# 01 — Overview

## What it is

**TatbeeqX** is a flexible multi-company management platform. The same binaries fit a restaurant, a retail POS, a clinic, a factory, a finance office, or a rental shop. The behavior changes by selecting a **business preset** (or designing your own custom tables) — not by recompiling.

It is built to run on a **LAN** today (one host machine + Windows desktop clients) and to **graduate to a cloud database** by changing one connection string and one Prisma provider — no application code changes.

## Who it is for

- A business owner who wants one app to manage multiple companies/branches.
- An IT admin running a small private network with several Windows clients.
- A developer extending the platform with new modules, reports, or custom entities through the UI rather than through code.

## Design goals

1. **Configurable, not coded.** Roles, permissions, menus, themes, business types, and entire tables are defined in the database and editable from the UI.
2. **Plugin-free Flutter desktop.** Tokens are persisted with plain `dart:io` to `%APPDATA%\TatbeeqX\auth.json` so the Windows build does not require Developer Mode (no symlink support needed).
3. **Safe by default.** SQL runner blocks auth tables. Custom entity names validated. Read-only mode is the default for SQL.
4. **One source of truth.** The database holds permissions, menus, themes, business state, custom tables, reports, templates. The UI reads from there at boot — no hard-coded duplicates.
5. **Audited.** Every mutation hits `audit_logs` with actor, action, entity, and a JSON diff.

## High-level architecture

```
+-----------------+        HTTP/JSON        +------------------+
|  Flutter Desktop| <---------------------> |  Express + Prisma|
|  (Windows / Web)|                         |  Node.js 20+     |
+-----------------+                         +------------------+
       ^                                            |
       | reads /api/themes/active at boot           |
       | reads /api/menus per session               v
       | calls /api/auth, /api/users, ...   +---------------+
                                            |  SQLite (dev) |
                                            |  Postgres/MySQL (prod swap) |
                                            +---------------+
                                                    ^
                                                    | served at /uploads
                                            +---------------+
                                            |  uploads/ dir |
                                            +---------------+
```

- **Frontend** loads the active theme on boot and rebuilds `MaterialApp.theme`. Sidebar fetches `/api/menus` and shows only items the user has the underlying `*.view` permission for.
- **Backend** layers: routes → middleware (auth, permission, validate) → lib helpers (`prisma`, `permissions`, `audit`, `reports`, `sql_runner`, `custom_entity_engine`, `business_presets`, `templates`).
- **Database** is a single SQLite file in dev. Prisma migrations + a comprehensive seeder bring it up.

## Clean architecture, kept simple

- **presentation** — Flutter widgets (`features/*/presentation`)
- **application** — controllers/notifiers (`features/*/application`)
- **domain** — entities (`features/*/domain`)
- **infrastructure** — repositories (`features/*/data`)
- **shared** — common widgets (`lib/shared/widgets`)

Patterns in use: Repository (data layer), Singleton (Riverpod providers), Dependency Injection (Riverpod overrides), Factory (`AppThemeBuilder.build`).

## Where to look in the repo

| You want to … | Open … |
|---|---|
| understand the data model | [backend/prisma/schema.prisma](../backend/prisma/schema.prisma) |
| see what gets seeded | [backend/prisma/seed.js](../backend/prisma/seed.js) |
| trace an HTTP request | [backend/src/server.js](../backend/src/server.js) → `routes/index.js` → the route file |
| understand permissions | [backend/src/lib/permissions.js](../backend/src/lib/permissions.js) and [backend/src/middleware/permission.js](../backend/src/middleware/permission.js) |
| add a new module | [docs/06-modules.md](06-modules.md) |
| change the look | [docs/09-theme-builder.md](09-theme-builder.md) |
| pick a business type | [docs/10-business-presets.md](10-business-presets.md) |
| design a new table from the UI | [docs/11-custom-entities.md](11-custom-entities.md) |
| run SQL safely | [docs/12-database-admin.md](12-database-admin.md) |
| capture or import a setup | [docs/14-templates.md](14-templates.md) |
