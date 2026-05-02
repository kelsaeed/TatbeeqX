# Project memory — TatbeeqX

This file is the single source of truth for project context. Read it first in any new session — do not rely on chat history.

## What this is

A flexible multi-company management system. Designed to fit any business type (restaurant, POS, factory, clinic, finance office, rental). Runs on LAN today, will move to a cloud DB without code changes by switching the connection string and Prisma provider.

## Tech stack

- **Backend** — Node.js 20+, Express, Prisma ORM, SQLite (dev), bcryptjs, JWT, multer for uploads, helmet, morgan, cors.
- **Frontend** — Flutter 3.41 desktop-first (Windows). Web is also enabled. Riverpod for state, go_router for routing, dio for HTTP.
- **No native Flutter plugins.** Token storage uses plain `dart:io` (writes to `%APPDATA%\TatbeeqX\auth.json`). This is **deliberate** — avoids the Windows symlink requirement so the user does not need to enable Developer Mode.
- **Auth** — JWT access + refresh, bcrypt-hashed passwords, super-admin bypass via `isSuperAdmin` flag.

## Folder layout

```
backend/
  src/
    config/env.js           # env loading
    lib/                    # prisma, jwt, password, permissions, audit, http, reports,
                            # sql_runner, custom_entity_engine, business_presets,
                            # db_introspect, templates, system_log, env_writer,
                            # db_pool, cron, approvals, webhooks, html_sanitize,
                            # approval_handlers, app, backup
    middleware/             # auth, permission, error, validate
    routes/                 # auth, users, roles, permissions, companies, branches,
                            # menus, audit, settings, themes, dashboard, reports, uploads,
                            # database, custom_entities, custom_records, business, templates,
                            # pages, system, system_logs, login_events,
                            # approvals, report_schedules, webhooks, admin
    server.js               # Express entry; serves /api and /uploads static
  prisma/
    schema.prisma           # SQLite by default; switch provider for online
    seed.js                 # full seed: permissions, roles, modules, menus,
                            # sample company, default theme, sample reports
    migrations/             # generated; never edit by hand
  uploads/                  # multer drops files here; gitignored
  .env                      # local-only, gitignored
  .env-backups/             # written by Promote endpoint when DATABASE_URL changes

frontend/lib/
  main.dart                 # boot: opens TokenStorage, runs ProviderScope
  app.dart                  # MaterialApp.router; loads active theme + bootstraps auth
  core/
    config/app_config.dart  # apiBaseUrl (LAN swap point) + apiTimeout
    network/                # ApiClient (dio + interceptors), ApiException
    storage/                # TokenStorage — plain File, no shared_preferences
    theme/                  # ThemeSettings, ThemeDataBuilder, ThemeController
    providers.dart          # Riverpod providers for storage + ApiClient
  routing/app_router.dart   # go_router with auth-guard redirect
  features/
    auth/                   # login, AuthController, AuthRepository
    dashboard/              # shell (sidebar+topbar) + dashboard page (with charts)
    users/ roles/ companies/ audit/ settings/ themes/ reports/ menus/
    custom_entities/ custom/ database/ templates/ setup/
    pages/                  # page builder (Phase 4.0)
    system/                 # /system console + DB connection registry
    system_logs/            # log viewer
    login_events/           # login activity viewer
    approvals/              # approval queue (Phase 4.3)
    report_schedules/       # cron-scheduled report runs (Phase 4.3)
    webhooks/               # outbound webhook subscriptions (Phase 4.4)
    backups/                # DB backup/restore (Phase 4.6)
  l10n/                     # ARB files + generated AppLocalizations (Phase 4.6)
  shared/widgets/           # page header, paginated table, charts, upload field, etc.
```

## How to run (Windows desktop)

Open the project folder in VS Code. Open two terminals.

**Terminal 1 (API):**
```
cd backend
npm run dev
```

**Terminal 2 (Flutter desktop):**
```
cd frontend
flutter run -d windows
```

Both must run at the same time. If the Flutter app shows "Cannot reach the server at http://localhost:4000/api", the backend is not running — start it.

