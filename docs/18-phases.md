# 18 — Phase status

This is the **single source of truth for "where are we?"**. If you only read one doc to find out where the project stands, this is it.

> Phase numbering matches `MEMORY.md`. The 5-step plan in the original `New Text Document.txt` was the *initial scaffold plan* and has long since been superseded.

---

## ✅ Phase 1 — Foundation (DONE)

**Backend**
- `src/config/env.js`, lib helpers (`prisma`, `jwt`, `password`, `permissions`, `audit`, `http`)
- Middleware (`auth`, `permission`, `error`, `validate`)
- Routes: `auth`, `users`, `roles`, `permissions`, `companies`, `branches`, `menus`, `audit`, `settings`, `themes`, `dashboard`, plus `index.js`
- `server.js` (Express entry; serves `/api` and `/uploads` static)
- `prisma/seed.js` — Super Admin, 5 default roles, full permission set, modules + menu, sample company/branch, default professional theme

**Flutter**
- `pubspec.yaml`, `analysis_options.yaml`
- `main.dart`, `app.dart`
- `core/config/app_config.dart` (LAN swap point)
- `core/network/api_client.dart` (dio + interceptors)
- `core/storage/` (plain `dart:io` token storage — no plugins)
- `core/theme/` (`ThemeSettings`, `AppThemeBuilder`, `ThemeController`)
- `routing/app_router.dart` (go_router with auth guard)

**Auth + shell**
- Login page + `AuthController` + `AuthRepository`
- Dashboard shell with dynamic sidebar from `/api/menus`, top bar with user/company, responsive layout

**Feature pages**
- Users, Roles + permission matrix, Companies/Branches, Audit log viewer, Settings, Theme Builder (Super Admin only)
- Dashboard page with cards + chart placeholders

---

## ✅ Phase 2 — Reports + uploads + real charts (DONE)

- Real dashboard charts: audit-by-day and audit-by-entity, both backed by `/api/dashboard/*` endpoints
- Reports module:
  - Backend registry of builders in `lib/reports.js`
  - 5 seeded reports: `users.by_role`, `users.active_status`, `companies.summary`, `audit.actions_summary`, `audit.entities_summary`
  - Frontend runner page with table ↔ bar-chart toggle
  - Add/edit/delete UI for custom reports
- File uploads:
  - `POST /api/uploads/image` (5 MB max, image MIME allowlist)
  - Files served at `/uploads/<file>`
  - Theme Builder integrates `LocalFileUploadField` for logo / favicon / background image (no native plugin — pastes a Windows path, reads via `dart:io`, uploads multipart)

---

## ✅ Phase 3 — Customization platform (DONE)

This is what was last shipped. The system can now be re-purposed without writing code.

- **Business presets** in [`backend/src/lib/business_presets.js`](../backend/src/lib/business_presets.js): retail, restaurant, clinic, factory, finance, rental, blank
- **Setup Wizard** at `/setup`. App router redirects Super Admins there until a preset is applied.
- **Custom Entities** at `/custom-entities`: design tables in a UI; each entity gets `<code>.{view,create,edit,delete,export,print}` permissions, a sidebar entry, a real SQL table, and a generic CRUD page at `/c/<code>`
- **Database admin** at `/database`: table explorer + SQL runner with safety guards (read-only default, auth-table protection, length cap, result truncation, full audit log)
- **Templates** at `/templates`: capture / apply / import / export of theme + business setup, in three flavors (`theme`, `business`, `full`)
- **Background image rendering**: themes with a `backgroundImageUrl` render the image behind the dashboard and overlaid on the login hero

The system is feature-complete for its original "configurable, no-code" goal.

---

## 🚧 Phase 4 — Supreme configurability — **CURRENT PHASE**

The asks: configure the database from the UI, design custom pages with blocks/buttons/images, customize *everything* about styling (transparency, opacity, overlays, glass effects), see the full system + login + audit logs, apply quick permission presets (view / view+edit / view+edit+delete / full / none).

### Phase 4.0 — Foundation (DONE this iteration)

**Schema additions**
- `Page`, `PageBlock` — page builder
- `LoginEvent` — login/logout/refresh tracking
- `SystemLog` — server-side event log
- `DatabaseConnection` — saved DB connections

