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
3. `node src/server.js` in the background (API on `127.0.0.1:4000`).
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

## Tests

- [`backend/tests/subsystem.test.js`](../backend/tests/subsystem.test.js) — `isLockdown`, `getSubsystemInfo`, `setSubsystemInfo`, `GET /api/subsystem/info`.
- [`backend/tests/boot_seeder.test.js`](../backend/tests/boot_seeder.test.js) — first-boot seeder idempotency, error handling.

The build CLI itself doesn't ship a vitest suite (it shells out to `flutter` and `npm`); smoke-test it with `--no-build` against a sample template — see the script's source for a 30-second self-check.
