# 16 — Deployment

The system is built to run on a **LAN** today and to migrate to a **cloud database** later without app code changes.

## LAN deployment (the default)

### Topology

```
+--------------+         LAN         +-----------------+
| Host machine | <-----------------> | Client machines |
| (Windows PC) |  PORT 4040 (HTTP)   | (Windows PCs)   |
|              |                     | running .exe    |
| backend +    |                     |                 |
| sqlite       |                     |                 |
+--------------+                     +-----------------+
```

### Steps

1. **On the host**:
   ```bash
   cd backend
   npm install
   npm run db:reset
   npm start          # or use pm2 / nssm to run as a Windows service
   ```
2. **Allow PORT 4040 through the Windows firewall** (`Inbound rule → Port → TCP 4040 → Allow`).
3. **Find the host's LAN IP**: `ipconfig` → `IPv4 Address` (e.g. `192.168.1.10`).
4. **Build the Flutter desktop app** with the host IP baked in:
   ```bash
   cd frontend
   flutter build windows --dart-define=API_BASE_URL=http://192.168.1.10:4040/api
   ```
5. **Copy** `frontend/build/windows/x64/runner/Release/` to each client machine. The `.exe` inside is `tatbeeqx.exe`.
6. **Launch on the client.** It will hit the host on first request.

> The LAN swap point is [`AppConfig.apiBaseUrl`](../frontend/lib/core/config/app_config.dart). At build time `--dart-define=API_BASE_URL=...` overrides the localhost default.

### Running the backend as a service

Recommended on the host so it survives reboots.

- **`pm2`** (cross-platform): `npm i -g pm2 && pm2 start "npm start" --name tatbeeqx && pm2 save && pm2-startup install`
- **`nssm`** (Windows-native): `nssm install TatbeeqX "C:\Program Files\nodejs\node.exe" "C:\path\to\backend\src\server.js"`

### File backups

The single source of truth is `backend/prisma/dev.db`. Back it up nightly:

```powershell
Copy-Item -Path "F:\...\backend\prisma\dev.db" `
          -Destination "\\nas\backups\TatbeeqX\$(Get-Date -Format yyyyMMdd).db"
```

Also back up `backend/uploads/` if you use the Theme Builder's uploads.

## Going online (cloud DB)

When you outgrow LAN — multiple offices, remote users, scaling — switch the database without changing application code.

### 1. Provision a managed Postgres or MySQL

- **Postgres**: Supabase, Render, Neon, RDS, Cloud SQL.
- **MySQL**: PlanetScale, Cloud SQL, RDS.

Get a connection string.

### 2. Update `backend/.env`

```ini
DATABASE_URL="postgresql://user:pass@host:5432/TatbeeqX"
```

### 3. Update `backend/prisma/schema.prisma`

```prisma
datasource db {
  provider = "postgresql"   // was "sqlite"
  url      = env("DATABASE_URL")
}
```

### 4. Migrate and seed

```bash
cd backend
npx prisma migrate deploy
npm run db:seed
```

### 5. Host the API somewhere

Render, Fly, Railway, a small VPS. Open PORT 4040 (or put it behind nginx on 443).

### 6. Rebuild the desktop client with the public URL

```bash
flutter build windows --dart-define=API_BASE_URL=https://api.yourdomain.com/api
```

The same client also works as a web build:

```bash
flutter build web
```

Drop the resulting `build/web/` onto any static host (Netlify, Vercel, S3+CloudFront).

## Multi-tenant on cloud

Out of the box, the system is **single-database multi-company** — one DB hosts many `companies` rows. If you need true multi-tenant (one DB per customer), provision one DB per customer and run one backend instance per DB. The schema and code are unchanged.

## Updating in place

A typical "ship a new version" flow:

```bash
# on the host
cd backend
git pull
npm install
npx prisma migrate deploy
pm2 restart tatbeeqx     # or your service manager equivalent

# on each client
# replace the Release/ folder with the new build
```

Migrations are forward-only and idempotent. The seeder is idempotent for permissions, modules, menu items, and roles — so re-running it after an update will *add* new permissions/menu items without touching existing data.

## Hard reset

If you need to wipe and start over on the host:

```bash
cd backend
npm run db:reset      # destroys dev.db, re-runs migrations, re-seeds
```

This deletes data. There is no undo other than restoring a backup.