**Backend**
- [`lib/system_log.js`](../backend/src/lib/system_log.js) — `logSystem(level, source, message, context)` and `recordLoginEvent(...)`
- [`lib/env_writer.js`](../backend/src/lib/env_writer.js) — safely read/write `.env` keys with timestamped backups in `.env-backups/`
- Routes: [pages.js](../backend/src/routes/pages.js), [system_logs.js](../backend/src/routes/system_logs.js), [login_events.js](../backend/src/routes/login_events.js), [system.js](../backend/src/routes/system.js)
- `POST /api/roles/:id/presets` — quick permission presets (`view`, `view_edit`, `view_edit_delete`, `full`, `none`) per module, with audit
- `POST /api/system/database/connections/:id/promote` — rewrites `DATABASE_URL` in `.env` (with backup) and marks connection primary
- `POST /api/system/database/sql/init` — multi-statement init SQL runner
- `/auth/login` records `LoginEvent` on success and on every failure mode (`unknown_user` / `inactive_user` / `bad_password`)
- `/auth/refresh` and a new `/auth/logout` also recorded

**Theme (data-only — no schema migration)**
- `surfaceOpacity`, `sidebarOpacity`, `topbarOpacity`, `cardOpacity`, `backgroundOpacity`
- `backgroundBlur`, `backgroundOverlayColor`, `backgroundOverlayOpacity`
- `loginOverlayColor`, `loginOverlayOpacity`
- `enableGlass`, `glassBlur`, `glassTint`, `glassTintOpacity`

**Seed**
- New modules with menus: `pages` (`/pages`), `system` (`/system`), `system_logs` (`/system-logs`), `login_events` (`/login-events`)
- Default theme extended with the transparency/glass fields

**Frontend**
- `/system` — process info cards + DB connection list + Add/Promote/Delete + multi-statement init SQL box
- `/system-logs` — paginated viewer with level/source/search filters and a Clear button
- `/login-events` — paginated viewer with event/success filters
- `/pages` — page list with new/delete
- `/pages/edit/:id` — block-based builder with palette of 15 block types and JSON config editor
- Router wired

**Docs**
- [21-page-builder.md](21-page-builder.md), [22-system-config.md](22-system-config.md), [23-logs.md](23-logs.md), [24-quick-presets.md](24-quick-presets.md)

### ✅ Phase 4.1 — Renderers + UX (DONE)

- ✅ **`PageRenderer` widget** — fetches `/api/pages/by-route?code=…` (or `?route=…`) and renders 15 block types as real Flutter widgets (text, heading, image, button, card, container, divider, spacer, list, table, chart, iframe placeholder, html, custom_entity_list, report). Charts render as custom-painted bar/pie lists — **no `fl_chart` dep**, keeping the no-plugin philosophy.
- ✅ **Mounted at `/p/:slug`** — sidebar entries for custom pages link here. Backend `/api/pages/by-route` extended to accept `?code=` alongside `?route=`.
- ✅ **Drag-and-drop reordering** in the builder using `ReorderableListView` with explicit `ReorderableDragStartListener` handles. Calls `POST /api/pages/:id/reorder` server-side.
- ✅ **Container/nesting in the UI** — every block has a "Move to container" popup that lets you assign it to any `container` or `card` block (or back to top level). Children render indented underneath their parent.
- ✅ **Theme Builder transparency UI** — three new sections (**Transparency & overlay**, **Glass effect**, **Login screen**) with sliders and color pickers for every Phase 4.0 field.
- ✅ **Login screen rebuilt** — supports `split` / `centered` / `minimal` styles, applies background image + overlay color/opacity, renders the form inside a glass card when `enableGlass` is on.
- ✅ **Dashboard shell** — stacked background (image → blur → overlay), glass-capable sidebar honouring `enableGlass` + `glassBlur` + `glassTint`, topbar honours `topbarOpacity`. `theme_data_builder.dart` honours `surfaceOpacity` and `cardOpacity` so Material widgets actually look transparent.
- ✅ **Quick-preset chips on every module** in the role editor: **None / View / View + edit / View + edit + delete / Full**. One click rewrites the chip selection for that module.
- ✅ **Sidebar merge** — `MenuController` loads `/api/pages/sidebar` and merges user-defined pages into the sidebar. Custom pages link to `/p/:code` (avoids collisions with built-in routes).

### Phase 4.1 — still open / nice-to-have

- Typed inspector per block type (color pickers, route picker, image picker) — today the builder still uses a universal JSON editor. Functional, just not polished.

### ✅ Phase 4.2 — Templates v2 + secondary DBs (DONE)

- ✅ **Templates v2** — `SUPPORTED_KINDS` extended to `theme`, `business`, `pages`, `reports`, `queries`, `full`. Capture serializes the matching subset; apply upserts intelligently (theme → new active row; business → `registerCustomEntity`; pages → upsert by code, delete+recreate blocks with two-pass parent linking; reports → upsert by code; queries → upsert by name).
- ✅ **`GET /api/templates/kinds`** — canonical list endpoint for UI consumers.
- ✅ **Secondary DB pool** in [`lib/db_pool.js`](../backend/src/lib/db_pool.js) — `getClientFor(connectionId)` returns a cached `PrismaClient` with `datasources.db.url` overridden, runs a `SELECT 1` probe to fail fast on bad URLs.
- ✅ **SQL runner accepts `connectionId`** — `POST /api/db/query` now takes `{ sql, allowWrite, connectionId }`. Auth-table protection only applies to primary (secondaries don't own this app's auth schema). Read-only default still enforced.
- ✅ **Cross-provider guardrail** — Prisma binds the SQL connector at compile time, so the pool rejects secondaries whose provider doesn't match the primary with a clear message instead of an obscure runtime error.

