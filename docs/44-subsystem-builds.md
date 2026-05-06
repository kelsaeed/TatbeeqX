# 44 — Subsystem builds (Phase 4.12)

TatbeeqX can be packaged as a **branded, locked-down customer binary** generated from a template. A vendor designs a setup using the full studio (custom entities, theme, reports, queries, pages), captures it as a template, and the build-subsystem CLI emits a folder the customer can ship.

- Template enrichment: [`backend/src/lib/templates.js`](../backend/src/lib/templates.js) (v3 templates carry `modules` + `branding`)
- Lockdown lib: [`backend/src/lib/subsystem.js`](../backend/src/lib/subsystem.js)
- Public info endpoint: `GET /api/subsystem/info`
- First-boot seeder: [`backend/src/lib/boot_seeder.js`](../backend/src/lib/boot_seeder.js)
- Frontend reader: [`frontend/lib/core/subsystem/subsystem_info.dart`](../frontend/lib/core/subsystem/subsystem_info.dart)
- Build CLI: [`tools/build-subsystem/build.mjs`](../tools/build-subsystem/build.mjs)

## What "lockdown" means

When the bundled `.env` has `SUBSYSTEM_LOCKDOWN=1`:

- The frontend's router redirects away from `/system`, `/system-logs`, `/database`, `/custom-entities`, `/templates`, `/themes`, `/pages`, `/translations` (the super-admin admin surfaces) — even when typed directly into the URL bar.
- The sidebar filters the same set of routes out, so vendor-side support sessions stay clean of admin clutter that customers shouldn't be poking at.
- `branding.appName`, `branding.logoUrl`, and `branding.primaryColor` from the template override the active theme's defaults.

**Backend permission checks remain authoritative.** The lockdown is organizational / UX, not adversarial:
- Backend routes still gate on `requireSuperAdmin()` / `requirePermission()`.
- A customer-side user can't promote themselves to Super Admin (the user routes don't accept `isSuperAdmin` from the client body — already enforced before Phase 4.12).
- The vendor's own Super Admin keeps full access for support.

## Template fields

A template captured with `kind: 'full'` (or `business`) now optionally carries:

```json
{
  "kind": "full",
  "version": 3,
  "createdAt": "2026-05-01T...",
  "modules": ["custom:products", "custom:work_orders"],
  "branding": {
    "appName": "Factory ABC",
    "logoUrl": "https://cdn.example/logo.png",
    "primaryColor": "#1f6feb",
    "iconPath": "./factory-abc.ico"
  },
  "theme": { ... },
  "entities": [ ... ],
  "pages": [ ... ],
  "reports": [ ... ],
  "queries": [ ... ]
}
```

- `modules` is the **contract for code-gen**: today it informs the runtime sidebar filter; in a future phase the same array drives the trimmed-binary code-gen tool (it walks `frontend/lib/features/` and keeps only the listed dirs). Treat the array as the public surface — don't split or rename keys.
- `branding.iconPath` is resolved relative to the template file's directory.

## Generating a customer build

Prereqs: a checkout of TatbeeqX, Node 20+, Flutter SDK on PATH.

```bash
# 1. Capture a template via TatbeeqX's UI (/templates page) or the
#    /api/templates/capture endpoint, save it to factory_v1.json.
# 2. Optionally edit factory_v1.json to set `branding` and `modules`
#    (the UI doesn't expose these yet — Phase 4.12 v2 will).

# 3. Run the build CLI:
node tools/build-subsystem/build.mjs \
  --template ./factory_v1.json \
  --out ./dist \
  --name "Factory ABC"

# Output: ./dist/factory-abc/
#   backend/        — Node + Prisma backend, .env with SUBSYSTEM_LOCKDOWN=1
#   app/            — Flutter Windows Release build, renamed to factory-abc.exe
#   start.bat       — installs deps on first run, then launches API + UI
#   README.md       — operator instructions
#   seed.json       — the template, applied on first boot
```

