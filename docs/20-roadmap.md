# 20 — Roadmap

What is *not yet built*. None of this is committed work — it's a queue. Pull items into a Phase 4 doc when prioritized, then mark them ✅ here as they ship.

## Phase 4.11 — DONE (5 of 6 candidates shipped)

Phase 4.11 wrapped 2026-05-01. Shipped: backup retention policy, non-Node webhook verify helpers, native S3/restic uploaders inside the receiver, per-key translation editor, full UI string migration (~330 strings × 3 locales). Auto-heal for missing custom-entity SQL tables and a sidebar overflow fix were added mid-phase. Test count: 119 → 139 backend + 28 receiver. See [docs/18-phases.md](18-phases.md) for the full breakdown.

The mobile shell candidate slipped to Phase 4.12; everything else is checked off below.

## Phase 4.11 candidates (originally proposed)

- [ ] **Mobile shell** — `flutter run -d ios|android`. Adaptive forms, mobile-friendly tables. Preserve the no-plugin rule. Risk: needs a device for verification. **Slipped to Phase 4.12.**
- [x] ~~**Full UI string migration** — dialog titles, table column headers, validation messages, snackbar text across the rest of the feature pages.~~ Shipped in Phase 4.11. ~330 strings across 32 files migrated; ARB grew from 49 → ~225 keys × 3 locales. Deep power-user editor surfaces (block_inspectors, theme_builder panels, page-builder add-panel) deliberately deferred — Super Admin-only, low ROI. See [32-i18n-strings.md](32-i18n-strings.md).
- [x] ~~**Native S3 / restic uploaders** in the receiver — drop the rclone hand-off requirement.~~ Shipped in Phase 4.11. S3 mode is hand-rolled SigV4 over native fetch (no AWS SDK dep, supports any S3-compatible provider). Restic mode spawns the binary directly. See [tools/backup-sync/README.md](../tools/backup-sync/README.md).
- [x] ~~**Per-key translation editor** — replace the JSON textarea in `/translations` with a key-by-key form (with side-by-side English reference).~~ Shipped in Phase 4.11. Navigates to `/translations/edit/:locale`. Search, untranslated-only filter, drop-orphans-on-save toggle. Raw JSON kept as overflow-menu option. See [42-translation-management.md](42-translation-management.md#per-key-editor-phase-411).
- [x] ~~**Backup retention policy on disk** — auto-prune `.db` / `.sql` / `.enc` files older than N days; honour an env-var schedule.~~ Shipped in Phase 4.11 — see [33-backups.md](33-backups.md#retention-policy). Implemented as DB-backed settings (`system.backup_retention_*`) rather than env vars so they hot-reload without restart.
- [ ] **iframe rendering on web build** — placeholder text on desktop, real `<iframe>` on web.
- [ ] **Postgres dev compose** — bring up the commented-out `postgres` service in compose with a sensible default `DATABASE_URL`, validate the `pg_dump` path against it.
- [x] ~~**Webhook signature verification helper** under `tools/` so external receivers in non-Node languages have a reference implementation.~~ Shipped in Phase 4.11 — see [tools/webhook-verify/README.md](../tools/webhook-verify/README.md). Python + Go + PHP + Bash, all stdlib-only, with a Node cross-language regression test.

## Customization platform improvements

- [ ] **Auto-`ALTER TABLE` on custom-entity column edits** — diff the column config on `PUT /api/custom-entities/:id` and run the necessary `ALTER TABLE ADD/DROP COLUMN`. Pitfall: SQLite's limited `ALTER TABLE` (no `DROP COLUMN` until 3.35; no easy `MODIFY COLUMN`). Plan a "rebuild" path: `CREATE TABLE _new`, copy, `DROP`, `RENAME`. (See [11-custom-entities.md](11-custom-entities.md).)
- [ ] **Templates including seed data** — currently `apply` copies structure only. Add an opt-in to also copy the entity's data rows. (See [14-templates.md](14-templates.md).)
- [ ] **Templates including reports + saved queries** — extend the `full` snapshot.
- [ ] **Custom relations across entities** — the `relation` column type exists in the schema but the dropdown is single-target. Add multi-select and many-to-many.

## Reports v2

- [ ] **Formula columns** — let a report builder return a column whose value is a function of other columns (computed in JS).
- [ ] **More chart types** — line, area, pie. The frontend uses `fl_chart`, which supports them.
- [ ] **Scheduled runs** — store a cron expression on a report row, run on schedule, persist results, optionally email/upload.
- [ ] **Pivot/group-by UI** — the runner currently shows raw rows; a UI grouping/pivoting layer would extend coverage without new builders.

## Workflows + approvals

- [ ] **Approval queues** tied to the `*.approve` permission. Today the permission exists but is not wired to any workflow.
- [ ] **State machines** for custom entities — define states and transitions, gate transitions on permissions, audit each transition.

## Theming

- [ ] **Per-company theming** — finish the company-switcher. Each company can have its own active theme; switching companies refreshes the theme.
- [ ] **Theme variables** — let users define their own named tokens (e.g. `--accent-success`) used by custom widgets.

## Mobile

- [ ] **Phone-friendly shell** — adaptive sidebar (drawer on mobile, sidebar on desktop). Most feature pages already use responsive widgets but the dashboard shell is desktop-first.
- [ ] **Mobile builds** — `flutter run -d ios|android`. Token storage will need a platform-specific path; keep the no-plugin rule.

## Cloud-first deploy

- [ ] **Docker compose** — one service for the API, one for Postgres, one for nginx. Out-of-the-box `docker compose up` for a cloud install.
- [ ] **HTTPS reverse proxy template** — nginx config that terminates TLS and proxies to `localhost:4040`.
- [ ] **Multi-tenant single-DB option** — a `tenantId` foreign key on the top-level entities so one DB hosts many isolated customers. (Current: many companies in one DB; isolation is by company filtering.)

## Operations

- [ ] **Upload garbage collection** — periodic job that compares files in `uploads/` against URLs referenced anywhere in `themes`/`settings`/`custom_entities` rows; deletes orphans. (See [15-uploads.md](15-uploads.md).)
- [ ] **Backup endpoint** — `POST /api/admin/backup` that copies `dev.db` to a configured destination and returns the path.
- [ ] **Health metrics** — beyond `/api/health`. Counts, last-N audit summary, DB size.
- [ ] **i18n** — currently English-only. Wrap user-facing strings in a translation helper; ship Arabic and French as the first non-English locales.
- [ ] **Date/time formatting per user locale** — partially in place via Flutter's `intl`; settle on a single rule.

## Developer experience

- [ ] **Tests** — there are none yet. Start with `backend/tests/permissions.test.js` and `backend/tests/sql_runner.test.js` (the two surfaces with the most invariants).
- [ ] **Type-checked frontend models** — the API responses are typed in Dart but the JSON shape is informal. Generate models from a single source (OpenAPI?) or hand-write a thin contract layer.
- [ ] **Migration linting** — fail CI if a migration drops a column without explicit confirmation.

## Documentation backlog

- [ ] **Per-page screenshots** in [03-getting-started.md](03-getting-started.md) and [09-theme-builder.md](09-theme-builder.md).
- [ ] **A "developer onboarding" doc** that walks through adding a new core module end to end with a small example.
- [ ] **An "admin operator" doc** for non-developer admins: how to back up, how to add a user, how to grant a one-off permission.

## Closed

### Phase 4.10
- ✅ **HTTPS download endpoint with pre-signed URLs** — `GET /api/admin/backups/:name/download` with dual auth (Super Admin Bearer or `?expires&sig`). Mounted before global auth so signed-URL clients don't fail JWT. Configurable via `BACKUP_DOWNLOAD_SECRET` + `BACKUP_PUBLIC_URL`. 1-hour default TTL.
- ✅ **Webhook `downloadUrl`** — emitted on `backup.created` when signing is enabled. Receivers can pull cross-host without a shared filesystem.
- ✅ **Receiver HTTPS pull mode** — `tools/backup-sync` falls back to streaming via `payload.downloadUrl` when `SRC_DIR` is missing (or always when `PULL_VIA_HTTP=1`).
- ✅ **Roles UI label resolution** — `_RoleCard` reads `role.labels[localeCode]` with English fallback. Role names flip with the active locale.
- ✅ **ARB import/export endpoints** — `GET/PUT /api/admin/translations[/:locale]`. Strips/restamps `@@locale`, writes timestamped `.bak-*` sidecars.
- ✅ **Translations UI** — `/translations` Super Admin page with list / edit / export / new-locale dialogs.
- ✅ **Tests grow to 119 / 13 files** — 7 signed-URL tests + 6 translation tests.

### Phase 4.9
- ✅ **Streaming encryption + v2 trailer-tag format** — `encryptStreamWithKey` pipes plaintext through the cipher straight to disk; auth tag at the file trailer. Memory stays flat regardless of source size. v1 read-back retained.
- ✅ **Built-in key rotation** — `POST /api/admin/backups/rotate-encryption` re-encrypts every `.enc` file with a new key and rewrites `.env` with a timestamped backup. All-or-nothing.
- ✅ **`Role.labels` JSON column** — seeded en/ar/fr for the 5 system roles; `/api/roles` DTO surfaces the parsed map.
- ✅ **Bulk page-header migration** — audit / dashboard / roles / reports / backups page titles read from `AppLocalizations`.
- ✅ **Off-site sync receiver tool** — standalone Node service in `tools/backup-sync/`. Listens for `backup.created`, verifies HMAC, copies to `DEST_DIR`. Pairs with rclone / restic / az-cli.
- ✅ **Tests grow to 106 / 11 files** — added round-trip encrypt/decrypt + tamper-detection + key-rotation tests.

### Phase 4.8
- ✅ **Per-page translatable titles** — `Page.titles` JSON column. `PageRenderer` resolves via `_resolveTitle(page, localeCode)` with English fallback.
- ✅ **Encrypted backups** — optional AES-256-GCM gated on `BACKUP_ENCRYPTION_KEY`. Self-contained `MCEB` on-disk format. Hex / base64 / passphrase (PBKDF2) key derivation. Restore decrypts to staging then atomically renames.
- ✅ **`backup.created` webhook event** — fires after every successful backup with `{ name, path, size, encrypted, provider }`. Off-site sync now plugs into the existing webhook delivery system.
- ✅ **More UI strings localized** — backups page header + buttons.
- ✅ **Isolated per-suite test DB** — vitest `globalSetup` (`tests/setup.js` + `vitest.config.js`) copies `prisma/dev.db` to a per-run temp file and sets `DATABASE_URL` before any test file imports Prisma. Self-verified the dev DB is unchanged after `npm test`.
- ✅ **Tests grow to 102 / 11 files** — added `backup_encryption.test.js`.

### Phase 4.7
- ✅ **Negative permission tests** — `tests/routes_permissions.test.js`. 8 tests covering a fixture non-super-admin against every Super-Admin endpoint.
- ✅ **Per-feature smoke tests** — `tests/routes_features.test.js`. 7 tests: pages CRUD + reorder, HTML sanitization, approval lifecycle, webhook test-fire + deliveries, schedule run-now, backup create/list/delete. All self-cleaning. Added `webhook.test` to `SUPPORTED_EVENTS`.
- ✅ **Native pg_dump / mysqldump** — `lib/backup.js` rewritten with provider detection. SQLite file-copy as before; pg spawns `pg_dump` with `PGPASSWORD`; mysql spawns `mysqldump`. Streams stdout to `.sql` file. Clear error if binary missing.
- ✅ **Sidebar label translation** — `MenuItem.labels` JSON column + `MENU_LABELS` map in seed (20 modules × en/ar/fr). `/api/menus` returns JSON; `MenuItemNode.labelFor(localeCode)` resolves with fallback.
- ✅ **More UI strings localized** — topbar `Sign out` / `Account` / `Switch company` / `No company` / `Language` / role labels.
- ✅ **Tests grow to 98 / 10 files** — was 83 / 8.

### Phase 4.6
- ✅ **gen_l10n + ARBs** — `flutter.generate: true`, `l10n.yaml`, `app_en/ar/fr.arb`, `AppLocalizations.delegate` wired. Login screen migrated to localized strings; the rest can adopt incrementally.
- ✅ **Backup + restore** — `lib/backup.js` + `routes/admin.js` + `/backups` UI. SQLite file copy with atomic rename on restore; `restartRequired: true` returned. Per-action audit + system log.
- ✅ **Builder analytics** — `GET /api/pages/analytics` returns counts + `byType` histogram + `emptyPages`. Surfaced as a panel above the page list.
- ✅ **Mobile shell polish** — topbar hides user name+role on narrow widths so the row doesn't overflow on phones.
- ✅ **Route-layer tests** — `supertest` dev dep, `buildApp()` extracted from `server.js`, 14 new HTTP integration tests. **83 total**.

### Phase 4.5
- ✅ **Conditional block visibility** — `PageRenderer` evaluates `config.visibleWhen` rule (`permission`, `permissions`+`match`, `isSuperAdmin`, `isLoggedIn`) against `AuthState`. UX feature, not a security gate.
- ✅ **Approval claim handlers** — `lib/approval_handlers.js`. `registerApprovalHandler(entity, fn)`, awaited inside the decide endpoints, errors captured per-handler. Webhooks for external receivers; handlers for in-process domain logic.
- ✅ **Auto-`ALTER TABLE` on custom-entity column edits** — `diffColumns()` + `applyColumnDiff()`. Adds and drops applied automatically (SQLite ≥ 3.35); type changes flagged as `skipped` with the rebuild instructions.
- ✅ **Per-company theming UI** — `_CompanySwitcher` in the topbar; `themeControllerProvider.loadActive(companyId: …)` reloads.
- ✅ **Docker compose** — `backend/Dockerfile`, `.dockerignore`, `docker-compose.yml`, `deploy/nginx.conf`. Two services + named volumes + commented-out Postgres.
- ✅ **i18n foundation** — `flutter_localizations`, persisted locale via extended `TokenStorage`, `_LocaleSwitcher` in topbar, MaterialApp wired with delegates + supportedLocales (en/ar/fr). UI strings still English; RTL flips automatically.
- ✅ **Tests grow to 69** — `custom_entity_engine.test.js` for `diffColumns`, `approval_handlers.test.js` for handler registry.

### Phase 4.4
- ✅ **Webhooks** — `WebhookSubscription` + `WebhookDelivery` models, HMAC-SHA256 signed POSTs, 3-attempt retry with backoff (immediate / 5 s / 30 s), 10 s timeout per attempt. Approval transitions and a synthetic `webhook.test` event wired. `/webhooks` page with CRUD + Send-test + delivery history. Secrets revealed once on create, redacted thereafter.
- ✅ **Multi-instance cron locking** — atomic `lockedBy`/`lockedAt` claim on `ReportSchedule`, 5-minute stale-lock reclaim. Two API instances pointed at the same DB no longer double-run.
- ✅ **Retention sweep** — hourly `purgeOldRunResults()` in the cron loop nulls out `ScheduledReportRun.result` blobs older than the schedule's `retentionDays` (or `system.report_retention_days`, default 30). Row preserved with `resultPurged: true`.
- ✅ **HTML sanitization** — `sanitize-html` package + `lib/html_sanitize.js`. PageBlock create AND update sanitize when `type === 'html'`.
- ✅ **Typed block inspectors** — typed dialogs for 11 block types (text, heading, image, button, card, spacer, iframe, html, report, custom_entity_list, divider). Falls back to JSON editor for unknown types.
- ✅ **Test suite** — vitest configured. 58 tests across `cron`, `sql_runner`, `permissions`, `html_sanitize`, `db_pool`. `npm test`.

### Phase 4.3
- ✅ **Workflows / approvals** — `ApprovalRequest` model + `/approvals` page + decide endpoints gated by `<entity>.approve`. Cancel limited to requester or Super Admin. Status lifecycle pending → approved/rejected/cancelled (terminal). Every transition audited.
- ✅ **Scheduled report runs** — `ReportSchedule` + `ScheduledReportRun` models. In-process minute-tick loop (`startCronLoop()` called at server boot). Supports `every_minute`, `every_5_minutes`, `hourly`, `daily`, `weekly`, `monthly`, plus 5-field standard cron expressions (own parser — no `node-cron` dep). `/report-schedules` page with create / toggle / Run-now / recent-runs / delete.
- ✅ **Native cross-provider DB drivers** — installed `pg` and `mysql2`; extended `lib/db_pool.js` to return a uniform handle (`runRead` / `runWrite` / `close` / `kind`). SQL runner reroutes secondary queries through the handle, so a SQLite primary can run SQL against a Postgres or MySQL secondary without restart. Same-provider path still uses cached PrismaClients for efficiency.

### Phase 4.2
- ✅ **Templates v2** — `SUPPORTED_KINDS` extended to `theme` / `business` / `pages` / `reports` / `queries` / `full`. Capture and apply both walk the new kinds. Pages preserve block parent/child links via a `localId`/`parentLocalId` two-pass insert.
- ✅ **`GET /api/templates/kinds`** — canonical list endpoint.
- ✅ **Secondary DB pool** in `lib/db_pool.js` — caches one `PrismaClient` per `DatabaseConnection`, with `datasources.db.url` overridden. Includes a `SELECT 1` probe so bad URLs fail fast.
- ✅ **SQL runner accepts `connectionId`** — `POST /api/db/query { sql, allowWrite, connectionId }`. Auth-table protection scoped to primary only (secondaries don't own this app's auth schema).
- ✅ **Cross-provider guardrail** — Prisma binds the SQL connector at compile time; the pool rejects secondaries whose provider differs from the primary with a clear error instead of a runtime crash.

### Phase 4.1
- ✅ **PageRenderer** — fetches by code or route, renders 15 block types (text, heading, image, button, card, container, divider, spacer, list, table, chart, iframe placeholder, html, custom_entity_list, report). Custom-painted bar/pie charts (no `fl_chart` dep).
- ✅ **Backend `/api/pages/by-route`** extended to accept `?code=` as well as `?route=`.
- ✅ **`/p/:slug` route** mounted in `app_router.dart` — sidebar entries from `/api/pages/sidebar` link here.
- ✅ **Drag-and-drop reorder** in the page builder using `ReorderableListView` + `ReorderableDragStartListener`.
- ✅ **Container nesting UI** — every block has a "Move to container" popup that targets any `container`/`card` block; children render indented under their parent.
- ✅ **Theme Builder transparency UI** — sliders + color pickers for surface/sidebar/topbar/card/background opacity, blur, overlay color+opacity, login overlay color+opacity, glass blur/tint/opacity.
- ✅ **Login screen rebuild** — `split`/`centered`/`minimal` styles, applies background image + overlay, glass card when `enableGlass` is on.
- ✅ **Dashboard shell rebuild** — stacked background (image → blur → overlay), glass-capable sidebar, opacity on topbar.
- ✅ **`theme_data_builder.dart`** applies `surfaceOpacity`/`cardOpacity` to Material widgets so the controls actually do something.
- ✅ **Quick-preset chips per module** in the role editor (None / View / View+edit / View+edit+delete / Full).
- ✅ **Sidebar merge** — `MenuController` pulls `/api/pages/sidebar` and adds custom pages to the sidebar at `/p/:code`.

### Phase 4.0
- ✅ **Page builder backend** — `Page`, `PageBlock` models; `/api/pages` CRUD + block CRUD + reorder; sidebar feed
- ✅ **System info console** — `/api/system/info` with process stats and counts
- ✅ **DB connection registry** — `DatabaseConnection` model + CRUD + Promote endpoint that rewrites `.env` (with timestamped backups under `.env-backups/`)
- ✅ **Init SQL runner** — `POST /api/system/database/sql/init` runs multi-statement SQL with per-statement results
- ✅ **System logs** — `SystemLog` model + viewer + clear-by-age
- ✅ **Login event tracking** — `LoginEvent` model + automatic recording on every login/refresh/logout, including failed attempts with `unknown_user` / `inactive_user` / `bad_password` reasons
- ✅ **Quick permission presets** — `POST /api/roles/:id/presets` accepts `{ module, level }` pairs (`view`, `view_edit`, `view_edit_delete`, `full`, `none`) with audit
- ✅ **Theme transparency fields** — opacity for surface/sidebar/topbar/card/background, blur, overlay color+opacity, login overlay, glass effect (data-only; no schema migration)
- ✅ **Frontend skeletons** — `/system`, `/system-logs`, `/login-events`, `/pages`, `/pages/edit/:id` wired into the router
