# 22 — System configuration

Live at `/system` (Super Admin). The console for operating the server: process info, database connections, init SQL.

- Backend: [routes/system.js](../backend/src/routes/system.js), [lib/env_writer.js](../backend/src/lib/env_writer.js)
- Frontend: [features/system/](../frontend/lib/features/system/)
- Models: `DatabaseConnection` in [schema.prisma](../backend/prisma/schema.prisma)

## Process info

`GET /api/system/info` returns:

- `node`, `platform`, `arch`, `hostname`, `uptimeSec`
- `memory`: rss / heapUsed / heapTotal
- `databaseProvider`, `databaseUrl` (masked: passwords replaced with `***`)
- `counts`: users, roles, permissions, audit logs, system logs, login events, pages, custom entities

The page renders these as info cards.

## Database connections from the UI

The user wants to **enter a database URL through the system** rather than editing `.env` by hand. The `DatabaseConnection` table holds named entries:

```
id  code     name            provider     url                              isPrimary  isActive
1   local    Local SQLite    sqlite       file:./dev.db                    true       true
2   cloud_pg Production PG   postgresql   postgresql://u:p@host:5432/db    false      true
```

| Method | Path | Notes |
|---|---|---|
| GET | `/api/system/database/connections` | list (URLs masked) |
| POST | `/api/system/database/connections` | create |
| PUT | `/api/system/database/connections/:id` | update |
| DELETE | `/api/system/database/connections/:id` | delete (cannot delete primary) |
| POST | `/api/system/database/connections/:id/promote` | **rewrite `DATABASE_URL` in `.env`** and mark this connection primary |
| POST | `/api/system/database/test` | trivial validator (provider must be in allowlist) |
| POST | `/api/system/database/sql/init` | run init SQL (CREATE TABLE / INSERT / …) statement-by-statement |

### Promote (the load-bearing endpoint)

`POST /api/system/database/connections/:id/promote`:

1. Backs up the current `.env` to `.env-backups/.env.<timestamp>` so a misconfiguration can be rolled back.
2. Writes `DATABASE_URL="..."` into `.env` (preserving other keys).
3. Sets `isPrimary: true` on the chosen connection (and false on the rest) inside the *current* DB (because the process is still pointing at the old one).
4. Returns `{ ok: true, restartRequired: true, message, backupPath }`.

The user then:
- Edits `prisma/schema.prisma` if the provider differs from the current one (e.g. `sqlite` → `postgresql`)
- Restarts the backend
- Runs `npx prisma migrate deploy && npm run db:seed`

The system **does not auto-restart**. Forcing a restart from a web request is a footgun (mid-request connections die, partial writes possible). Promote = "stage the change", restart = "go live".

### Why .env editing instead of pure DB

Prisma reads `DATABASE_URL` from the environment at process start and binds the client to one provider. There is no supported way to swap providers at runtime in one process. Storing connections in the DB is for *bookkeeping*; the `.env` rewrite is what actually moves the runtime.

For per-query targeting of *secondary* databases — see the next section.

## Secondary DB pool (Phase 4.2)

The SQL runner accepts an optional `connectionId` in its body:

```json
POST /api/db/query
{ "sql": "SELECT * FROM products LIMIT 10;", "connectionId": 2 }
```

The pool ([`lib/db_pool.js`](../backend/src/lib/db_pool.js)):

1. Looks up the saved `DatabaseConnection` row by id.
2. Spins up a `PrismaClient` with `datasources.db.url` overridden, caches it by connection id (re-uses on repeat calls; rebuilds if the URL changes).
3. Runs a `SELECT 1` probe to fail fast on a bad URL.
4. Reuses the cached client for the lifetime of the process.

### Auth-table protection

Auth-table protection (the `users`/`roles`/`permissions`/… block list) **only applies to the primary connection** — secondaries don't own this app's auth schema, so blocking those names there would be wrong. Read-only mode still applies unless `allowWrite: true`.

### Cross-provider support (Phase 4.3)

The pool now uses native drivers for cross-provider secondaries:

| Connection provider | Driver path | Status |
|---|---|---|
| same as primary (e.g. `sqlite` ↔ `sqlite`) | `PrismaClient` with overridden URL | ✅ |
| `postgresql` | `pg.Pool` (`pg` package) | ✅ |
| `mysql` | `mysql2/promise` Pool | ✅ |
| `sqlserver` | — | ❌ rejected with clear error |
| `mongodb` | — | ❌ rejected (different paradigm) |

Each driver is wrapped in a uniform handle (`runRead(sql)` / `runWrite(sql)` / `close()` / `kind`) so [`sql_runner.js`](../backend/src/lib/sql_runner.js) doesn't branch on provider. The `kind` field comes back in the response (`"prisma"`, `"pg"`, `"mysql"`) so you can tell what executed your query.

If you need the **whole app** (not just SQL queries) on a different provider, **Promote** the connection in `/system` — that rewrites `.env` and after a restart + `prisma migrate deploy + db:seed` the primary changes.

### Provider inference

If a connection is saved without an explicit provider, `inferProvider(url)` guesses from the scheme: `file:`/`*.db` → `sqlite`, `postgres://` → `postgresql`, `mysql://` → `mysql`, etc.

## Init SQL

`POST /api/system/database/sql/init` — paste a multi-statement script (CREATE TABLE / ALTER TABLE / CREATE INDEX / INSERT). The endpoint:

- Splits on `;\n` boundaries
- Runs each statement via `prisma.$executeRawUnsafe`
- Records per-statement success/error in the response
- Audits the run (`action: 'init_sql'`, count of statements)
- Logs a system message

Useful for bootstrapping a fresh secondary DB or applying a migration to the primary while iterating.

> **Caution**: this is *not* protected by the SQL runner's auth-table guard. The user can hose `users`/`roles`/`permissions` with a careless statement. The route requires Super Admin. If you want auth-table protection here too, route it through `lib/sql_runner.js`.

## Provider allowlist

Currently: `sqlite`, `postgresql`, `mysql`, `sqlserver`, `mongodb`. Mongo is in the allowlist for connection bookkeeping only — Prisma's Mongo provider has its own quirks; the seed and most queries assume SQL.

## Reading and writing .env safely

The helper at [`lib/env_writer.js`](../backend/src/lib/env_writer.js):

- `readEnvKeys([keys])` returns the current values for the asked keys (no whole-file dump).
- `setEnvKeys(map)` writes the given keys, replacing existing lines or appending. Backs up first.
- Backups go to `backend/.env-backups/.env.<ISO-timestamp>`.

Call it from any new endpoint that needs to mutate `.env` — don't write `.env` ad-hoc.
