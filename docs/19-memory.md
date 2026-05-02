# 19 — Project memory snapshot

This is a curated mirror of the **durable, non-obvious facts** about the project. The full long-form is at [`MEMORY.md`](../MEMORY.md) at the project root. This page is the human-facing companion.

> If you change something here, change `MEMORY.md` to match (and vice versa).

## Identity

- **Name**: TatbeeqX
- **Goal**: a flexible multi-company management system; same binary fits a restaurant, retail POS, clinic, factory, finance office, or rental shop. The behavior is configured (preset, custom entities, theme), not coded.
- **Default deployment**: LAN — one host, many Windows clients. **Future**: cloud, by swapping the DB connection string.

## Tech (load-bearing decisions)

- Backend: Node 20+, Express, Prisma, **SQLite (dev), Postgres/MySQL on cloud swap**, JWT (access + refresh), `bcryptjs`, `multer`.
- Frontend: Flutter 3.41 desktop-first (Windows; web also enabled), Riverpod, go_router, dio.
- **No native Flutter plugins.** This avoids the Windows symlink requirement so users do not need Developer Mode. Token storage is plain `dart:io` writing to `%APPDATA%\TatbeeqX\auth.json`. Image uploads are done by reading the file with `dart:io` and posting multipart — not via `file_picker`.
- **`bcryptjs`, not `bcrypt`.** Pure JS, no native build tools needed on Windows.
- **Plain `dart:io` for storage, not `shared_preferences`.** Same rationale.

## Auth model

- Login with username **or** email. Tokens: short access + revocable refresh.
- `users.isSuperAdmin` is a hard flag that **bypasses every permission check**. Use it sparingly.
- Effective permissions = `(union of role permissions) + per-user grants − per-user revokes`.
- Permission codes are `<module>.<action>`. Actions: `view`, `create`, `edit`, `delete`, `approve`, `export`, `print`, `manage_settings`, `manage_users`, `manage_roles`.

## What is dynamic at runtime

| Driven by DB (no code change required) | Where |
|---|---|
| Sidebar menu | `menu_items` filtered by user permissions, served from `/api/menus` |
| App theme | `themes.isActive`, served from `/api/themes/active`, applied by `MaterialApp.theme` |
| Roles + their permissions | `roles` + `role_permissions`, edited from `/roles` |
| Tables for the customer's domain | `custom_entities` + real SQL tables, designed at `/custom-entities` |
| Reports | `reports` rows + builders in `lib/reports.js` |
| Setup state | `settings.system.business_type` |

## Default seeded data

- Super Admin: `superadmin` / `ChangeMe!2026` (override via `SEED_SUPERADMIN_*`)
- 5 system roles: `super_admin`, `chairman`, `company_admin`, `manager`, `employee`
- One sample company `DEMO` with one branch `MAIN`
- One default theme: "Default Professional" (`isDefault: true` and `isActive: true`)
- 5 sample reports

## Non-obvious gotchas (worth remembering)

These are the rules that surprised someone once. Record-keeping prevents re-learning them.

1. **Prisma `upsert` cannot null a unique-side column.** Use `findFirst` then `update`/`create`. (Settings and seeder already do this.)
2. **SQLite `PRAGMA` returns BigInt.** Coerce `Number(...)` before serializing to JSON.
3. **`prisma generate` fails on Windows if the dev server holds the engine DLL.** Stop the server first.
4. **`prisma migrate dev` is non-interactive in this shell.** Use `prisma db push --accept-data-loss --skip-generate` for local schema changes.
5. **The SQL runner blocks auth tables even with Write mode on.** Auth integrity is non-negotiable.
6. **Custom entity edits do not ALTER the SQL table** — only the form/list config. Run the `ALTER` manually from `/database` if you need it. Two-step is intentional today.
7. **Two identifier validators for a reason**: strict for user-created tables, permissive for inspecting Prisma's PascalCase tables. Don't merge them.
8. **Static files are served at `/uploads/<file>`, not `/api/uploads/<file>`.** Frontend strips the `/api` suffix to build the asset URL.
9. **The Setup Wizard drives off `setupControllerProvider`.** If Super Admins land back on `/setup` after applying a preset, the controller is stale — refresh it.
10. **No native Flutter plugins.** This is the rule. The repo will not build on Windows if a plugin slips into `pubspec.yaml`.

## Phase status (today)

