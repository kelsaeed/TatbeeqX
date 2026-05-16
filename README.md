# TatbeeqX

[![CI](https://github.com/kelsaeed/TatbeeqX/actions/workflows/ci.yml/badge.svg)](https://github.com/kelsaeed/TatbeeqX/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

**A management platform you bend to fit the business — not the other way around.**

Most business software makes you adapt your workflow to its tables and screens. TatbeeqX flips that. You define your own tables, forms, roles, reports, and automations from inside the running app, with no code and no redeploy. Start it on an office network with nothing but Node and a SQLite file. When you outgrow that, point it at Postgres and keep going — the only thing that changes is a connection string. And when a setup is worth repeating, freeze it into a branded, standalone Windows app you can hand to a customer.

It fits restaurants, retail and POS, clinics, factories, finance offices, and rental companies out of the box — anywhere the alternative is a pile of spreadsheets and a half-finished CRUD app.

> **Where to start**
> - **Installing it** → [SETUP.md](SETUP.md) — every install path in one place
> - **Just want to see it run?** → [docs/03-getting-started.md](docs/03-getting-started.md) — a 5-minute desktop walkthrough
> - **Using the app** → [docs/49-user-manual.md](docs/49-user-manual.md) — sign-in, password reset, 2FA, every module
> - **Where the project stands** → [docs/18-phases.md](docs/18-phases.md) — the single source of truth for status

## What makes it different

A few things genuinely set TatbeeqX apart from a typical CRUD admin:

- **Almost everything is data, not code.** Roles, permissions, sidebar menus, themes, even entire tables and the pages that render them live in the database and are edited from the UI. Adding a module to a customer's install is a few clicks, not a release.
- **LAN today, cloud tomorrow — same code.** Runs on SQLite over a local network with zero infrastructure. Moving online means provisioning Postgres or MySQL and changing `DATABASE_URL`. No application code changes.
- **It ships products, not just runs one.** Capture a configured setup as a template, then build a branded, locked-down customer binary from it — its own database, its own backend, your name on the window.
- **No Developer Mode required on Windows.** The desktop app deliberately avoids native Flutter plugins, so it builds without symlink support. Auth tokens are written to `%APPDATA%` with plain `dart:io`.
- **Secure by default.** Rotating refresh tokens with reuse/theft detection, TOTP 2FA plus recovery codes, bcrypt passwords, per-IP login throttling, timing-safe comparison, and a full audit trail — on by default, not a checklist item.

## Stack

| Layer | Choices |
|---|---|
| Backend | Node.js 20+, Express, Prisma, SQLite (swap to Postgres/MySQL by connection string) |
| Frontend | Flutter — Windows desktop is primary; web, iOS, and Android also ship. Riverpod, go_router, dio |
| Auth | JWT access tokens + revocable, rotating refresh tokens with reuse detection; bcrypt; TOTP 2FA + recovery codes; per-IP rate limiting |
| Permissions | Role-based, fully database-driven, with per-user grant/revoke overrides on top |
| Automation | Workflow engine (4 trigger types, 8 action types), in-app notifications, HMAC-signed webhooks, SMTP email |
| Tests | A vitest backend suite (30+ test files) and `flutter analyze`, run in CI on every push |

## Quick start

### 1. Backend

```bash
cd backend
cp .env.example .env
npm install
npm run db:reset      # creates the SQLite file, runs migrations, seeds defaults
npm run dev           # API on http://localhost:4040
```

`db:reset` seeds a Super Admin. Change the password the moment you log in:

```
username: superadmin
password: ChangeMe!2026
```

### 2. Desktop app (Windows)

```bash
cd frontend
flutter pub get
flutter run -d windows
```

No Developer Mode needed — see the note above on why. For a web build, `flutter run -d chrome`.

The app reads its API base URL from `lib/core/config/app_config.dart` (default `http://localhost:4040/api`). To point a client at a LAN server:

```bash
flutter run -d windows --dart-define=API_BASE_URL=http://<server-lan-ip>:4040/api
```

## First run: pick a business type

The first time you sign in as Super Admin you land on `/setup`. Pick a starting point and TatbeeqX builds the tables, permissions, and sidebar entries for it in one step:

| Preset | Starter tables |
|---|---|
| Retail / POS | products, customers, suppliers, sales, payments |
| Restaurant | menu items, tables, orders, reservations, customers |
| Clinic | patients, appointments, treatments |
| Factory | products, raw materials, work orders, inventory movements, suppliers |
| Finance office | customers, invoices, accounts, transactions |
| Rental company | assets, customers, rentals, payments |
| Blank slate | nothing — you design every table yourself |

Each preset creates the SQL tables, the `view/create/edit/delete/export/print` permissions, the sidebar links, and grants everything to Super Admin and Company Admin. To apply one before the first boot instead, set `SEED_BUSINESS_TYPE=clinic` in `backend/.env` and run `npm run db:reset`.

## What you can shape from inside the app

These are the Super Admin surfaces that make TatbeeqX a platform rather than a fixed product:

- **Custom Entities** (`/custom-entities`) — design new tables in a form: fields, types, required/unique/searchable flags. Each entity gets an auto-generated list and form at `/c/<code>`.
- **Database admin** (`/database`) — browse tables, columns, indexes, and foreign keys; preview rows; run SQL. Read-only until you flip Write mode; the auth tables stay protected. Useful queries can be saved.
- **Theme Builder** (`/themes`) — colors, fonts, radius, shadows, gradients, login layout, logo/favicon/background uploads. The active theme is fetched at startup and applied live; no rebuild.
- **Page Builder** (`/pages`) — compose custom pages from 15 block types with drag-and-drop reordering and container nesting; render them at `/p/<code>`.
- **Reports** (`/reports`) — each report points at a safe server-side builder function, never raw user SQL. Run as a table or a bar chart, schedule recurring runs, add your own.
- **Workflows & approvals** (`/workflows`, `/approvals`) — automation on record changes, events, schedules, or inbound webhooks; actions from setting fields to sending email. Approval queues are gated per module.
- **Webhooks** (`/webhooks`) — HMAC-SHA256-signed outbound POSTs with retry and delivery history.
- **Templates** (`/templates`) — capture the current theme, tables, reports, and branding as one snapshot. Re-apply it, share the JSON between installs, or feed it to the subsystem builder.
- **Translations & backups** — edit ARB files per key from the UI (English, Arabic with RTL, French); create, restore, and rotate encrypted database backups with on-disk retention and optional off-site sync.

## Roles and permissions

Permissions are rows in the database with codes like `users.view`, `roles.edit`, `orders.approve`. A user's effective set is:

```
(union of permissions from every assigned role)
  + per-user grants
  − per-user revokes
```

Super Admins carry an `isSuperAdmin` flag and bypass the checks entirely. The actions available per module are `view`, `create`, `edit`, `delete`, `approve`, `export`, `print`, `manage_settings`, `manage_users`, and `manage_roles`. The role editor has quick presets (`view`, `view_edit`, `view_edit_delete`, `full`, `none`) so you can set a whole module in one click.

Seeded roles:

| Role | What it can do |
|---|---|
| Super Admin | Full control; owns the Theme Builder; the only role that edits the roles/permissions tables directly |
| Chairman | Full read visibility, high-level approvals, export and print |
| Company Admin | Manages users, roles, branches, and settings within their company |
| Manager | Limited management inside assigned modules |
| Employee | Only what's explicitly granted (dashboard view by default) |

## Turn a setup into a shippable app

This is the part people miss, so it's worth stating plainly: a configured TatbeeqX is a *studio*. When a setup is ready to ship, you **export a frozen, branded copy** — a subsystem build.

```bash
node tools/build-subsystem/build.mjs \
  --template ./restaurant.json \
  --out ./dist \
  --name "Restaurant" \
  --admin-password "<a strong one>"
```

You get `./dist/restaurant/` containing the branded `restaurant.exe`, its **own** bundled backend, its **own** database seeded from the template on first boot, a `start.bat`, and operator docs. With `SUBSYSTEM_LOCKDOWN=1` baked in, the customer never sees the admin surfaces; backend permission checks stay authoritative regardless.

It is a **snapshot, not a live link**. The built app runs independently — editing the studio afterward does not reach back into a shipped bundle. To push changes you either rebuild and re-ship, or connect to that install's backend and edit it there. Full details and the customer-admin handover flow are in [docs/44-subsystem-builds.md](docs/44-subsystem-builds.md).

## Deployment

### On a LAN (today)

1. Run the backend on the host (`npm start`, or `pm2`/`nssm` on Windows).
2. Allow port 4040 through the Windows firewall.
3. Find the host's LAN IP (`ipconfig`).
4. Build each client against that IP:
   ```bash
   flutter build windows --dart-define=API_BASE_URL=http://192.168.x.x:4040/api
   ```
5. Copy `build/windows/x64/runner/Release/` to the client and run the executable.

### Going online later

1. Provision Postgres or MySQL.
2. Update `DATABASE_URL` in `backend/.env`.
3. Change `provider` in `backend/prisma/schema.prisma` to `postgresql` or `mysql`.
4. Run `npx prisma migrate deploy` and `npm run db:seed`.

No application code changes — that's the whole point of the LAN-to-cloud path.

## Project layout

```
backend/      Express API, Prisma schema, seeders, vitest suite
frontend/     Flutter app
  lib/
    core/         config, network, theme, storage, providers
    routing/      go_router with an auth guard
    features/     one folder per module (auth, users, roles, companies,
                  reports, workflows, pages, custom entities, …), each
                  split into data / application / domain / presentation
    shared/       reusable widgets (tables, headers, icons)
tools/
  build-subsystem/   branded, locked-down customer binaries
  backup-sync/       off-site backup receiver (S3 / restic)
  webhook-verify/    signature-verification helpers in several languages
docs/         The documentation hub — start at docs/README.md
.github/      CI workflow and issue/PR templates
```

Architecture is clean but deliberately unfussy: presentation widgets, application notifiers, domain entities, and data-layer repositories, wired with Riverpod. Repository, singleton, dependency-injection, strategy, and factory patterns show up where they earn their keep.

## Adding a new module by hand

If you'd rather code a module than use Custom Entities:

1. Add a Prisma model and migration.
2. Add `backend/src/routes/<module>.js` and register it in `routes/index.js`.
3. Insert its permissions and a menu row (the seeder's `MODULES` array is the easy spot).
4. Add `frontend/lib/features/<module>/` (data, application, domain, presentation).
5. Add the route to `frontend/lib/routing/app_router.dart`.

The sidebar builds itself from `/api/menus`, so once the menu row exists and the user holds `<module>.view`, the link appears on its own.

## Testing

```bash
cd backend && npm test          # vitest
```

CI runs the backend suite and `flutter analyze` on every push. The API has broad coverage; see [docs/35-route-tests.md](docs/35-route-tests.md) and [docs/38-test-isolation.md](docs/38-test-isolation.md) for how the suite stays isolated and fast.

## Documentation

Everything lives in [docs/](docs/) and the index is [docs/README.md](docs/README.md). The ones worth bookmarking:

- [docs/03-getting-started.md](docs/03-getting-started.md) — the fastest path to a running app
- [docs/49-user-manual.md](docs/49-user-manual.md) — the day-to-day user guide
- [docs/18-phases.md](docs/18-phases.md) — exactly what's built and what's next
- [docs/07-api-reference.md](docs/07-api-reference.md) — every endpoint
- [docs/10-business-presets.md](docs/10-business-presets.md) and [docs/44-subsystem-builds.md](docs/44-subsystem-builds.md) — presets and shipping branded builds

## License

MIT — see [LICENSE](LICENSE).