LAN client build (target a host server's IP):
```
flutter build windows --dart-define=API_BASE_URL=http://<host-ip>:4000/api
```

The output `.exe` is at `frontend/build/windows/x64/runner/Release/tatbeeqx.exe` (or `Debug/` for debug builds). Copy the whole folder to a client machine.

## Default seeded data

- Super Admin login: `superadmin` / `ChangeMe!2026` (override via `SEED_SUPERADMIN_*` env vars).
- 5 roles: `super_admin`, `chairman`, `company_admin`, `manager`, `employee` — all marked `isSystem: true`.
- One sample company `DEMO` with one branch `MAIN`.
- One default theme: "Default Professional" — both `isDefault` and `isActive`.
- 5 sample reports: `users.by_role`, `users.active_status`, `companies.summary`, `audit.actions_summary`, `audit.entities_summary`.

## Permission model

Permission codes use `<module>.<action>` form. Actions: `view`, `create`, `edit`, `delete`, `approve`, `export`, `print`, `manage_settings`, `manage_users`, `manage_roles`.

A user's effective permissions =
`(union of permissions from assigned roles)` + `per-user grants` − `per-user revokes`.

Super Admins skip all checks (they have `isSuperAdmin` true on the user record).

The Flutter sidebar reads `/api/menus`, which the backend filters by the requesting user's permissions — so a sidebar item only shows when the user can see the underlying module.

## Theme Builder

Super Admin only, at `/themes`. Edits any of:
- mode (light/dark), primary/secondary/accent/background/surface/sidebar/topbar colors and their text colors
- font family + base size
- button/card/table radius
- shadows, gradients (with from/to colors and direction)
- login style, dashboard layout
- app name, logo URL, favicon URL, background image URL (all support upload via the integrated `LocalFileUploadField` — paste a Windows path, click Upload)

The active theme is fetched on app boot (`/api/themes/active`) and applied dynamically. No rebuild required after changing it.

## Reports

- Backend builders live in [`backend/src/lib/reports.js`](backend/src/lib/reports.js). Each builder is a function returning `{ columns, rows }`.
- The DB stores `code/name/description/category/builder/config`. The `builder` is a key into the registry, **not** raw SQL — this keeps user-defined reports safe.
- Frontend `/reports` shows reports grouped by category. Opening one runs it; the runner page can toggle table ↔ bar chart when there is at least one numeric column.

To add a report: append a builder in `reports.js`, then either seed a row or create one through `POST /api/reports`.

## File uploads

- Endpoint: `POST /api/uploads/image` (auth required, multipart `file` field).
- Allowed MIME: PNG, JPEG, WebP, GIF, SVG, ICO. 5 MB max.
- Files saved to `backend/uploads/`, served at `/uploads/<filename>`.
- The frontend uses the integrated [`LocalFileUploadField`](frontend/lib/shared/widgets/local_file_upload_field.dart) — pastes a local Windows path, reads the file via `dart:io`, uploads multipart, stores the returned URL.

## Going online later

Switch SQLite → Postgres/MySQL:
1. `backend/prisma/schema.prisma`: change `provider = "sqlite"` to `"postgresql"` or `"mysql"`.
2. `backend/.env`: set `DATABASE_URL` to the cloud connection string.
3. `npx prisma migrate deploy && npm run db:seed`.

No application code changes required.

## Common pitfalls

- **Login fails / spinner forever** → backend is not running. Start `npm run dev` in `backend/`.
- **"Building with plugins requires symlink support"** → a Flutter plugin slipped back into `pubspec.yaml`. Keep this app plugin-free; use plain `dart:io` instead.
- **`prisma generate` fails with EPERM rename DLL** → the dev server is running and has the engine DLL locked. Stop the server, then re-run.
- **"Argument `companyId` must not be null"** when seeding/saving settings → the schema's compound unique `[companyId, key]` does not accept null in `upsert`. Use `findFirst` + create/update instead. Already fixed in the seeder and settings route — keep this pattern.

## Phase status

- **Phase 1** — auth, RBAC, audit, dynamic menus, full CRUD for users/roles/companies/branches, settings, theme builder. Done.
- **Phase 2** — real dashboard charts (audit-by-day, audit-by-entity), Reports module with 5 seeded reports, file uploads with theme-builder integration. Done.
- **Phase 3** — business-type presets, DB explorer + SQL runner, custom-entity engine with generic CRUD, setup wizard, background image rendering, templates (capture/apply/import/export). Done.
- **Phase 4.0** — page builder backend (`/pages`, blocks), system console (`/system` with process info + DB connection registry + Promote endpoint that rewrites `.env`), system logs (`/system-logs`) + login event tracking (`/login-events`), quick permission presets (`POST /api/roles/:id/presets` with `view` / `view_edit` / `view_edit_delete` / `full` / `none` per module), theme transparency/glass fields. Done.
- **Phase 4.1** — page renderer at `/p/:code` rendering 15 block types, drag-drop reorder, container nesting in builder UI, theme transparency UI sliders, login overlay rendering with style variants (split/centered/minimal) + glass card, dashboard stacked background, quick-preset chips per module in role editor, sidebar merge with `/api/pages/sidebar`. Done.
- **Phase 4.2** — Templates v2 (six kinds: theme/business/pages/reports/queries/full), `GET /api/templates/kinds` endpoint, page captures preserve block parent/child via localId/parentLocalId two-pass insert. Secondary DB pool in `lib/db_pool.js` with cached PrismaClients (override `datasources.db.url`). `POST /api/db/query` accepts `connectionId`. Auth-table protection scoped to primary only. Done.
- **Phase 4.3** — `ApprovalRequest` + `/approvals` page with per-entity decide gate (`<entity>.approve`); `ReportSchedule` + `ScheduledReportRun` + in-process minute-tick cron loop (`startCronLoop()` at boot, no `node-cron` dep, supports enum frequencies + 5-field standard cron); native cross-provider drivers — `pg` and `mysql2` installed and wrapped in a uniform `runRead`/`runWrite`/`close` handle so the SQL runner can target Postgres / MySQL secondaries from a SQLite primary. Done.
- **Phase 4.4** — webhooks (HMAC-SHA256, 3-attempt retry); multi-instance cron locking; hourly retention sweep; HTML sanitization on PageBlock create+update; typed block inspectors for 11 types; vitest 58 tests. Done.
- **Phase 4.5** — conditional block visibility; approval claim handlers; auto-`ALTER TABLE` on entity column edits; per-company theming UI; Docker compose template; i18n foundation; 69 tests. Done.
- **Phase 4.6** — gen_l10n with `app_en/ar/fr.arb` + login screen migrated; SQLite backup/restore endpoints + `/backups` UI; builder analytics; mobile-shell polish; route-layer tests via extracted `buildApp()`; 83 tests / 8 files. Done.
- **Phase 4.7** — negative permission tests + per-feature smoke tests; native `pg_dump` / `mysqldump`; sidebar label translation; topbar localized; 98 tests / 10 files. Done.
- **Phase 4.8** — `Page.titles` JSON + `PageRenderer` locale resolver; encrypted backups (`MCEB` v1, in-memory); `backup.created` webhook event; isolated per-suite test DB via vitest globalSetup; 102 tests / 11. Done.
- **Phase 4.9** — streaming encryption (`MCEB` v2 trailer-tag, flat memory); built-in key rotation endpoint; `Role.labels` JSON seeded en/ar/fr; bulk page-header migration; off-site sync receiver under `tools/backup-sync/`; 106 tests / 11. Done.
- **Phase 4.10 (now)** — HTTPS download endpoint with HMAC-signed URLs (`GET /api/admin/backups/:name/download`, dual auth: Super Admin Bearer or `?expires&sig`; gated on `BACKUP_DOWNLOAD_SECRET`; default 1h TTL); webhook `backup.created` payload includes `downloadUrl`; receiver tool falls back to HTTPS pull when shared filesystem isn't available, or always when `PULL_VIA_HTTP=1`; roles UI resolves `role.labels[localeCode]` so role names flip with active locale; ARB import/export endpoints (`/api/admin/translations`) + `/translations` Super Admin page (edit/export/new-locale; strips and re-stamps `@@locale`; writes timestamped `.bak-*` sidecars); 119 tests / 13 files. Done.
- **Phase 4.11** — mobile shell, full UI string migration, native S3/restic uploaders, per-key translation editor, backup retention policy. Next (proposed).

See [docs/18-phases.md](docs/18-phases.md) for the full breakdown.

## Business types & customization platform

This is the no-code/low-code layer on top of the foundation.

### Business presets
Defined in [`backend/src/lib/business_presets.js`](backend/src/lib/business_presets.js). Each preset is a registry entry with:
- `code`, `name`, `description`, `icon`
- `entities`: array of column definitions

Built-in presets: `retail`, `restaurant`, `clinic`, `factory`, `finance`, `rental`, `blank`.

Apply on seed: set `SEED_BUSINESS_TYPE=retail` in `backend/.env` before running the seeder.

Apply at runtime: `POST /api/business/apply` with `{"code": "<preset>"}`. The first-run **Setup Wizard** at `/setup` does this automatically; the redirect in [app_router.dart](frontend/lib/routing/app_router.dart) sends Super Admins there until a preset is applied.

Applying a preset:
1. For each entity, runs `CREATE TABLE IF NOT EXISTS …` via `prisma.$executeRawUnsafe`.
2. Registers the entity in `custom_entities`.
3. Creates `<prefix>.{view,create,edit,delete,export,print}` permissions and grants them to Super Admin + Company Admin.
4. Adds a sidebar menu item linking to `/c/<code>`.
5. Stores the chosen type in `settings.system.business_type`.

### Custom entities (user-defined tables)
Schema row in `custom_entities` keyed by `code`, pointing to a real SQL `tableName`. Config JSON stores column definitions (name, label, type, required, unique, searchable, showInList, defaultValue).

Column types: `text`, `longtext`, `integer`, `number`, `bool`, `date`, `datetime`, `relation` → mapped to SQLite types in [`custom_entity_engine.js`](backend/src/lib/custom_entity_engine.js).

**Adding a new custom entity** in the UI: `/custom-entities` → New entity. Backend validates names with `^[a-z][a-z0-9_]{0,62}$`. The CREATE TABLE is auto-generated, permissions and menu created, sidebar refreshes via `MenuController.load()`.

Generic CRUD lives at `GET/POST/PUT/DELETE /api/c/:code` using raw SQL against the registered `tableName`. Frontend `/c/:code` route renders a generic list (using `paginated_search_table.dart`) and a generic form dialog ([custom_record_dialog.dart](frontend/lib/features/custom/presentation/custom_record_dialog.dart)) that auto-builds inputs from column types.

### Database admin
Super Admin only at `/database`.
- `GET /api/db/tables` — list tables with row counts and the `CREATE TABLE` SQL.
- `GET /api/db/tables/:name` — columns, foreign keys, indexes.
- `GET /api/db/tables/:name/preview?limit=50` — first N rows.
- `POST /api/db/query` — run SQL.
- Saved queries: `GET/POST/PUT/DELETE /api/db/queries`.

### SQL runner safety
[`sql_runner.js`](backend/src/lib/sql_runner.js) enforces:
- Read-only by default; **Write mode** toggle in the UI flips `allowWrite=true`.
- Blocks any statement that touches the auth tables (`users`, `roles`, `permissions`, `role_permissions`, `user_roles`, `user_permission_overrides`).
- Hard 10,000-character limit; rows truncated at 1,000.
- Every query is audited with `action: 'sql_query'`.

Two identifier validators in [`custom_entity_engine.js`](backend/src/lib/custom_entity_engine.js):
- `validateTableName` — strict (`^[a-z][a-z0-9_]{0,62}$`) for **user-created** tables.
- `validateIdent` — permissive (`^[A-Za-z_][A-Za-z0-9_]{0,62}$`) for **inspecting** Prisma's PascalCase tables (User, AuditLog, etc.) in the DB explorer.

### Templates
A template is a captured snapshot of:
- Active theme (name + JSON settings) — kind `theme`
- Custom entities registry + their columns + business type — kind `business`
- Both — kind `full`

Stored in `system_templates` (`code`, `name`, `kind`, `data` JSON). Capture endpoint `POST /api/templates/capture`, apply endpoint `POST /api/templates/:id/apply`, import via paste at `POST /api/templates/import`, export by GET on a single template (the UI copies the JSON to clipboard).

UI: `/templates` (Super Admin only). Includes Save current / Import JSON / Apply / Copy JSON / Delete.

Apply behavior: theme is created as a new theme record and activated; entities are re-registered (table preserved if it already exists, registration row updated); business type setting overwritten.

## Common pitfalls (Phase 3 additions)

- **`prisma migrate dev` fails with "non-interactive environment"** in this shell. Workaround: use `npx prisma db push --accept-data-loss --skip-generate` then `npx prisma generate`. Or run interactively in a real terminal.
- **PRAGMA returns BigInt** — always coerce with `Number(...)` before serializing to JSON. The introspect helpers do this.
- **Compound unique with nullable column** — Prisma upsert can't set a null on the unique side. Use `findFirst` + `update`/`create` (already applied in seeder, settings, business state).
- **Custom entity column edits don't ALTER the SQL table** — yet. Edits to the registration row update the form schema, but don't add/drop columns. For now, use Database admin → SQL runner with `ALTER TABLE …` to evolve real tables, then update the entity's column config.
- **Setup wizard loop** — if the Super Admin keeps landing on `/setup`, check that the redirect in [app_router.dart](frontend/lib/routing/app_router.dart) reads from `setupControllerProvider`. After applying a preset, the controller is refreshed automatically.

## Architecture notes

Clean architecture, but kept simple:
- **presentation** — Flutter widgets (`features/*/presentation`)
- **application** — controllers/notifiers (`features/*/application`)
- **domain** — entities (`features/*/domain`)
- **infrastructure** — repositories (`features/*/data`)
- **shared** — common widgets (`lib/shared/widgets`)

Patterns in use: Repository (data layer), Singleton (Riverpod providers), Dependency Injection (Riverpod overrides), Factory (`AppThemeBuilder.build`).

Adding a new module:
1. Add the Prisma model + migration.
2. Add a route file in `backend/src/routes/<module>.js` and register it in `routes/index.js`.
3. Add permissions + a menu row to the seeder and re-seed.
4. Create a feature folder under `frontend/lib/features/<module>/`.
5. Add the route to `frontend/lib/routing/app_router.dart`.

The dashboard sidebar will pick the new module up automatically once the menu row exists and the user has its `*.view` permission.