### ✅ Phase 4.3 — Workflows + scheduled reports + native cross-provider drivers (DONE)

- ✅ **Workflows / approvals** — `ApprovalRequest` model with pending → approved/rejected/cancelled lifecycle. `/approvals` page with filters + per-row Approve / Reject buttons + new-request dialog. Decide endpoints check `<entity>.approve` (the original entity, scoped per-request) on top of `approvals.view`. Cancel limited to requester or Super Admin. Every transition audited (`request` / `approve` / `reject` / `cancel`).
- ✅ **Cron-scheduled report runs** — `ReportSchedule` + `ScheduledReportRun` models. In-process loop in [`lib/cron.js`](../backend/src/lib/cron.js) ticks every minute, runs all due schedules, stores results. Supports `every_minute` / `every_5_minutes` / `hourly` / `daily` / `weekly` / `monthly` plus a 5-field standard cron parser (no `node-cron` dep). `/report-schedules` page with create / enable-disable toggle / Run-now / recent-runs viewer / delete.
- ✅ **Native cross-provider drivers** — `pg` and `mysql2` installed and wired into [`lib/db_pool.js`](../backend/src/lib/db_pool.js). The pool returns a uniform handle (`runRead` / `runWrite` / `close` / `kind`) regardless of underlying driver; SQL runner uses it for any secondary connection. Same-provider still uses cached PrismaClients. `sqlserver` and `mongodb` rejected with a clear message.
- ✅ **Server boot** wires `startCronLoop()`. First tick fires 5s after boot to pick up overdue schedules.
- ✅ **New seed entries** — `approvals` and `report_schedules` modules with their menu entries; existing roles auto-pick up the new permissions on re-seed.

### ✅ Phase 4.4 — Operations + DX (DONE)

- ✅ **Webhooks** — `WebhookSubscription` + `WebhookDelivery` models. HMAC-SHA256 signed POSTs (`X-Money-Signature: sha256=…`), 3-attempt retry with backoff (immediate / 5 s / 30 s), 10 s timeout per attempt, fire-and-forget from the producing route. Approval `request`/`approve`/`reject`/`cancel` and a synthetic `webhook.test` event are wired. `/webhooks` page exposes CRUD + Send-test + delivery history. Secrets revealed once on create, redacted thereafter.
- ✅ **Multi-instance cron coordination** — claim-based locking on `ReportSchedule` via atomic `updateMany`. `lockedBy` (worker id) + `lockedAt`. Stale locks older than 5 minutes are reclaimable. Two API instances pointed at the same DB will not double-run.
- ✅ **Retention sweep** — `purgeOldRunResults()` runs once an hour, nulls out `ScheduledReportRun.result` blobs older than the schedule's `retentionDays` (or `settings.system.report_retention_days`, default 30 days). Row preserved with `resultPurged: true` so audit history isn't lost.
- ✅ **HTML sanitization** — `sanitize-html` package + `lib/html_sanitize.js` wrapper. PageBlock create AND update sanitize when `type === 'html'`. Strips scripts, on-handlers, `javascript:` URLs.
- ✅ **Typed block inspectors** — typed dialogs for `text`, `heading`, `image`, `button`, `card`, `spacer`, `iframe`, `html`, `report`, `custom_entity_list`, `divider`. The page builder dispatches via `inspectorFor(type)` and falls back to the JSON editor for unknown types.
- ✅ **Test suite** — `vitest` configured. 58 tests across 5 files: `cron.test.js` (computeNext + cron parser invariants), `sql_runner.test.js` (read-only + auth-table guards, primary vs secondary), `permissions.test.js` (effective resolution), `html_sanitize.test.js` (sanitization invariants), `db_pool.test.js` (provider inference). `npm test` runs them all.

### ✅ Phase 4.5 — Polish + scale (DONE)

