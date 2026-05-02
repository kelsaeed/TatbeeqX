# 08 — Database schema

The canonical schema is [backend/prisma/schema.prisma](../backend/prisma/schema.prisma). Everything below mirrors that file. If they disagree, the Prisma file wins.

## Engine

- **Dev**: SQLite, single file at `backend/prisma/dev.db`
- **Prod swap**: change `provider = "sqlite"` to `"postgresql"` or `"mysql"`, point `DATABASE_URL` at the cluster, run `npx prisma migrate deploy && npm run db:seed`. No app changes.

## Identity / structure

| Table | Purpose |
|---|---|
| `companies` | Top-level tenants. One install can hold many. |
| `branches` | Belong to a company. Cascade on company delete. |
| `users` | Login accounts. `isSuperAdmin` flag bypasses permission checks. |
| `roles` | Named permission bundles. `isSystem` rows (super_admin, chairman, company_admin, manager, employee) cannot be deleted. |
| `permissions` | Catalog. Code is `<module>.<action>`. |
| `role_permissions` | Many-to-many: role ↔ permission. |
| `user_roles` | Many-to-many: user ↔ role. Cascade on user/role delete. |
| `user_permission_overrides` | Per-user grant/revoke layered over roles (`allow: 1` grant, `allow: 0` revoke). |

## Navigation / appearance

| Table | Purpose |
|---|---|
| `modules` | Logical units. Drives the catalog and the menu builder. |
| `menu_items` | Sidebar entries. `permissionCode` is the gate. |
| `themes` | Theme records. One row has `isActive: true`; another may have `isDefault: true`. Global (`companyId NULL`) or company-specific. |
| `settings` | Key/value store. `[companyId, key]` is unique with nullable companyId — use `findFirst`+`update`/`create`, not `upsert` (Prisma quirk). |

## Audit

| Table | Purpose |
|---|---|
| `audit_logs` | Indexed on `createdAt`, `entity`, `actorId`. Stores `before` / `after` JSON. |

## Reporting

| Table | Purpose |
|---|---|
| `reports` | `code`, `name`, `description`, `category`, `builder` (key into `reports.js`), `config` JSON. |

## Customization platform (Phase 3)

| Table | Purpose |
|---|---|
| `custom_entities` | User-defined tables: `code`, `tableName`, `label`, `icon`, `config` (column definitions JSON). |
| `system_templates` | Captured snapshots: `code`, `name`, `kind` (`theme` / `business` / `full`), `data` JSON. |
| `saved_queries` | Saved SQL runner queries: `name`, `sql`, `allowWrite`, `createdById`. |
| `<custom-table>` | Real SQL tables created when a preset is applied or an entity is added. Created via `prisma.$executeRawUnsafe('CREATE TABLE IF NOT EXISTS …')`. |

## Conventions

- All Prisma models have `id Int @id @default(autoincrement())`.
- `createdAt` and `updatedAt` (where it makes sense) use `@default(now())` and `@updatedAt`.
- Foreign keys cascade on parent delete where it makes sense (`branch.companyId`, `userRole.userId/roleId`, etc.).
- Indexes on `companyId`, `branchId`, `entity`, `createdAt` for the access patterns the app needs (filter audit logs by entity/date, list branches per company, etc.).

## Inspecting the live DB

Use the **Database** module (Super Admin only) at `/database`:

- Lists all tables with row counts and the `CREATE TABLE` SQL.
- Click a table to see columns, foreign keys, indexes.
- Preview the first 50 rows.
- Run SQL through the safe runner — read-only by default, **Write mode** toggle for INSERT/UPDATE/ALTER. Auth tables (`users`, `roles`, `permissions`, `role_permissions`, `user_roles`, `user_permission_overrides`) are blocked even in Write mode.

The two identifier validators in [`custom_entity_engine.js`](../backend/src/lib/custom_entity_engine.js):

- `validateTableName` — strict (`^[a-z][a-z0-9_]{0,62}$`) — for **user-created** tables
- `validateIdent` — permissive (`^[A-Za-z_][A-Za-z0-9_]{0,62}$`) — for **inspecting** Prisma's PascalCase tables (User, AuditLog, etc.) in the explorer

## Going from SQLite to Postgres/MySQL

```ini
# backend/.env
DATABASE_URL="postgresql://user:pass@host:5432/TatbeeqX"
```

```prisma
// backend/prisma/schema.prisma
datasource db {
  provider = "postgresql"   // was "sqlite"
  url      = env("DATABASE_URL")
}
```

```bash
cd backend
npx prisma migrate deploy
npm run db:seed
```

JSON columns: SQLite stores as `TEXT` and Prisma serializes/deserializes; Postgres uses `JSONB` natively. No app changes needed.
