# 12 — Database admin

A Super-Admin-only console for inspecting and editing the live database. It is the closest thing the system has to a built-in `psql`/SSMS.

- Page: `/database`
- Backend: [routes/database.js](../backend/src/routes/database.js), [lib/db_introspect.js](../backend/src/lib/db_introspect.js), [lib/sql_runner.js](../backend/src/lib/sql_runner.js)
- Frontend: [features/database/](../frontend/lib/features/database/)

## What it does

### Table explorer

`GET /api/db/tables` lists every table with its row count and `CREATE TABLE` SQL. `GET /api/db/tables/:name` returns columns, foreign keys, and indexes. `GET /api/db/tables/:name/preview?limit=50` returns the first N rows.

### SQL runner

`POST /api/db/query` body:

```json
{ "sql": "SELECT * FROM products LIMIT 10;", "allowWrite": false }
```

Toggling **Write mode** in the UI flips `allowWrite` to `true`, enabling `INSERT`, `UPDATE`, `DELETE`, `ALTER TABLE`, `CREATE TABLE`, `DROP TABLE`. By default the runner is read-only.

### Saved queries

Frequent queries can be saved. CRUD on `/api/db/queries`. Stored in `saved_queries` with the author's id.

## Safety guards

Implemented in [`sql_runner.js`](../backend/src/lib/sql_runner.js):

| Guard | Behavior |
|---|---|
| **Read-only by default** | Only `SELECT`, `EXPLAIN`, `WITH ... SELECT`, `PRAGMA` (read variants) succeed unless `allowWrite: true`. |
| **Auth-table protection** | Any statement touching `users`, `roles`, `permissions`, `role_permissions`, `user_roles`, or `user_permission_overrides` is rejected — even with `allowWrite: true`. Auth integrity is non-negotiable. |
| **Hard length limit** | SQL longer than 10,000 characters is rejected. |
| **Result truncation** | Result rows truncated at 1,000. |
| **Auditing** | Every query, success or failure, audited with `action: 'sql_query'`, `entity: 'database'`, full SQL in `before/after`. |

## Why a dedicated runner instead of "exec the user's string"

Two reasons:

1. **The auth tables are the keys to the kingdom.** A typo in an `UPDATE users SET ...` could lock everyone out. The runner refuses to touch them.
2. **Audit and revertibility.** Every query is logged with the actor and timestamp. If anything goes wrong, the audit log is the trail.

## Table introspection mechanics

[`db_introspect.js`](../backend/src/lib/db_introspect.js) uses SQLite `PRAGMA` queries to enumerate tables, columns, foreign keys, and indexes. **`PRAGMA` returns BigInt for numeric columns** — always coerce to `Number(...)` before serialization. (The introspect helpers do; if you call `PRAGMA` directly, do this yourself.)

## Two identifier validators

The DB explorer needs to handle two kinds of names:

| Validator | Regex | Used for |
|---|---|---|
| `validateTableName` | `^[a-z][a-z0-9_]{0,62}$` | User-created tables (custom entities) |
| `validateIdent` | `^[A-Za-z_][A-Za-z0-9_]{0,62}$` | Inspecting Prisma tables (User, AuditLog, …) |

Both reject anything that could break out of an identifier position into SQL. Neither is a substitute for parameterized queries — they only validate identifiers that **must** be inlined (table/column names).

## Permissions

| Endpoint | Required role/perm |
|---|---|
| All `GET /api/db/*` and `POST /api/db/query` | Super Admin (`isSuperAdmin: true`) |
| Saved-query CRUD | Super Admin |

The middleware short-circuits via the `isSuperAdmin` flag — there are no granular `database.*` permissions yet.
