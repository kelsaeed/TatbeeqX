# TatbeeqX

[![CI](https://github.com/kelsaeed/TatbeeqX/actions/workflows/ci.yml/badge.svg)](https://github.com/kelsaeed/TatbeeqX/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Flexible multi-company management platform. Suits restaurants, POS/cashier, factories, clinics, finance offices, rentals, and more. Built to run on a LAN today and to graduate to a cloud database without code changes.

> **New here?**
> - **Setting up?** → [SETUP.md](SETUP.md) (every install in one place)
> - **Just want to run it?** → [docs/03-getting-started.md](docs/03-getting-started.md) (5-minute desktop walkthrough)
> - **Using the app?** → [docs/49-user-manual.md](docs/49-user-manual.md) (sign in, password reset, 2FA, all the modules)
> - **Where the project stands?** → [docs/18-phases.md](docs/18-phases.md) (current: Phase 4.19 — SMTP outbound email)

## Stack

- **Backend** — Node.js 20+, Express, Prisma, SQLite (swap the connection string to Postgres/MySQL when you go online).
- **Frontend** — Flutter (Windows desktop primary; web + iOS + Android shipped) with Riverpod, go_router, dio.
- **Auth** — JWT access + revocable refresh tokens with rotation + reuse detection, bcrypt passwords, TOTP 2FA + recovery codes, per-IP login rate limiting, timing-safe compare.
- **Permissions** — role-based, fully driven by the database. Admins create roles and assign permissions from the UI; per-user grant/revoke overrides on top.
- **Theme** — Super Admin can re-style the entire app from the UI; settings live in the database.
- **Automation** — workflow engine (4 trigger types × 8 action types), in-app notifications, outbound webhooks (HMAC-signed), outbound email via SMTP.
- **Tests** — 28 backend test files / 340 vitest cases; CI runs them + `flutter analyze` on every push.

## Project layout

```
backend/      Express API, Prisma schema, seeders
frontend/     Flutter app
  lib/
    core/             config, network, theme, storage, providers
    routing/          go_router with auth guard
    features/
      auth/           login, session
      dashboard/      shell + dashboard page
      users/          user management
      roles/          roles + permission matrix
      companies/      companies + branches
      audit/          audit log viewer
      settings/       key/value settings
      themes/         appearance + theme builder
      menus/          dynamic menu loading
      pages/          page builder + renderer
      approvals/      approval queue
      workflows/      workflow engine UI (Phase 4.17)
      notifications/  in-app notifications (Phase 4.18) — bell + page
      sessions/       per-account active devices
      webhooks/       outbound HTTP subscriptions
      backups/        DB backup / restore
      translations/   per-key ARB editor
      custom_entities/ + custom/  user-defined tables + generic CRUD
      reports/ + report_schedules/ ...
    shared/widgets/   reusable widgets (table, header, icons, …)
tools/         Operations utilities
  build-subsystem/   branded locked-down customer binaries (Phase 4.12)
  backup-sync/       off-site backup receiver (S3 / restic)
  webhook-verify/    multi-language signature verifier helpers
docs/         Documentation hub — start at docs/README.md
.github/      CI workflow + issue/PR templates
```

## First-time setup

### 1. Backend

```bash
cd backend
cp .env.example .env
npm install
npm run db:reset      # creates SQLite file, runs migrations, seeds defaults
npm run dev           # API on http://localhost:4040
```

Default Super Admin credentials (change immediately after first login):

```
username: superadmin
password: ChangeMe!2026
```

### 2. Frontend (Windows desktop)

```bash
cd frontend
flutter pub get
flutter run -d windows
```

> **No Developer Mode required.** The app intentionally avoids Flutter plugins on Windows so it builds without symlink support. Tokens are persisted to `%APPDATA%\TatbeeqX\auth.json` via plain `dart:io`, not via `shared_preferences`.

Web build:

```bash
flutter run -d chrome
```

The Flutter app reads the API base URL from `lib/core/config/app_config.dart`. Default is `http://localhost:4040/api`. To target a LAN server, run with:

```bash
flutter run -d windows --dart-define=API_BASE_URL=http://<server-lan-ip>:4040/api
```

## LAN deployment

1. Run the backend on the host machine (`npm start` or use `pm2`/`nssm` on Windows).
2. Allow PORT 4040 through the Windows firewall.
3. Find the host LAN IP (`ipconfig`).
4. On client machines, build the Flutter desktop app with the LAN IP:
   ```bash
   flutter build windows --dart-define=API_BASE_URL=http://192.168.x.x:4040/api
   ```
5. Copy `build/windows/x64/runner/Release/` to the client and launch the executable.

## Going online later

1. Provision a Postgres or MySQL database.
2. Update `DATABASE_URL` in `backend/.env`.
3. Change `provider` in `backend/prisma/schema.prisma` to `postgresql` (or `mysql`).
4. Run `npx prisma migrate deploy` and `npm run db:seed`.

No application code changes required.

## Roles seeded by default

- **Super Admin** — full system control, owns the Theme Builder, only role that can edit roles/permissions table directly.
- **Chairman** — full read visibility, high-level approvals, export and print.
- **Company Admin** — manages users, roles, branches, and settings inside their company.
- **Manager** — limited management within assigned modules.
- **Employee** — only the permissions explicitly granted (defaults to dashboard view).

## Permission model

Permissions are stored in the database with codes like `users.view`, `roles.edit`, `themes.manage_settings`. A user's effective permissions are:

```
(union of permissions from all assigned roles)
  + per-user grants
  - per-user revokes
```

Super Admins bypass permission checks (they have an `isSuperAdmin` flag on their user record).

Supported actions per module: `view`, `create`, `edit`, `delete`, `approve`, `export`, `print`, `manage_settings`, `manage_users`, `manage_roles`.

## Theme Builder

Available to Super Admin only at `/themes`.

- Edit primary, secondary, accent, background, surface, sidebar, top bar colors
- Light / dark mode
- Font family + base size, button/card/table radius
- Shadows, gradients (with direction)
- Login style, dashboard layout
- App name, logo URL, favicon URL, background image URL
- Live preview of cards, buttons, inputs, sidebar, top bar
- Activate, duplicate, reset, delete themes
- Themes can be global (companyId null) or company-specific

The active theme is fetched on app startup and applied dynamically — no rebuild needed.

## API surface

| Path | Notes |
| --- | --- |
| `POST /api/auth/login` | username/email + password → access + refresh tokens |
| `POST /api/auth/refresh` | rotate access token |
| `GET /api/auth/me` | current user + permissions |
| `POST /api/auth/change-password` | self-service |
| `GET/POST/PUT/DELETE /api/users` | with search, pagination, role assignment |
| `GET/POST/PUT/DELETE /api/roles` | with permission assignment |
| `GET /api/permissions` | full catalog |
| `GET/POST/PUT/DELETE /api/companies` | |
| `GET/POST/PUT/DELETE /api/branches` | filter by `companyId` |
| `GET /api/menus` | filtered by user permissions |
| `GET /api/audit` | paginated audit log |
| `GET/PUT /api/settings` | key/value config |
| `GET /api/themes/active` | public — used at boot |
| `GET/POST/PUT/DELETE /api/themes` | super admin only |
| `POST /api/themes/:id/activate` | activate one theme |
| `POST /api/themes/:id/duplicate` | clone |
| `POST /api/themes/:id/reset` | reset to default |
| `GET /api/dashboard/summary` | counts + recent activity |
| `GET /api/dashboard/audit-by-day` | audit events per day (`?days=14`) |
| `GET /api/dashboard/audit-by-module` | audit events per entity (`?days=30`) |
| `GET /api/reports` | list reports (filter by `?category=`) |
| `GET /api/reports/:id` | single report config |
| `POST /api/reports/:id/run` | execute report; returns `{columns, rows}` |
| `POST/PUT/DELETE /api/reports` | manage custom reports |
| `POST /api/uploads/image` | multipart image upload (5 MB max) |
| `GET /api/business/presets` | list available business presets |
| `GET /api/business/state` | is a preset applied? what type? entity count? |
| `POST /api/business/apply` | apply a preset (Super Admin) |
| `GET /api/db/tables` | list SQL tables (Super Admin) |
| `GET /api/db/tables/:name` | columns, foreign keys, indexes |
| `GET /api/db/tables/:name/preview` | first N rows |
| `POST /api/db/query` | run SQL with safety guards |
| `GET/POST/PUT/DELETE /api/db/queries` | saved queries |
| `GET /api/custom-entities` | registered custom entities |
| `POST/PUT/DELETE /api/custom-entities` | manage entities (Super Admin) |
| `GET/POST/PUT/DELETE /api/c/:code` | generic CRUD against a custom entity |
| `GET/POST/DELETE /api/templates` | list / capture / delete templates |
| `POST /api/templates/:id/apply` | apply a captured template |
| `POST /api/templates/import` | import a template from JSON |
| `GET/POST/PUT/DELETE /api/pages` | custom pages (Phase 4) |
| `GET/POST/PUT/DELETE /api/pages/:id/blocks` | page blocks |
| `POST /api/pages/:id/reorder` | reorder blocks |
| `GET /api/pages/by-route` | resolve a page + blocks by its route |
| `GET /api/pages/sidebar` | sidebar-visible pages, filtered by permission |
| `GET /api/system/info` | server info + counts |
| `GET/POST/PUT/DELETE /api/system/database/connections` | saved DB connections |
| `POST /api/system/database/connections/:id/promote` | rewrite `.env` `DATABASE_URL` (with backup) |
| `POST /api/system/database/sql/init` | run multi-statement init SQL |
| `GET /api/system-logs` | server log viewer |
| `POST /api/system-logs/clear` | clear logs by age/level |
| `GET /api/login-events` | login/logout/refresh history |
| `POST /api/roles/:id/presets` | apply quick presets (`view`/`view_edit`/`view_edit_delete`/`full`/`none`) per module |
| `GET /api/templates/kinds` | list supported template kinds (Phase 4.2) |
| `POST /api/db/query` | now accepts `connectionId` to target a secondary DB (sqlite/postgres/mysql) |
| `GET/POST /api/approvals` | approval queue + new request (Phase 4.3) |
| `POST /api/approvals/:id/{approve,reject,cancel}` | decision endpoints, gated by `<entity>.approve` |
| `GET/POST/PUT/DELETE /api/report-schedules` | recurring report runs |
| `POST /api/report-schedules/:id/run-now` | manual trigger |
| `GET /api/report-schedules/:id/runs` | recent run history |
| `GET/POST/PUT/DELETE /api/webhooks` | outbound HMAC-signed webhook subscriptions (Phase 4.4) |
| `POST /api/webhooks/:id/test` | dispatch a synthetic `webhook.test` event |
| `GET /api/webhooks/:id/deliveries` | recent delivery attempts |
| `GET/POST /api/admin/backups` | list / create DB backups (Phase 4.6) |
| `POST /api/admin/backups/:name/restore` | restore from a backup (Super Admin) |
| `POST /api/admin/backups/sweep-retention` | manually trigger the retention prune (Super Admin, Phase 4.11) |
| `GET /api/pages/analytics` | page-builder usage stats (Phase 4.6) |
| `POST /api/admin/backups/rotate-encryption` | re-encrypt all `.enc` backups with a new key + rewrite `.env` (Phase 4.9) |
| `GET /api/admin/backups/:name/download` | stream a backup; dual auth: Bearer or HMAC-signed `?expires&sig` (Phase 4.10) |
| `GET/PUT /api/admin/translations[/:locale]` | edit ARB files from the UI (Phase 4.10) |
| `POST /api/auth/forgot-password` | self-serve password reset email (Phase 4.19, public, anti-enumeration, rate-limited; 503 if SMTP unconfigured) |
| `POST /api/auth/redeem-reset-token` | redeem a one-time reset token (public, rate-limited, single-use; Phase 4.16) |
| `POST /api/auth/2fa/{enroll,verify-enrollment,challenge,disable}` | TOTP enrollment + login challenge + self-disable (Phase 4.16) |
| `POST /api/users/:id/{password-reset,2fa/reset}` | admin-token password reset + admin 2FA reset (Phase 4.16) |
| `GET/POST/DELETE /api/auth/sessions[/:id]` | active devices + per-session revoke (Phase 4.16) |
| `POST /api/auth/sessions/revoke-all` | sign out everywhere (Phase 4.16) |
| `GET/POST/PUT/DELETE /api/workflows` | workflow definitions (Phase 4.17) |
| `POST /api/workflows/:id/run` | manual fire (`workflows.run`) |
| `POST /api/workflows/by-code/:code/run` | by-code manual fire — used by page-builder buttons (Phase 4.17 v2) |
| `POST /api/workflows/incoming/:code` | **public** webhook trigger; secret matched against `X-Workflow-Secret` (Phase 4.17 v2) |
| `GET /api/workflows/:id/runs` + `/runs/:runId` | run history + step detail |
| `GET /api/notifications` + `/unread-count` | per-user notification list + badge (Phase 4.18) |
| `POST /api/notifications/{:id/read,read-all}` + `DELETE` | mark + dismiss (Phase 4.18) |
| `GET /api/health` | health probe |

For deeper per-endpoint coverage see [docs/07-api-reference.md](docs/07-api-reference.md).

## Database

Tables: `companies`, `branches`, `users`, `roles`, `permissions`, `role_permissions`, `user_roles`, `user_permission_overrides`, `audit_logs`, `settings`, `modules`, `menu_items`, `themes`.

All tables use `id` autoincrement plus `createdAt`/`updatedAt` audit fields where applicable. Foreign keys cascade on delete where it makes sense (branches → company, user_roles → user/role, etc.). Relevant indexes are on `companyId`, `branchId`, `entity`, and `createdAt`.

## Architecture

Clean architecture, kept simple:

- **presentation** — Flutter widgets (`features/*/presentation`)
- **application/usecases** — controllers/notifiers (`features/*/application`)
- **domain** — entities (`features/*/domain`)
- **infrastructure** — API repositories (`features/*/data`)
- **shared** — common widgets (`lib/shared/widgets`)

Patterns used:
- Repository (data layer)
- Singleton (Riverpod providers for `ApiClient`, `TokenStorage`, theme + auth controllers)
- Dependency Injection (Riverpod overrides)
- Strategy (theme-aware widgets read settings; the API permission middleware composes per-request)
- Factory (`AppThemeBuilder.build` produces a `ThemeData` from settings)

## Adding a new module

1. Add a Prisma model and migration.
2. Add a route file in `backend/src/routes/<module>.js` and register it in `routes/index.js`.
3. Insert permissions for it (`<module>.view`, `<module>.create`, ...) and a menu item; the seeder’s `MODULES` array is the easiest spot.
4. Create a feature folder under `frontend/lib/features/<module>/` (data, application, domain, presentation).
5. Add the route to `frontend/lib/routing/app_router.dart`.

The dashboard sidebar populates itself from `/api/menus`, so once the menu row exists and the user has the relevant `*.view` permission, the link appears automatically.

## Phase status

- **Phase 1** — foundation: auth, RBAC, audit, seeded data, Flutter shell, dynamic theme, full CRUD for users/roles/companies/branches, audit viewer, settings, theme builder.
- **Phase 2** — real dashboard charts (audit by day + by entity), Reports module (5 seeded reports + chart/table toggle + add/edit/delete), file uploads (`POST /api/uploads/image`, served from `/uploads`, wired into the Theme Builder for logo/favicon/background).
- **Phase 3** — business-type presets (retail, restaurant, clinic, factory, finance, rental, blank), in-app **Setup Wizard**, **Database admin** (table explorer + SQL runner with audit + saved queries), **Custom Entities** with auto-generated CRUD/permissions/menus, **Templates** (capture/apply/import/export the whole setup), background image rendering on dashboard + login.
- **Phase 4.0** — **Page Builder** (`/pages`, `/pages/edit/:id` with 15 block types), **System console** (`/system`, process info + DB connection registry + Promote endpoint that rewrites `.env`, init SQL runner), **System Logs** (`/system-logs`), **Login Activity** (`/login-events`, captures every login/refresh/logout, including failed attempts with reasons), **Quick permission presets** (`view` / `view_edit` / `view_edit_delete` / `full` / `none`), theme transparency/glass settings.
- **Phase 4.1** — `PageRenderer` at `/p/:code` rendering all 15 block types, drag-drop reorder + container nesting in the builder, Theme Builder UI for transparency/glass/login overlays, login screen variants (split / centered / minimal), dashboard stacked background, quick-preset chips on every module in the role editor, sidebar merges custom pages from `/api/pages/sidebar`.
- **Phase 4.2** — **Templates v2**: capture+apply for `pages` / `reports` / `queries` (alongside existing `theme` / `business` / `full`), with parent/child block links preserved on apply. **Secondary DB pool**: SQL runner accepts a `connectionId` to query saved `DatabaseConnection` rows without restarting.
- **Phase 4.3** — **Workflows / approvals** (`/approvals`, gated by `<entity>.approve`). **Cron-scheduled report runs** (`/report-schedules`, in-process minute-tick loop, supports enum frequencies + 5-field standard cron). **Native cross-provider DB drivers** (`pg` + `mysql2`) so the SQL runner can target Postgres / MySQL secondaries from a SQLite primary without restart.
- **Phase 4.4** — **Webhooks** (HMAC-SHA256-signed POSTs, 3-attempt retry, fire-and-forget on approval transitions). **Multi-instance cron locking** (atomic claim with 5-minute stale reclaim). **Run-result retention** (`scheduled_report_runs.result` blobs auto-purged after `retentionDays`, default 30). **HTML sanitization** on the page-builder `html` block. **Typed block inspectors** for 11 block types. 58-test vitest suite.
- **Phase 4.5** — **Conditional page-block visibility**. **Approval claim handlers**. **Auto-`ALTER TABLE`** on custom-entity column edits. **Per-company theming UI**. **Docker compose** template. **i18n foundation** (locale switcher, persisted choice, RTL flips automatically). **69 tests** passing.
- **Phase 4.6** — **gen_l10n + ARBs** with the login screen translated. **Backup + restore** endpoints + `/backups` UI (SQLite). **Builder analytics**. **Mobile-shell polish**. **Route-layer tests** via extracted `buildApp()`. **83 tests**.
- **Phase 4.7** — **Negative permission tests** + **per-feature smoke tests**, self-cleaning. **Native `pg_dump` + `mysqldump`** for cloud backups. **Sidebar label translation** for all 20 core modules. **98 tests**.
- **Phase 4.8** — **Per-page translatable titles**. **Encrypted backups** (AES-256-GCM, `MCEB` v1 in-memory). **`backup.created` webhook event**. **Isolated per-suite test DB**. **102 tests**.
- **Phase 4.9** — **Streaming encryption** (`MCEB` v2 with trailer-tag, v1 read-back retained). **Built-in key rotation**. **Role label translation** (`Role.labels` JSON). **Bulk page-header migration**. **Off-site sync receiver tool** (`tools/backup-sync/`). **106 tests**.
- **Phase 4.10** — **HTTPS download endpoint with pre-signed URLs** (`GET /api/admin/backups/:name/download`, dual auth: Super Admin Bearer or `?expires&sig`; webhook payload now includes `downloadUrl` so receivers can pull cross-host). **Receiver HTTPS pull mode** (no shared filesystem required). **Roles UI label resolution** (role names flip with active locale). **ARB import/export endpoints + `/translations` UI** (edit ARBs from the TatbeeqX UI, with timestamped `.bak-*` sidecars). **119 tests** passing.
- **Phase 4.13** — **Subsystem builds v2: automated admin handover.** Closes the biggest 4.12 caveat. The build CLI now takes `--admin-username` / `--admin-password`, hashes the password with bcrypt rounds=10 in the CLI itself, and embeds a `lockdownAdmin` block in `seed.json` — **plaintext never lands on disk**. On first boot in lockdown mode, the seeder disables `superadmin` (vendor still has DB-level support access via SSH), upserts the customer's Company Admin from the pre-computed hash, and grants the `company_admin` role. Pass `--no-admin` to skip and provision manually. **159 backend + 28 receiver tests**. See [docs/44-subsystem-builds.md](docs/44-subsystem-builds.md#customer-admin-user--automated-phase-413).
- **Phase 4.14** — **Mobile shell.** iOS + Android scaffolds via `path_provider` (only new dep). Existing responsive shell handles the layout. AndroidManifest cleartext + iOS ATS exception are pre-configured for LAN dev — tighten before App Store / Play submission. See [docs/45-mobile-shell.md](docs/45-mobile-shell.md).
- **Phase 4.15** — **Templates UI + iframe-on-web + custom relations + deep i18n.** Operators edit `branding` + `modules` in the UI before exporting templates. `iframe` block renders a real `<iframe>` on web with a placeholder on desktop. Many-to-many `relations` column type with auto-managed join tables + reverse-cascade. Deep i18n cleanup pass (block inspectors / theme panels / page-builder add-panel translated). Postgres compose deferred (Docker not installed in dev env).
- **Phase 4.16** — **Code-gen pruning** for `tools/build-subsystem/`. `--prune` strips sidebar imports + GoRoutes + `routes/index.js` lines for modules absent from `template.modules`. ~30% smaller bundles on the retail preset. 15 unit tests + smoke test that re-runs `flutter analyze` against the pruned bundle.
- **Phase 4.16 follow-ups** — **Perf pass** (Gradle parallel, gzip middleware, audit-by-day SQL `GROUP BY`, settings bulk-update batched, `db_introspect` parallelized, frontend cold-boot waterfall fix). **Auth hardening** — refresh-token rotation + reuse detection (`RefreshToken` model with `replacedById` chain, theft → invalidate full chain), per-user **sessions UI** + sign-out-everywhere, **admin-token password reset** (single-use sha256-hashed, cascading session revoke on redeem), **TOTP 2FA + recovery codes** (encrypted secret at rest, 10 single-use recovery codes), per-IP login rate limit, timing-safe login compare, per-row login event audit.
- **Phase 4.17** — **Workflow engine v1+v2.** Admin-defined automation. Triggers: `record` (custom-entity insert/update/delete + filter), `event` (subscribes to `dispatchEvent` stream), `schedule` (cron), `webhook` (public `POST /api/workflows/incoming/:code` with `X-Workflow-Secret`). Actions: `set_field`, `create_record`, `http_request`, `dispatch_event`, `create_approval`, `log`, `notify_user`, `send_email`. Visual chain builder UI (advanced JSON editor preserved behind a toggle). Per-action conditions (JSON DSL — equals/notEquals/gt/in/contains/matches/composers all/any/not). `{{trigger.row.id}}` + `{{steps.<name>.<key>}}` templating. Per-workflow run + step persistence. Page-builder buttons can fire workflows by code. Template-portable. See [docs/48-workflow-engine.md](docs/48-workflow-engine.md).
- **Phase 4.18** — **In-app notifications.** Per-user `Notification` model, topbar bell with unread badge (45s poll), full `/notifications` page. Workflow `notify_user` action resolves target by `userId` | `username` | `email`. Approval decisions create both an in-app notification and an email (when SMTP up).
- **Phase 4.19 (current)** — **SMTP outbound email** via Nodemailer (vendor-neutral; Resend / Postmark / SendGrid / SES / Postfix / Gmail). Stub-mode fallback when `SMTP_HOST` is unset — system stays fully functional, emails just no-op. Self-serve `/auth/forgot-password` (anti-enumeration, rate-limited, 1h single-use token). Workflow `send_email` action. Approval-decision emails to the requester. Frontend `ForgotPasswordPage` + "Forgot password?" link on login. **28 files / 340 tests** passing.
- **Phase 4.12** — **Subsystem builds.** A vendor can capture a template (custom entities + theme + reports + branding) via `/templates`, then run [`tools/build-subsystem/build.mjs`](tools/build-subsystem/) to emit a branded, locked-down customer binary: patched Windows resources, generated `.env` with `SUBSYSTEM_LOCKDOWN=1` + `BOOT_SEED_PATH=./seed.json`, bundled `flutter build windows --release` output, and a `start.bat` that installs deps + applies the template on first boot. New backend lib (`subsystem.js`) + public `GET /api/subsystem/info` endpoint. Frontend `subsystemInfoProvider` reads it once at boot to filter the sidebar, redirect away from super-admin routes, and apply `branding.{appName, logoUrl, primaryColor}` overrides. The `template.modules` array is the runtime sidebar contract today and the future code-gen contract for trimmed-binary builds. See [docs/44-subsystem-builds.md](docs/44-subsystem-builds.md).
- **Phase 4.11** — **Operational housekeeping + i18n breadth.** **Backup retention policy on disk** — hourly cron sweep prunes `backend/backups/` by age (`system.backup_retention_days`, default 30) and count (`system.backup_retention_max_count`, default disabled), with a min-keep floor (`system.backup_retention_min_keep`, default 1). Manual trigger: `POST /api/admin/backups/sweep-retention`. Settings hot-reload — no restart needed. **Non-Node webhook verify helpers** ([`tools/webhook-verify/`](tools/webhook-verify/)) for Python, Go, PHP, Bash — stdlib-only, with a Node cross-language regression test that auto-skips missing toolchains. **Native S3 / restic uploaders** in [`tools/backup-sync/`](tools/backup-sync/) — `UPLOADER=s3` is hand-rolled SigV4 (no AWS SDK dep, supports any S3-compatible provider via `S3_ENDPOINT`); `UPLOADER=restic` spawns the binary with fail-fast at startup. Optional `KEEP_LOCAL_COPY=0` to bound disk usage. **Per-key translation editor** at `/translations/edit/:locale` replaces the JSON textarea — search, untranslated-only filter, drop-orphans-on-save, English reference column; raw-JSON dialog kept in overflow. **Full UI string migration to AppLocalizations** — ~330 hardcoded strings across 32 files migrated to `t.foo` lookups; ARB grew from 49 → ~225 keys × 3 locales (en/ar/fr) including ICU plurals with Arabic dual/few/many forms. Power-user editor surfaces (block_inspectors, theme_builder deep panels, page-builder add-panel, sql_runner internals) deliberately deferred — Super-Admin-only with low translation ROI. **Auto-heal for custom-entity tables** — `ensureTable()` recreates missing SQL tables from registered config when the registry is intact but the table was dropped (DB reset, partial restore). **139 backend + 28 receiver tests**.

## Pick a business type

When you first run the app as Super Admin, you'll land on `/setup`. Pick one of:

| Preset | Starter tables |
| --- | --- |
| Retail / POS | products, customers, suppliers, sales, payments |
| Restaurant | menu items, tables, orders, reservations, customers |
| Clinic | patients, appointments, treatments |
| Factory | products, raw materials, work orders, inventory movements, suppliers |
| Finance office | customers, invoices, accounts, transactions |
| Rental company | assets, customers, rentals, payments |
| Blank slate | nothing — define everything yourself |

Each preset auto-creates SQL tables, permissions (`<table>.{view,create,edit,delete,export,print}`), sidebar entries, and grants to Super Admin + Company Admin.

To pre-apply on seed:
```
SEED_BUSINESS_TYPE=clinic
```
in `backend/.env`, then `npm run db:reset`.

## Customize anything

- **Custom Entities** (`/custom-entities`, Super Admin) — design new tables in a UI: name, columns, types, required/unique/searchable/list flags. Each entity gets its own page at `/c/<code>` with auto-generated list + form.
- **Database** (`/database`, Super Admin) — list tables, see columns/indexes/foreign keys, preview rows, run any SQL. Read-only by default; flip the **Write mode** switch for INSERT/UPDATE/ALTER. Auth tables (`users`, `roles`, `permissions`, …) are protected. Save useful queries.
- **Theme Builder** (`/themes`, Super Admin) — colors, font, radius, shadows, gradients, login style, dashboard layout, and uploads for logo / favicon / background image. Background image now renders behind the dashboard and overlays the login hero.
- **Templates** (`/templates`, Super Admin) — capture the current theme + custom tables as a single snapshot. Re-apply later, copy JSON to share between installs, or paste JSON to import. Three flavors: theme only, business only, or full.

## Reports

Reports are stored in the `reports` table. Each row points to a server-side **builder** key — a function in [`backend/src/lib/reports.js`](backend/src/lib/reports.js). This keeps the system safe: no raw SQL is executed from user input.

Seeded reports:
- `users.by_role` — users assigned to each role
- `users.active_status` — active vs inactive count
- `companies.summary` — companies with branch and user counts
- `audit.actions_summary` — audit events grouped by action (last 30 days)
- `audit.entities_summary` — audit events grouped by target entity (last 30 days)

**Adding a new report:**
1. Add a builder function to `backend/src/lib/reports.js` that returns `{ columns, rows }`.
2. Insert a row in the `reports` table (or seed it) with that `builder` key.

A report appears at `/reports` and can be run, viewed as a table, or shown as a bar chart when there's at least one numeric column.

## File uploads

`POST /api/uploads/image` (auth required, multipart `file` field) — accepts PNG/JPEG/WebP/GIF/SVG/ICO up to 5 MB. Returns `{ url }`. Files live in `backend/uploads/` and are served at `http://<host>:4040/uploads/<filename>`.

The Theme Builder uses this for logo, favicon, and background image. Paste a local file path into the secondary input and click **Upload** — no native file picker plugin needed, so no Developer Mode requirement.