- ✅ **Conditional block visibility** — `PageRenderer` evaluates `config.visibleWhen` against `AuthState`. Supports `permission` / `permissions` + `match` (any/all) / `isSuperAdmin` / `isLoggedIn`. See [28-conditional-visibility.md](28-conditional-visibility.md).
- ✅ **Approval claim handlers** — `lib/approval_handlers.js` with `registerApprovalHandler(entity, fn, name?)`. Wired into the decide endpoints AFTER the audit log and BEFORE the HTTP response. Errors captured per-handler so one bad handler doesn't break the chain. See [29-claim-handlers.md](29-claim-handlers.md).
- ✅ **Auto-`ALTER TABLE`** — `diffColumns(old, new)` + `applyColumnDiff(tableName, diff)` in `custom_entity_engine.js`. `PUT /api/custom-entities/:id` runs the diff and applies `ADD COLUMN` / `DROP COLUMN` automatically. Type changes flagged as `skipped` with a reason (SQLite needs a rebuild). Returns the schema summary in the response.
- ✅ **Per-company theming UI** — `_CompanySwitcher` in the topbar; `themeControllerProvider.loadActive(companyId: ...)` accepts a target company. Backend already filtered by `companyId` since Phase 1.
- ✅ **Docker compose** — `backend/Dockerfile`, `.dockerignore`, `docker-compose.yml`, and `deploy/nginx.conf`. Two services (api + web), named volumes for data + uploads, Postgres service ready to uncomment. See [30-deploy-docker.md](30-deploy-docker.md).
- ✅ **i18n foundation** — `flutter_localizations` + `intl ^0.20.2`, `LocaleController` persisting choice to `TokenStorage` (extended with `readKey`/`writeKey`), `_LocaleSwitcher` in the topbar, MaterialApp wired with `localizationsDelegates` + `supportedLocales` (en/ar/fr). Layout flips LTR↔RTL automatically on locale change. String translation deferred until ARBs are filled in. See [31-i18n.md](31-i18n.md).
- ✅ **Tests grow to 69** (was 58) — added `custom_entity_engine.test.js` for `diffColumns` invariants and `approval_handlers.test.js` for the registry/error-capture invariants.

### ✅ Phase 4.6 — Operational depth (DONE)

- ✅ **gen_l10n + ARBs** — `flutter.generate: true`, `l10n.yaml`, `app_en.arb` / `app_ar.arb` / `app_fr.arb`. `AppLocalizations.delegate` wired into MaterialApp. Login screen migrated to `t.signIn` / `t.password` / etc. — picks up Arabic/French translations automatically. RTL layout flips when Arabic is selected.
- ✅ **Backup + restore endpoints** — `lib/backup.js` + `routes/admin.js`. SQLite-only path today: file-copy to `backend/backups/<timestamp>[-label].db`; restore disconnects Prisma, atomically renames the staged file onto the live DB, returns `restartRequired: true`. `/backups` page with create/restore/delete + size + timestamps.
- ✅ **Builder analytics** — `GET /api/pages/analytics` returns `{ pageCount, blockCount, blocksPerPage, byType, emptyPages }`. Surfaced as a panel above the page list.
- ✅ **Mobile shell polish** — `_TopBar` hides the user's name+role on narrow widths so the row doesn't overflow; sidebar already swapped to a Drawer below 800px width since Phase 1.
- ✅ **Route-layer tests** — `supertest` installed (dev dep). `src/server.js` refactored to use `buildApp()` from `lib/app.js` so tests mount the app without binding a port. `tests/routes.test.js` covers `/health`, `/auth/login`, `/auth/me`, `/auth/refresh`, `/permissions`, `/menus`, `/templates/kinds`, `/db/query` (read-only + auth-table block). **83 tests / 8 files** total (was 69 / 7).

### ✅ Phase 4.7 — Test depth + cloud backups + label translation (DONE)

- ✅ **Negative permission tests** — `tests/routes_permissions.test.js` (8 tests). Provisions a fixture user with no roles, confirms 403 on every Super-Admin-only endpoint. Self-cleaning.
- ✅ **Per-feature smoke tests** — `tests/routes_features.test.js` (7 tests). Pages CRUD + reorder, HTML sanitization, approval lifecycle, webhook test-fire + delivery history, schedule run-now, backup create/list/delete. All self-cleaning. Bonus: `webhook.test` added to `SUPPORTED_EVENTS` so subscriptions can target it.
- ✅ **Native pg_dump / mysqldump** — `lib/backup.js` rewritten with provider detection. SQLite still file-copies. Postgres spawns `pg_dump` with `PGPASSWORD` env. MySQL spawns `mysqldump`. Streams stdout to a `.sql` file. Clear errors when binary not on PATH. In-process restore still SQLite-only; pg/mysql `.sql` dumps restored from the host. See [36-native-backups.md](36-native-backups.md).
- ✅ **Sidebar label translation** — `MenuItem.labels` JSON column populated by `MENU_LABELS` map (en/ar/fr for all 20 modules). `/api/menus` returns the JSON. `MenuItemNode.labelFor(localeCode)` resolves with English fallback. Dashboard sidebar passes the active locale through.
- ✅ **More UI strings localized** — topbar (`Sign out`, `Account`, `Switch company`, `No company`, `— Global theme —`, `Language`, role labels) all read from `AppLocalizations`.
- ✅ **Tests** — **98 / 10 files** (was 83 / 8). +15 tests this iteration.