- **Phase 1** — foundation. ✅
- **Phase 2** — reports + uploads + real charts. ✅
- **Phase 3** — business presets, custom entities, database admin, templates. ✅
- **Phase 4.0** — page builder backend + system config + logs + login tracking + quick permission presets + theme transparency fields. ✅
- **Phase 4.1** — page renderer at `/p/:code` with 15 block types, drag-drop reorder, container nesting, theme transparency UI, login overlay rendering with style variants (split/centered/minimal) + glass card, dashboard stacked background, quick-preset chips per module in role editor, sidebar merge with `/api/pages/sidebar`. ✅
- **Phase 4.2** — Templates v2 with `pages`/`reports`/`queries` kinds (capture + apply, with two-pass block-parent linking for pages); `GET /api/templates/kinds`; secondary DB pool in `lib/db_pool.js` cached PrismaClient with overridden URL; `POST /api/db/query` accepts `connectionId`; auth-table protection scoped to primary; cross-provider guardrail. ✅
- **Phase 4.3** — Workflows / approvals (`ApprovalRequest` model, `/approvals` page, per-entity decide gate); cron-scheduled report runs (`ReportSchedule` + `ScheduledReportRun`, in-process minute-tick loop, no `node-cron` dep, 5-field standard cron parser); native cross-provider drivers (`pg`, `mysql2`) via uniform handle (`runRead`/`runWrite`/`close`) so SQL runner is provider-agnostic. ✅
- **Phase 4.4** — webhooks (HMAC-SHA256, 3-attempt retry); multi-instance cron locking (5-min stale reclaim); hourly retention sweep; HTML sanitization on PageBlock create+update; typed block inspectors for 11 types; vitest 58 tests. ✅
- **Phase 4.5** — conditional block visibility; approval claim handlers; auto-`ALTER TABLE` on entity column edits; per-company theming; Docker compose template; i18n foundation; 69 tests. ✅
- **Phase 4.6** — gen_l10n with ARBs (en/ar/fr) + login screen migrated; backup/restore endpoints; builder analytics; mobile-shell polish; route-layer tests with supertest; 83 tests / 8 files. ✅
- **Phase 4.7** — negative permission tests + per-feature smoke tests; native `pg_dump` / `mysqldump`; sidebar label translation; topbar + company/locale switcher localized; 98 tests / 10 files. ✅
- **Phase 4.8** — `Page.titles` JSON + `PageRenderer` locale resolver; encrypted backups (AES-256-GCM, `MCEB` v1 format); `backup.created` webhook event; isolated per-suite test DB via vitest globalSetup; 102 tests / 11. ✅
- **Phase 4.9** — streaming encryption (`MCEB` v2 trailer-tag, flat memory); built-in key rotation; `Role.labels` JSON seeded en/ar/fr; bulk page-header migration; off-site sync receiver under `tools/backup-sync/`; 106 tests / 11. ✅
- **Phase 4.10** — HTTPS download endpoint with HMAC-signed URLs (`GET /api/admin/backups/:name/download`, dual auth: Super Admin Bearer OR `?expires&sig`); webhook payload includes `downloadUrl`; receiver tool HTTPS pull mode (cross-host); roles UI resolves `role.labels[localeCode]`; ARB import/export endpoints + `/translations` Super Admin page (edit/export/new-locale with `.bak-*` sidecars); 119 tests / 13 files. ✅ **Current iteration.**
- **Phase 4.11** — mobile shell, full UI string migration, native S3/restic uploaders, per-key translation editor, backup retention policy. (proposed)
- See [18-phases.md](18-phases.md) for the canonical phase tracker.

## How a typical install looks

```
Host PC (Windows):
  backend/                      ← `npm start`, port 4000
    prisma/dev.db               ← single source of truth
    uploads/                    ← logos, favicons, backgrounds
  Windows Firewall: TCP 4000 inbound allowed

Each client PC (Windows):
  TatbeeqX.exe (built with --dart-define=API_BASE_URL=http://192.168.x.x:4000/api)
  %APPDATA%\TatbeeqX\auth.json   ← tokens
```

## Where things are

| Concern | File |
|---|---|
| Schema | [`backend/prisma/schema.prisma`](../backend/prisma/schema.prisma) |
| Seed | [`backend/prisma/seed.js`](../backend/prisma/seed.js) |
| Permission resolver | [`backend/src/lib/permissions.js`](../backend/src/lib/permissions.js) |
| Audit | [`backend/src/lib/audit.js`](../backend/src/lib/audit.js) |
| SQL runner | [`backend/src/lib/sql_runner.js`](../backend/src/lib/sql_runner.js) |
| Custom entity engine | [`backend/src/lib/custom_entity_engine.js`](../backend/src/lib/custom_entity_engine.js) |
| Business presets | [`backend/src/lib/business_presets.js`](../backend/src/lib/business_presets.js) |
| Reports registry | [`backend/src/lib/reports.js`](../backend/src/lib/reports.js) |
| Templates | [`backend/src/lib/templates.js`](../backend/src/lib/templates.js) |
| API base URL | [`frontend/lib/core/config/app_config.dart`](../frontend/lib/core/config/app_config.dart) |
| Token storage | [`frontend/lib/core/storage/`](../frontend/lib/core/storage/) |
| Theme application | [`frontend/lib/core/theme/`](../frontend/lib/core/theme/) |
| Router + auth guard | [`frontend/lib/routing/app_router.dart`](../frontend/lib/routing/app_router.dart) |
| Upload widget | [`frontend/lib/shared/widgets/local_file_upload_field.dart`](../frontend/lib/shared/widgets/local_file_upload_field.dart) |
