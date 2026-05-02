# 03 — Getting started

This walks a developer through a clean install on a Windows machine with no prior setup. End users should read [49-user-manual.md](49-user-manual.md) instead — this page is for people who will run the backend + frontend from source.

For the full prerequisite matrix (mobile / iOS / SMTP / Postgres dev loop / etc.), see [SETUP.md](../SETUP.md). This page is the minimum viable path.

## Prerequisites

- Node.js 20+ on the PATH (`node -v`)
- Flutter 3.27+ on the PATH (`flutter --version`) with Windows desktop enabled (`flutter config --enable-windows-desktop`). Verified on 3.41.6.
- Visual Studio 2022 Build Tools with the **C++ desktop development** workload (required for the Windows desktop build)
- VS Code (recommended)

## 1. Clone / open the project

```bash
git clone https://github.com/kelsaeed/TatbeeqX
cd TatbeeqX
```

Open the folder in VS Code. Open two terminals (Terminal → New Terminal, then split with `+`).

## 2. Backend — first run

```bash
cd backend
cp .env.example .env       # then edit .env to taste
npm install
npm run db:reset           # creates SQLite, runs migrations, seeds defaults
npm run dev                # API on http://localhost:4000
```

`npm run db:reset` is idempotent — re-run it whenever you want a clean database with default seed data.

To pre-apply a business type on seed:

```ini
# backend/.env
SEED_BUSINESS_TYPE=retail   # or restaurant | clinic | factory | finance | rental | blank
```

then `npm run db:reset`.

## 3. Frontend — first run

```bash
cd frontend
flutter pub get
flutter run -d windows
```

The desktop window should open. The login screen accepts:

```
username: superadmin
password: ChangeMe!2026
```

Change the password from **Settings → Account** after first login (or seed your own via `SEED_SUPERADMIN_*` env vars).

## 4. First-run wizard

A fresh database has no business type applied. After login as Super Admin you will land on `/setup`. Pick a preset (or pick *Blank* to define everything yourself). The wizard:

- runs `CREATE TABLE IF NOT EXISTS` for each preset entity
- registers each entity in `custom_entities`
- creates `<prefix>.{view,create,edit,delete,export,print}` permissions and grants them to Super Admin + Company Admin
- adds a sidebar menu item for each entity at `/c/<code>`
- writes `settings.system.business_type`

## 5. Optional — wire up email (Phase 4.19)

Email is **off by default**. Without it the system stays fully functional — but self-serve "Forgot password?", approval-decision emails, and the `send_email` workflow action all stub out (printed to console in dev, silent no-op in prod).

To enable, add the SMTP block to `backend/.env`:

```ini
SMTP_HOST=smtp.your-provider.com
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USER=apikey-or-username
SMTP_PASS=your-secret
SMTP_FROM="TatbeeqX <no-reply@your-domain.com>"
APP_URL=http://localhost:8080
```

Restart `npm run dev`. Verify with `curl -X POST http://localhost:4000/api/auth/forgot-password -H "Content-Type: application/json" -d '{"identifier":"superadmin"}'` — you should see an email arrive (or in dev mode, the message printed to the backend console).

Full provider matrix in [SETUP.md §7](../SETUP.md#7-optional--outbound-email-smtp).

## Web build (optional)

```bash
cd frontend
flutter run -d chrome
```

The same `API_BASE_URL` rule applies. CORS is open in dev (`cors()` with defaults).

## Common after-install commands

| Goal | Command |
|---|---|
| Reset DB to seed | `cd backend && npm run db:reset` |
| Re-seed (no schema change) | `cd backend && npm run db:seed` |
| Generate Prisma client | `cd backend && npx prisma generate` |
| Push schema (no migration record) | `cd backend && npx prisma db push --accept-data-loss --skip-generate` |
| New Flutter desktop release | `cd frontend && flutter build windows` |
| New Flutter web build | `cd frontend && flutter build web` |

## Verifying the install

1. `curl http://localhost:4000/api/health` returns `{"ok":true}`.
2. The Flutter window logs in successfully.
3. As Super Admin, the sidebar shows the full set: Dashboard, Companies, Branches, Users, Roles, Approvals, Audit Logs, Reports, Report Schedules, **Workflows**, Settings, Appearance, Database, Custom entities, Templates, Pages, System, System Logs, Login Activity, Webhooks, Backups, Translations.
4. The top bar shows the **notifications bell** (Phase 4.18) — click it and you should see "No notifications."
5. `/themes` is reachable.
6. `/database` lists tables and shows row counts.
7. `cd backend && npm test` — passes (340 tests / 28 files as of Phase 4.19, plus 8 cross-language tests that auto-skip on missing toolchains).
8. `cd frontend && flutter analyze` — zero issues.

If any of those fail, jump to [17-pitfalls.md](17-pitfalls.md). For end-user docs (sign-in, password reset, 2FA, working with the modules) see [49-user-manual.md](49-user-manual.md).