### ✅ Phase 4.8 — Multilingual data + crypto + test isolation (DONE)

- ✅ **Per-page translatable titles** — `Page.titles` JSON column added; pages route reads/writes it; `PageRenderer` resolves the right title via `_resolveTitle(page, localeCode)` with fallback to canonical `title`. See [32-i18n-strings.md](32-i18n-strings.md).
- ✅ **Encrypted backups** — optional AES-256-GCM via `BACKUP_ENCRYPTION_KEY`. Self-contained on-disk format `MCEB` (magic + version + salt + iv + authTag + ciphertext). Hex / base64 / passphrase-with-PBKDF2 key formats. Restore decrypts to staging then atomically renames. Receiver of `backup.created` webhook gets `encrypted: true|false`. See [37-encrypted-backups.md](37-encrypted-backups.md).
- ✅ **`backup.created` webhook event** — `lib/backup.js` calls `fireAndForget('backup.created', { name, path, size, encrypted })` after every successful backup. `webhooks` route's `SUPPORTED_EVENTS` updated. Off-site sync now wires through the existing webhook infra rather than building one bespoke uploader.
- ✅ **More UI strings localized** — backups page header (`Backups`, `New`, `Refresh`, error labels) read from `AppLocalizations`.
- ✅ **Isolated per-suite test DB** — vitest `globalSetup` (`tests/setup.js` + `vitest.config.js`) copies `prisma/dev.db` to a per-run temp file and points `DATABASE_URL` at it before any test imports Prisma. Self-test verified the dev DB is unchanged after `npm test`. See [38-test-isolation.md](38-test-isolation.md).
- ✅ **Tests grow to 102 / 11 files** (was 98 / 10) — added `backup_encryption.test.js` (4 tests).

### ✅ Phase 4.9 — Crypto polish + role i18n + sync receiver (DONE)

- ✅ **Streaming encryption + v2 format** — auth tag moved to file trailer (v2). New writer streams plaintext through the cipher straight to disk via `pipeline()` — memory stays flat regardless of source size. Reader detects v1 vs v2 by version byte; v1 stays in-memory (legacy). Round-trip + tamper-detection tests added. See [37-encrypted-backups.md](37-encrypted-backups.md).
- ✅ **`exports`** for `encryptStreamWithKey` and `decryptBackupToWithKey` so downstream tools (CLI scripts, the rotation routine) can pass an explicit key without polluting the env.
- ✅ **Built-in key rotation** — `POST /api/admin/backups/rotate-encryption` re-encrypts every `.enc` file with a new key, then writes `BACKUP_ENCRYPTION_KEY=<new>` to `.env` via the env_writer (with a timestamped backup). All-or-nothing: a partial failure leaves `.env` untouched. Returns `restartRequired: true`. See [39-key-rotation.md](39-key-rotation.md).
- ✅ **Role label translation** — `Role.labels` JSON column added; seed populates en/ar/fr for the 5 system roles; `/api/roles` DTO returns the parsed map. Frontend can resolve via the same pattern as `MenuItemNode.labelFor(localeCode)`.
- ✅ **Bulk page-header migration** — audit, dashboard, roles, reports, backups page headers read from `AppLocalizations` (`t.audit`, `t.dashboard`, `t.roles`, `t.reports`, `t.backups`). Fallback to English happens automatically when an ARB entry is missing.
- ✅ **Off-site sync receiver tool** — new [`tools/backup-sync/`](../tools/backup-sync/) standalone Node service. Listens for `backup.created`, verifies HMAC, copies the referenced file to a configurable `DEST_DIR`. Pairs with whatever uploader you already trust (rclone, restic, az-cli). See [40-offsite-sync.md](40-offsite-sync.md).
- ✅ **Tests grow to 106 / 11 files** (was 102 / 11) — added round-trip encrypt/decrypt + tamper-detection + key-rotation tests.

### ✅ Phase 4.10 — Cross-host sync + content management (DONE)

