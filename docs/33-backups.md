# 33 — Database backups

Snapshots of the primary database, taken from the UI. Restore overwrites the live DB and requires an API restart.

- Page: `/backups`
- Backend: [`routes/admin.js`](../backend/src/routes/admin.js), [`lib/backup.js`](../backend/src/lib/backup.js)
- Permissions: `backups.view`, `backups.create`, `backups.delete`. Restore is gated on **Super Admin** specifically (no granular permission), since it can delete data.

## Today: SQLite only

The current implementation copies the SQLite DB file. The endpoints return a clear `400` for any other primary provider:

> Backup only supported for SQLite primary today. For Postgres / MySQL, use pg_dump / mysqldump from the host.

Native Postgres/MySQL backup support is on the roadmap; for now, run those tools from the host or a sidecar container.

## Storage layout

```
backend/
  backups/
    dev-2026-04-30T19-45-00-000Z.db
    dev-2026-04-30T19-50-12-345Z-pre-migration.db
```

The directory is created on demand by `getBackupsDir()` and lives next to the rest of the backend (alongside `uploads/` and `.env-backups/`). It is **not** gitignored by default — add `backend/backups/` to your `.gitignore` if you don't want snapshots to slip into commits.

## Endpoints

| Method | Path | Permission | Notes |
|---|---|---|---|
| GET | `/api/admin/backups` | `backups.view` | lists files in `backend/backups/` with size + mtime |
| POST | `/api/admin/backups` | `backups.create` | body: `{ label? }`. Label sanitized to `[a-z0-9_-]` and capped at 40 chars. |
| DELETE | `/api/admin/backups/:name` | `backups.delete` | `name` validated against `[A-Za-z0-9._-]` and confined to the backups dir. |
| POST | `/api/admin/backups/:name/restore` | Super Admin | overwrites the live DB; returns `restartRequired: true` and a message. |

## Restore flow

1. The endpoint disconnects the in-process Prisma client (`prisma.$disconnect()`) so the engine releases its file lock.
2. Copies the backup file to `<live>.restoring-<ts>` (staging).
3. Renames staging onto the live file path — atomic on a single filesystem.
4. Returns `{ ok: true, restartRequired: true }`.

The API process **does not auto-restart**. The user must restart it (e.g. `pm2 restart` or by stopping `npm run dev` + restarting). On boot, Prisma re-opens the new file.

> **Why no auto-restart?** Forcing a process restart from a web request is a footgun — in-flight requests die mid-write, partial responses get sent. Restore = "stage the change", restart = "go live". The same pattern as DB-connection promote in [22-system-config.md](22-system-config.md).

## Naming

Backup files are named `dev-<ISO-timestamp>[-<label>].db`. The timestamp is the wall clock at create time (not necessarily the DB's last-write time). The `-label` segment is kebab-case.

## Audit + system log

- Every `create`/`delete`/`restore` writes an `audit_logs` row (`entity: "Backup"`).
- `lib/backup.js` also calls `logSystem('info'|'warn', 'backup', …)` so the admin can see backup activity at `/system-logs`.

## Operational notes

- **Run while idle.** SQLite tolerates the file copy at any time, but a backup taken during heavy writes may capture an in-progress transaction. Schedule backups during low-traffic windows.
- **Back up `uploads/` separately** — the current endpoints only snapshot the DB. Theme assets and user uploads are still on disk in `backend/uploads/`. A full restore needs both.
- **No off-site sync.** Files stay local. Wire up rclone, restic, or your cloud provider's storage CLI to ship them off-host. A periodic job that POSTs to `/api/admin/backups` followed by an off-site copy is a reasonable cron pattern.
- **Retention.** Auto-pruned on the hourly cron tick — see [Retention policy](#retention-policy) below.

## Retention policy

Files in `backend/backups/` are pruned automatically by the in-process cron loop (`lib/cron.js`), once per hour. Two rules are applied together — a file is deleted if **either** triggers, but the floor `minKeep` is always honored:

| Setting key (companyId=null) | Default | Meaning |
|---|---|---|
| `system.backup_retention_days` | `30` | Delete files older than N days. `0` disables the age rule. |
| `system.backup_retention_max_count` | `0` | Keep only the newest N files. `0` disables the count rule. |
| `system.backup_retention_min_keep` | `1` | Never let count drop below this — protects against deleting the last backup. |

All three are read at sweep time. Change them via `PUT /api/settings` (or the Settings UI) and the next sweep picks up the new values — no restart needed.

The sweep:
- Only touches files matching `*.db`, `*.sql`, `*.db.enc`, `*.sql.enc` (same regex as `listBackups()`). Operator-dropped files are left alone.
- Sorts by mtime, newest first. The newest `minKeep` files are protected unconditionally.
- Logs a single `info` line under [system logs](23-logs.md) per sweep when anything was deleted; silent otherwise.
- **Does not** fire a webhook on retention deletion. Receivers maintain their own copy under their own retention.

To run the sweep on demand (e.g. after lowering the limits):

```
POST /api/admin/backups/sweep-retention   (Super Admin)
→ { deleted: [...], kept: <count>, totalBefore: <count>, config: {...} }
```

## Roadmap

- Native `pg_dump` + `mysqldump` paths for cloud installs.
- Optional encryption (AES-256 with a key from `.env`).
- Off-site upload after create (S3 / B2 / azure-blob).
