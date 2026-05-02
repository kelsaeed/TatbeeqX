# 03 — Getting started

This walks through a clean install on a Windows machine with no prior setup.

## Prerequisites

- Node.js 20+ on the PATH (`node -v`)
- Flutter 3.41+ on the PATH (`flutter --version`) with Windows desktop enabled (`flutter config --enable-windows-desktop`)
- Visual Studio 2022 Build Tools with the **C++ desktop development** workload (required for the Windows desktop build)
- VS Code (recommended)

## 1. Clone / open the project

```
F:\Backup for TatbeeqX\New Project\
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
3. The sidebar shows: Dashboard, Companies, Branches, Users, Roles, Reports, Audit Logs, Settings, Appearance, Database, Custom entities, Templates.
4. `/themes` is reachable as Super Admin.
5. `/database` lists tables and shows row counts.

If any of those fail, jump to [17-pitfalls.md](17-pitfalls.md).