- ✅ **HTTPS download endpoint with pre-signed URLs** — `GET /api/admin/backups/:name/download`, dual auth (Super Admin Bearer token OR `?expires&sig` HMAC). Mounted before the global `authenticate` middleware so signed-URL clients don't fail JWT. Configurable via `BACKUP_DOWNLOAD_SECRET` + `BACKUP_PUBLIC_URL`. Default TTL 1 h. See [41-cross-host-sync.md](41-cross-host-sync.md).
- ✅ **Webhook payload includes `downloadUrl`** — emitted by `lib/backup.js` when signing is enabled, so receivers can pull cross-host without a shared filesystem.
- ✅ **Receiver HTTPS pull mode** — `tools/backup-sync/receiver.js` falls back to streaming the file from `payload.downloadUrl` when `SRC_DIR` is unreachable, or always when `PULL_VIA_HTTP=1`. Uses Node 18+ `fetch` with `AbortSignal.timeout` and a `.partial-<ts>` staging file.
- ✅ **Roles UI label resolution** — `_RoleCard` reads `role.labels[localeCode]` with English fallback. Combined with the `Role.labels` JSON from Phase 4.9, role names now flip with the active locale.
- ✅ **ARB import/export endpoints + Translations UI** — `GET/PUT /api/admin/translations[/:locale]` (Super Admin only). Strips/restamps `@@locale`, writes timestamped `.bak-*` sidecars, lists `isSupported` flag. New `/translations` page at sidebar position 100 with edit / export / new-locale dialogs. Saves remind the operator that `flutter gen-l10n` + rebuild is required for changes to take effect. See [42-translation-management.md](42-translation-management.md).
- ✅ **Tests grow to 119 / 13 files** (was 106 / 11) — added 7 signed-URL tests (`tests/signed_url.test.js`) and 6 translation tests (`tests/translations.test.js`).

### ✅ Phase 4.11 — Operational housekeeping + i18n breadth (DONE)

