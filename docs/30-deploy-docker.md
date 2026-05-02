# 30 — Docker deployment

Cloud-first deploy via `docker compose`. Two services by default — `api` (Node + Prisma) and `web` (nginx serving the Flutter web build) — plus a commented-out `postgres` service when you outgrow SQLite.

## Files

| File | Purpose |
|---|---|
| [`backend/Dockerfile`](../backend/Dockerfile) | Single-stage Node 20-slim with OpenSSL, deps, source, and `prisma generate` baked in |
| [`backend/.dockerignore`](../backend/.dockerignore) | Keeps `node_modules`, `.env`, the dev SQLite, and tests out of the build context |
| [`docker-compose.yml`](../docker-compose.yml) | Two services + named volumes for data + uploads |
| [`deploy/nginx.conf`](../deploy/nginx.conf) | SPA + `/api` + `/uploads` reverse proxy |

## Default topology (SQLite)

```
                +---------+      :8080      +-----+
                |  user   |  ────────────▶  | web | (nginx)
                +---------+                 +-----+
                                              │ /api/, /uploads/
                                              ▼
                                            +-----+
                                            | api | (node + prisma)
                                            +-----+
                                              │
                                  named volumes:
                                  data:       /app/data    (sqlite)
                                  uploads:    /app/uploads (multer)
```

The api container's CMD runs `prisma migrate deploy || prisma db push`, then a no-op-on-conflict seed, then `node src/server.js`. So the first `docker compose up` produces a usable system with the seeded Super Admin (`superadmin` / `ChangeMe!2026` unless you set `SEED_SUPERADMIN_*`).

## Environment

`docker-compose.yml` requires:

- `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET` — make these long random strings, e.g. `openssl rand -hex 32`.

Optional:

- `DATABASE_URL` — defaults to `file:/app/data/dev.db` (SQLite on the volume). Set to a Postgres URL when promoting that service.
- `SEED_SUPERADMIN_USERNAME` / `_EMAIL` / `_PASSWORD` — override the defaults.
- `POSTGRES_PASSWORD` — only used if you uncomment the `postgres` service.

Recommended `.env` next to `docker-compose.yml`:

```ini
JWT_ACCESS_SECRET=...
JWT_REFRESH_SECRET=...
SEED_SUPERADMIN_PASSWORD=...
```

`docker compose` reads it automatically.

## First run

```bash
# build the Flutter web bundle that nginx will serve
(cd frontend && flutter build web --dart-define=API_BASE_URL=/api)

# bring everything up
docker compose up --build -d

# tail logs
docker compose logs -f api
```

Then open `http://localhost:8080`.

## Promoting to Postgres

1. Uncomment the `postgres` service block in `docker-compose.yml` and the `pgdata` volume.
2. Edit `backend/prisma/schema.prisma`: `provider = "postgresql"`.
3. Set `DATABASE_URL` in `.env`:
   ```ini
   DATABASE_URL=postgresql://money:${POSTGRES_PASSWORD}@postgres:5432/TatbeeqX
   ```
4. Uncomment the `depends_on` block under `api` so it waits for postgres' health check.
5. `docker compose up --build -d`.

The api's CMD will run `prisma migrate deploy` against the new database, seed defaults, and start. SQLite-era data is **not** migrated — see [16-deployment.md](16-deployment.md) for the manual swap path.

## Updating

Bump `version` in `backend/package.json` (or just rebuild) and:

```bash
docker compose build
docker compose up -d
```

The seed is idempotent for permissions, modules, menu items, and roles — re-running the container will *add* new permissions/menu items added to the seed without touching existing data.

## Hardening checklist (before prod)

- Run nginx behind a TLS terminator (Caddy / Traefik / a CDN). The current `deploy/nginx.conf` is plain HTTP for clarity.
- Set strong `JWT_*_SECRET` values, not the defaults.
- Set a strong `SEED_SUPERADMIN_PASSWORD` and rotate the seeded admin's password from the UI on first login.
- Restrict `4000` (the api port) so only `web` can reach it. Today it's published on the host for ease of debugging.
- Mount `data` and `uploads` on durable storage and back them up regularly.
- For multi-instance scale-out, run only one api replica until you've moved off SQLite — the cron loop's claim-based locking is correct only when all instances share a Postgres/MySQL primary.

## Caveats

- **Multi-arch image** — the slim image is multi-arch via the official `node:20-slim`, but Prisma's binary engine is platform-specific and will be downloaded at `prisma generate` time during the build. If you're building on Mac arm64 for an x86_64 host, set `--platform linux/amd64` on the build.
- **No HTTPS in this template** — terminate TLS in your edge (Caddy/Traefik/cloud LB), not in nginx here.