Flags:
- `--no-build` — skip `flutter build windows --release`. Use when iterating on the staging step or when Flutter isn't installed locally.
- `--source <dir>` — point at a different TatbeeqX checkout (default: the script's grandparent dir).
- `--prune` — **(Phase 4.16)** strip optional modules NOT listed in `template.modules` from the staged source before the Flutter build. Removes route imports, app router entries, and orphaned feature dirs/route files. Core/infra modules (auth, dashboard, users, roles, companies, branches, audit, settings, reports, backups) are always kept regardless. The pruner is marker-driven (`// MOD: <code>` and `// MOD-BEGIN/END`); see [`tools/build-subsystem/prune.mjs`](../tools/build-subsystem/prune.mjs) for the catalog of supported optional modules. Smoke-tested against `flutter analyze` — pruned source still compiles clean.

## How the bundle runs on the customer host

`start.bat` does:
1. `npm install --omit=dev` in `backend/` (first run only).
2. `npx prisma migrate deploy` + `node prisma/seed.js` (first run only — creates the SQLite DB and seeds default users/roles/menus).
3. `node src/server.js` in the background (API on `127.0.0.1:4040`).
4. Launches `app/<name>.exe` (the Flutter desktop binary).

On first boot of the API, the seeder script in `boot_seeder.js`:
- Reads `BOOT_SEED_PATH=./seed.json` from `.env`.
- Verifies no `system.subsystem_info` or `system.boot_seed_applied` setting exists yet (idempotency marker).
- Calls `applyTemplateData()` on the parsed template — same code path as `POST /api/templates/:id/apply`.
- Plants the marker so subsequent restarts don't re-apply.

## Customer admin user — automated (Phase 4.13)

The build CLI bakes a `lockdownAdmin` block into `seed.json` containing only the bcrypt hash of the password — **plaintext never lands on disk**:

```bash
node tools/build-subsystem/build.mjs \
  --template ./factory_v1.json \
  --out ./dist \
  --admin-password "<choose a strong one>" \
  [--admin-username factoryadmin] \
  [--admin-fullname "Factory Admin"] \
  [--admin-email admin@factory.example]
```

On the customer's first boot, the seeder (running because `SUBSYSTEM_LOCKDOWN=1` is set):

1. Sets `users.isActive = false` for the seeded `superadmin` account.
2. Upserts the Company Admin user with the bcrypt hash you provided (no re-hashing — the CLI's hash is portable).
3. Grants the `company_admin` role to that user.
4. Plants the `system.boot_seed_applied` marker so subsequent restarts are no-ops.

The customer logs in with the credentials you handed them. The vendor can re-enable `superadmin` for support over SSH (`UPDATE users SET isActive = 1 WHERE username = 'superadmin'`) and disable again afterward.

If you'd rather provision the admin manually (e.g., via a vendor portal), pass `--no-admin` to the build CLI. The bundle then leaves `superadmin` active, and you handle handover yourself.

**Why hash in the CLI, not the backend?** Two reasons:
- The seed.json sits in the bundle, the bundle ships across email/USB/whatever — plaintext in there is a real risk.
- Idempotency: the boot seeder must be safe to re-trigger (e.g., after a manual `DELETE FROM settings WHERE key='system.boot_seed_applied'`). A pre-computed hash makes the seed file deterministic.

## Architecture hooks for future code-gen

The Phase 4.12 v1 path is **same binary, different config + branding**. The hooks for true code-gen (trimmed binaries) are in place:

- `template.modules` is the contract — a future tool reads it and walks `frontend/lib/features/` keeping only the listed dirs, regenerates `app_router.dart` with only those routes, strips backend route registrations from `routes/index.js`.
- Backend routes are file-per-module under `backend/src/routes/` — the imports/registrations in `routes/index.js` are easy to filter at code-gen time.
- Frontend feature dirs are isolated under `lib/features/<dir>/` — same property.

Until that lands, expect:
- Bundle size: ~80–120 MB (Flutter engine dominates; trimming features won't shrink this much).
- Runtime: a bit lighter than the full studio because the lockdown hides initialization for super-admin pages, but the heavy lifting (auth, RBAC, Prisma) is unchanged.

## Port management (Phase 4.20)

By default a subsystem build bakes `PORT=4040` into `backend/.env` and ships unchanged. Two flags on the build CLI extend this for cases where 4040 might be busy on the customer host or where the vendor wants to run multiple subsystems side-by-side on one machine for a demo.

```bash
# Single explicit port — bakes PORT=4044 into the bundle. start.bat
# only ever tries this port. No fallback.
node tools/build-subsystem/build.mjs --port 4044 ...

# Pool — bakes a range. Build-time scan picks the first free port on
# the build host as the primary; runtime scan in start.bat picks
# again on the customer host and falls through to the next free
# port if the primary is busy.
node tools/build-subsystem/build.mjs --port-pool 4040-4050 ...
```

**What gets baked:**
- `backend/.env` → `PORT=<primary>`.
- `flutter build windows --release --dart-define=API_BASE_URL=http://localhost:<primary>/api` — compile-time default for the .exe.
- `start.bat` → a `setlocal enabledelayedexpansion` block with the runtime pool (primary first, fallbacks after). `netstat -ano | findstr ":<port> "` picks the first free port; `set PORT=...` and `set TATBEEQX_API_BASE_URL=...` are exported before the backend + .exe launch.

**Flutter runtime override.** [`AppConfig.apiBaseUrl`](../frontend/lib/core/config/app_config.dart) reads `Platform.environment['TATBEEQX_API_BASE_URL']` first, falling back to the compile-time `--dart-define`. This is what lets `start.bat` redirect the same .exe at a different port without rebuilding.

**`dotenv` precedence note:** the backend's [env.js](../backend/src/config/env.js) reads `process.env.PORT ?? 4040`, and dotenv (default behavior) doesn't override values already present in `process.env`. So when `start.bat` `set PORT=...` before launching `node src/server.js`, the shell value wins over `.env`. That's by design.

## Subsystems Manager (Phase 4.20)

Studio-only surface for launching locally-built subsystem bundles side-by-side. **Hidden in lockdown builds** — a subsystem managing other subsystems would fork-bomb itself; the surface only makes sense in the dev/studio install. Added to `HIDDEN_IN_LOCKDOWN` in [`lib/subsystem.js`](../backend/src/lib/subsystem.js).

- Registry: `<APPDATA>/TatbeeqX/subsystems.json` (one row per registered bundle: id / name / bundleDir / port / backendPid / exePid / lastStartedAt / lastStoppedAt).
- Logs: `<APPDATA>/TatbeeqX/logs/<id>.log` (per-bundle, append-mode, single-level rotation at 5 MB → `<id>.log.1`).
- Backend lib: [`backend/src/lib/subsystems_manager.js`](../backend/src/lib/subsystems_manager.js).
- Backend route: [`backend/src/routes/subsystems.js`](../backend/src/routes/subsystems.js) — mounted at `/api/admin/subsystems`, gated by `requireSuperAdmin()`.
- Frontend page: [`frontend/lib/features/subsystems/presentation/subsystems_page.dart`](../frontend/lib/features/subsystems/presentation/subsystems_page.dart) — at `/subsystems`. Sidebar menu seeded with sortOrder 94.

### REST surface

| Method + path                              | Effect                                                                                              |
| ------------------------------------------ | --------------------------------------------------------------------------------------------------- |
| `GET    /api/admin/subsystems`             | List rows. Each row carries a live `status` (running / partial / stopped / missing) computed from `kill(pid, 0)` + `fs.existsSync(bundleDir)`. |
| `POST   /api/admin/subsystems/inspect`     | Pre-flight a folder. Returns `{ bundleDir, port, suggestedName, hasExe }` if valid; 400 otherwise. Used by the Add-bundle dialog. |
| `POST   /api/admin/subsystems`             | Register a bundle (`{ bundleDir, name? }`).                                                         |
| `DELETE /api/admin/subsystems/:id`         | Unregister. Refuses if running.                                                                     |
| `POST   /api/admin/subsystems/:id/start`   | Spawn backend + .exe. Runs first-boot setup if needed.                                              |
| `POST   /api/admin/subsystems/:id/stop`    | `taskkill /F /T` on tracked PIDs.                                                                   |
| `POST   /api/admin/subsystems/:id/restart` | Stop + 300 ms + start, sequenced.                                                                   |
| `POST   /api/admin/subsystems/:id/port`    | Reassign port (rewrites `.env` PORT line). Refuses if running. Collision check against other rows. |
| `GET    /api/admin/subsystems/:id/logs`    | Tail `<id>.log`. Returns `{ lines, bytes, path }`. `?lines=N` defaults to 200, capped at 2000.      |

### Process model

The studio spawns the bundle's `node src/server.js` and `<name>.exe` **directly** (not via `start.bat`). Direct spawn gives clean PIDs to track. The trade-off: the studio also has to replicate `start.bat`'s first-boot path (`npm install --omit=dev` + `prisma migrate deploy` + `prisma/seed.js`) on first start — `ensureBackendBootstrapped()` in [`subsystems_manager.js`](../backend/src/lib/subsystems_manager.js) handles that.

- **Detachment.** Children spawn with `detached: true` + `unref()` so they outlive a studio crash. The next studio session sees them via `kill(pid, 0)` and reports `running` correctly.
- **Stop.** `taskkill /PID <pid> /F /T` (force + tree). Node's `process.kill()` doesn't reliably terminate Windows GUI processes, and SIGTERM has no Windows equivalent.
- **Status.** `kill(pid, 0)` throws on Windows when the process doesn't exist (libuv translates to OpenProcess permission probe). Catch = dead PID. Plus `fs.existsSync(bundleDir)` for the `'missing'` state.
- **Logs.** `stdio: ['ignore', logFd, logFd]` redirects stdout + stderr to the per-bundle log file. The parent closes its fd copy after spawn; the child inherits a duplicate. `.exe` stdout is intentionally NOT captured — it's a GUI app with no diagnostic value there.

### What you can't do (yet)

Deliberately not implemented:
- **Folder picker** in the Add-bundle dialog. Currently you paste the path. Skipped to avoid pulling in `file_selector` as a new dep.
- **i18n** of the page strings. Hardcoded English; rest of the studio routes through ARB. Folded into the next i18n chore pass.
- **Multi-level log rotation.** Single rotation only — once `<id>.log.1` exists, the next rotation clobbers it.
- **stdout/stderr from the .exe.** GUI app, no useful output.
- **Live status push.** Page polls every 5s instead of WebSocket / SSE.

## Tests

- [`backend/tests/subsystem.test.js`](../backend/tests/subsystem.test.js) — `isLockdown`, `getSubsystemInfo`, `setSubsystemInfo`, `GET /api/subsystem/info`.
- [`backend/tests/boot_seeder.test.js`](../backend/tests/boot_seeder.test.js) — first-boot seeder idempotency, error handling.

The build CLI itself doesn't ship a vitest suite (it shells out to `flutter` and `npm`); smoke-test it with `--no-build` against a sample template — see the script's source for a 30-second self-check.

The Subsystems Manager is integration-tested manually against real bundles. Adding vitest coverage for the registry I/O + log tail + status logic is feasible but punted — the lib is small (~330 lines) and most of its surface is OS-level (`spawn` / `taskkill` / file descriptors) which mocks awkwardly.