- ✅ **Backup retention policy on disk** — hourly cron sweep prunes `backend/backups/` by age (`system.backup_retention_days`, default 30) and count (`system.backup_retention_max_count`, default disabled), with a min-keep floor (`system.backup_retention_min_keep`, default 1). Manual trigger: `POST /api/admin/backups/sweep-retention` (Super Admin). Settings hot-reload — no restart needed. Webhooks are NOT fired on retention deletion (receivers maintain their own retention). See [33-backups.md](33-backups.md#retention-policy).
- ✅ **Webhook signature verification helpers for non-Node receivers** — `tools/webhook-verify/` ships stdlib-only reference implementations for Python, Go, PHP, and Bash. Each exposes `verify(rawBody, signatureHeader, secret) → bool` using language-native constant-time compares, includes a self-contained unit test, and works as a CLI for the cross-language regression test in `backend/tests/webhook_verify_helpers.test.js` — which spawns each helper, asserts good/tampered exit codes, and skips languages whose toolchain isn't on PATH. See [tools/webhook-verify/README.md](../tools/webhook-verify/README.md).
- ✅ **Native S3 / restic uploaders inside the receiver** — `tools/backup-sync/` now does direct off-site delivery without the rclone hand-off. **S3 mode** (`UPLOADER=s3`) is hand-rolled SigV4 PUT over native `fetch`, no AWS SDK dep, supports any S3-compatible provider via `S3_ENDPOINT` + path-style addressing (B2 / Wasabi / MinIO / R2). **Restic mode** (`UPLOADER=restic`) spawns the `restic` binary; the receiver fails-fast at startup if the binary isn't on PATH. Optional `KEEP_LOCAL_COPY=0` unlinks the `DEST_DIR` file after a successful upload to bound disk usage; failed uploads always preserve the local copy. Receiver tests: 28 (SigV4 vs AWS published vector, S3 PUT shape against local stub, restic dispatch via injected `spawn`, signature + acquisition + upload code paths via supertest). See [tools/backup-sync/README.md](../tools/backup-sync/README.md).
- ✅ **Per-key translation editor** — replaces the JSON textarea on `/translations`. New page `/translations/edit/:locale` shows one card per ARB key with English reference + editable target value + badges for modified / untranslated / orphan. Search filter, "untranslated only" toggle, "drop orphans on save" toggle (non-en only). Header counter shows X of Y keys not yet translated. Backend unchanged — same `PUT /api/admin/translations/:locale`. Legacy raw-JSON dialog kept as an overflow-menu option for power users. See [42-translation-management.md](42-translation-management.md#per-key-editor-phase-411).
- ✅ **Full UI string migration to AppLocalizations** — ~330 hardcoded user-facing strings across 32 frontend files migrated to `t.foo` lookups in 3 batches. ARB grew from 49 → ~225 keys × 3 locales (en/ar/fr) = ~675 entries. Includes ICU plural rules with Arabic dual/few/many forms (`permissionsCount`, `usersCount`, `branchesCount`, `starterTablesCount`, `columnsCount`). Covers: shared widgets, all CRUD pages (users/companies/branches/roles/settings), audit + logs viewers, backups, dashboard, reports, webhooks, approvals, setup, custom entities, custom records, templates, themes, pages, system, database top-level. **Deliberate scope cut**: deep editor surfaces (block_inspectors.dart's 15+ inspectors, page_builder_page.dart's `_blockTypeLabels` and add-block panel, theme_builder_page.dart's color-picker / typography / glass panels, sql_runner_panel.dart internals, page_renderer.dart runtime messages) stay English — Super Admin-only power-user surfaces with high translation cost and low ROI. Future phase if there's demand. See [32-i18n-strings.md](32-i18n-strings.md).
- ✅ **Custom-entity table auto-heal** — `ensureTable(entity)` in `lib/custom_entity_engine.js` recreates a missing SQL table from the registered column config when the registry row exists but the table doesn't (typically a DB reset / partial restore). `CREATE TABLE IF NOT EXISTS` is idempotent; first heal logs `warn` to system_logs. Wired into all CRUD operations (listRows / getRow / insertRow / updateRow / deleteRow). Fixes the user-reported "no such table: suppliers" 500s. 4 tests added in `tests/custom_entity_engine.test.js`.
- ✅ **Sidebar overflow fix** at `dashboard_shell.dart:157` — collapsed sidebar (72 px) was rendering wallet icon + name + toggle in a Row, overflowing by 18 px. Now collapsed mode shows only a centered toggle; expanded mode unchanged.
- ✅ **Tests grow to 139 / 15 files** (was 119 / 13) — 7 retention tests, 9 cross-language webhook verifier tests (4 Python + 4 Bash + 1 sanity; Go + PHP run on machines with those toolchains), 4 custom-entity auto-heal tests. Receiver-side tests live in `tools/backup-sync/tests/` (28 tests / 4 files) — separate vitest run. Frontend has no widget-test suite, so UI changes are verified via `flutter analyze` (clean) plus operator smoke-test on the desktop build.

### ✅ Phase 4.12 — Subsystem builds (DONE)

- ✅ **Backend lockdown** — `SUBSYSTEM_LOCKDOWN=1` env var + `lib/subsystem.js` exposing `isLockdown()`, `getSubsystemInfo()`, `setSubsystemInfo()`. New public `GET /api/subsystem/info` endpoint surfaces the lockdown flag, declared modules, and branding overrides. Super-admin-only routes stay gated by `requireSuperAdmin()`; the customer's user routes already filter out `isSuperAdmin` from request bodies, so the customer-admin ceiling is enforced at the API surface. 11 tests in `tests/subsystem.test.js`.
- ✅ **Template enrichment** — captures bumped to v3 (v2 still applies cleanly). `kind: 'full' | 'business'` templates carry optional `modules` (sidebar filter contract — also the future code-gen contract) and `branding` (appName / logoUrl / primaryColor / iconPath). Apply path persists them via `setSubsystemInfo()`.
- ✅ **First-boot seeder** — when `BOOT_SEED_PATH` env var is set, `bootSeedIfNeeded()` reads the JSON template at that path on server start and calls `applyTemplateData()` once. Marker row in `settings` (`system.boot_seed_applied`) makes subsequent restarts a no-op. 5 tests in `tests/boot_seeder.test.js`.
- ✅ **Frontend lockdown** — new `subsystemInfoProvider` (FutureProvider) loads `/subsystem/info` once at boot. Router redirect blocks `/system`, `/system-logs`, `/database`, `/custom-entities`, `/templates`, `/themes`, `/pages`, `/translations` in lockdown mode. Sidebar filters the same routes (cosmetic for vendor super-admin support sessions). Branding overrides (appName / logoUrl / primaryColor) apply through `theme.copyWith({...})` in `app.dart` so they take effect at MaterialApp.title + ThemeData level.
- ✅ **`tools/build-subsystem/build.mjs` CLI** — takes `--template <file>` + `--out <dir>` + optional `--name`, stages a working copy of `backend/` + `frontend/`, patches `windows/runner/Runner.rc` (FileDescription / InternalName / OriginalFilename / ProductName), optionally swaps `app_icon.ico` from `branding.iconPath`, writes a generated `.env` with `SUBSYSTEM_LOCKDOWN=1` + `BOOT_SEED_PATH=./seed.json` + fresh JWT secrets, runs `flutter build windows --release` (skip with `--no-build`), and assembles a final `<out>/<slug>/` bundle with `backend/`, `app/<slug>.exe`, `start.bat`, `README.md`, and `seed.json`. Smoke-tested with `--no-build` against a sample template.
- ✅ **Tests grow to 155 / 17 files** (was 139 / 15) — 11 subsystem + 5 boot_seeder. Frontend verified via `flutter analyze` (clean). See [44-subsystem-builds.md](44-subsystem-builds.md).

### ✅ Phase 4.13 — Subsystem builds v2 (DONE)

Closes the biggest Phase 4.12 caveat: vendor used to need to manually disable the `superadmin` user and create a Company Admin via SQL before handing the bundle over. The CLI now does this automatically — and crucially, the customer's admin password is **bcrypt-hashed in the CLI** before being written to `seed.json`, so plaintext never lands on disk.

- ✅ **`tools/build-subsystem/build.mjs` v0.2.0** — new flags `--admin-username` (default `admin`), `--admin-password` (required unless `--no-admin`), `--admin-fullname`, `--admin-email`. CLI hashes with `bcryptjs` rounds=10 (matches the backend's `lib/password.js`) and embeds `lockdownAdmin: {username, fullName, email, passwordHash}` into the bundled `seed.json`. Plaintext is wiped from `args.adminPassword` after hashing as a defensive memory-clear.
- ✅ **Boot seeder handover** — `applyLockdownAdmin()` in `lib/boot_seeder.js` runs only when `SUBSYSTEM_LOCKDOWN=1` AND the seed carries `lockdownAdmin`. Disables `superadmin` (vendor still has DB-level restore for support: `UPDATE users SET isActive = 1`), upserts the Company Admin with the pre-computed hash (no re-hashing), grants the `company_admin` role idempotently. Re-applying on a non-locked install is a no-op for the admin handover (the operator's super-admin stays untouched).
- ✅ **No plaintext on disk** — verified by smoke-test: `grep -r "<password>" <bundle-dir>/` returns empty after build. The `seed.json` contains only the bcrypt hash; `system.boot_seed_applied` only stores a timestamp.
- ✅ **Tests grow to 159 / 17 files** (was 155): 4 new cases in `tests/boot_seeder.test.js` covering the lockdownAdmin flow, the lockdown-only gate, missing-hash rejection, and idempotent re-apply against an existing user. See [44-subsystem-builds.md](44-subsystem-builds.md#customer-admin-user--automated-phase-413).

### ✅ Phase 4.14 — Mobile shell (DONE) — **CURRENT**

Closes the last Phase 4.11 carry-over. The Flutter app now runs on iOS and Android in addition to Windows desktop and web. No native plugins beyond `path_provider`; the existing responsive shell (sidebar→drawer below 800 px, in place since Phase 4.6) handled the layout side. See [45-mobile-shell.md](45-mobile-shell.md).

- ✅ **iOS + Android scaffolds** at [frontend/ios/](../frontend/ios/) and [frontend/android/](../frontend/android/). Buildable via `flutter run -d ios` / `flutter run -d android`.
- ✅ **`path_provider: ^2.1.5`** added to [pubspec.yaml](../frontend/pubspec.yaml) — the only new dep, used solely to locate a writable app-support directory on iOS/Android. `TokenStorage._resolveDir()` in [secure_storage.dart](../frontend/lib/core/storage/secure_storage.dart) branches by platform; desktop paths unchanged.
- ✅ **AndroidManifest** declares `INTERNET` + `usesCleartextTraffic="true"` (LAN HTTP); **iOS Info.plist** sets `NSAllowsArbitraryLoads` for the same reason. Both should be tightened before App Store / Play submission.
- ✅ **No release signing yet** — Android `release` block falls back to debug keys; iOS uses default automatic provisioning. Documented in the open-follow-ups section of [45-mobile-shell.md](45-mobile-shell.md). Out of scope until a customer needs store distribution.
- ✅ **No new tests, no UI changes** — verified via `flutter pub get` (clean) + `flutter analyze` (clean) + operator smoke-test on Android emulator and iOS simulator (login → drawer nav → CRUD → company switch → logout, RTL flip on Arabic).

### Phase 4.15 — proposed

- True code-gen pruning — read `template.modules` and emit a trimmed Flutter source tree + trimmed backend routes. The Phase 4.12 metadata + module-per-file structure makes this tractable.
- Templates UI for `branding` + `modules` editing — today operators hand-edit captured JSON before passing to the build CLI.
- Deep i18n cleanup pass (block inspectors, theme builder panels, page builder add-panel) — the Phase 4.11 scope cut.
- iframe rendering on web build (placeholder text on desktop, real `<iframe>` on web).
- Postgres dev compose path + validate `pg_dump` against it.
- Custom relations across entities — multi-select / many-to-many.
- Mobile release signing + store pipelines — when distribution is on the table.

---

## How to update this doc

When you start working on Phase 4 (or beyond):

1. Add a new section `🚧 Phase 4 — <name>` at the top of "active phase".
2. Mark the **current phase** label there. Demote Phase 3's heading to ✅.
3. Mirror the change in `MEMORY.md` under "Phase status".
4. Keep the descriptions terse — link to subsystem docs for detail.
