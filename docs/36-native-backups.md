# 36 — Native pg_dump / mysqldump backups

Phase 4.7 extends the backup system in [33-backups.md](33-backups.md) to handle non-SQLite primaries. The same `/backups` UI now works for PostgreSQL and MySQL by spawning the standard CLI dump tools.

- Lib: [`backend/src/lib/backup.js`](../backend/src/lib/backup.js) — `detectProvider()`, `createPostgresBackup()`, `createMysqlBackup()`
- Endpoints unchanged — see [33-backups.md](33-backups.md)

## Provider matrix

| Primary provider | Backup mechanism | Output | In-process restore? |
|---|---|---|---|
| `sqlite` | File copy + atomic rename | `dev-<ts>[-label].db` | ✅ yes |
| `postgresql` | `pg_dump` → stdout → file | `pg-<ts>[-label].sql` | ❌ run `psql < file` from host |
| `mysql` / `mariadb` | `mysqldump` → stdout → file | `mysql-<ts>[-label].sql` | ❌ run `mysql < file` from host |
| `sqlserver`, `mongodb` | Not supported | — | — |

Provider is detected from `DATABASE_URL` via `detectProvider(url)`, not from the connection registry — so backups always target whatever the running process is actually using.

## How the dump runs

`spawnDumpToFile(bin, args, env, dest)` is the shared helper. It:

1. Opens a write stream on the destination file.
2. `child_process.spawn(bin, args, { env })` — pipes stdout into the file, captures stderr in memory.
3. On `close` with code 0, finalizes the file. On non-zero exit (or `error`), deletes the partial file and throws with the captured stderr (truncated to 1000 chars).

If the binary isn't on PATH, the user gets a clear:

> Could not run pg_dump: spawn pg_dump ENOENT. Make sure pg_dump is on PATH inside the API process or container.

## Postgres flags

```
pg_dump -h <host> -p <port> -U <user> \
        --no-owner --no-privileges --clean --if-exists --quote-all-identifiers \
        -d <database>
```

- `--no-owner` / `--no-privileges` — produce dumps that can be restored under a different role.
- `--clean --if-exists` — the dump starts with `DROP IF EXISTS` so a re-import is idempotent.
- `--quote-all-identifiers` — preserves PascalCase Prisma table names (`User`, `AuditLog`) even when restoring to a case-folded server.

Password is passed via `PGPASSWORD` (env var) so it never lands in `ps`.

## MySQL flags

```
mysqldump --single-transaction --routines --triggers --no-tablespaces \
          -h <host> -P <port> -u <user> -p<password> <database>
```

- `--single-transaction` — non-blocking dump for InnoDB tables.
- `--routines --triggers` — include stored procs / triggers.
- `--no-tablespaces` — sidesteps a `PROCESS` privilege requirement on managed MySQL services.

`mysqldump` has no `MYSQL_PWD` equivalent that's safe across all distros, so the password is inlined as `-p<password>`. **This means it's visible in `ps`** for the lifetime of the dump on multi-tenant hosts. Acceptable on a single-tenant container; if it isn't, set up a `~/.my.cnf` and remove the `-p` flag.

## URL parsing

`parseDbUrl(url)` uses Node's built-in `URL`. Supported schemes:

- `postgres://user:pass@host:5432/dbname?...`
- `postgresql://user:pass@host:5432/dbname?...`
- `mysql://user:pass@host:3306/dbname`
- `mariadb://user:pass@host:3306/dbname`

Query string params are intentionally ignored — they often contain Prisma-specific params (`schema=public`, `pgbouncer=true`) that the CLIs don't understand.

## Restoring from a `.sql` dump

Out-of-process from the host (or a sidecar container):

```bash
# Postgres
psql -h $HOST -p $PORT -U $USER -d $DB < backups/pg-2026-04-30T...-pre-migration.sql

# MySQL
mysql -h $HOST -P $PORT -u $USER -p$PASS $DB < backups/mysql-2026-04-30T...-pre-migration.sql
```

The API does not offer in-process restore for these providers — the client connections, role privileges, and concurrent writes make it too dangerous to do from inside the running app process. SQLite gets in-process restore because it has none of those concerns (single file, single writer).

## Docker compose ergonomics

If you're running the API in `docker compose` and want native dumps to work:

```dockerfile
# backend/Dockerfile (add to the apt-get install line)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       openssl ca-certificates \
       postgresql-client default-mysql-client \
    && rm -rf /var/lib/apt/lists/*
```

Skip this if you only run SQLite — the binary additions inflate the image by ~20 MB.

## Tests

The existing backup smoke test in `tests/routes_features.test.js` skips gracefully on non-SQLite primaries (returns 400 "Backup only supported for SQLite primary today" with the v4.6 message) — once the test fixture runs against pg/mysql, it'll exercise the new paths automatically. There's no Postgres in the dev test environment so the new code paths aren't covered by an automated test today; manual verification is the path.

## Caveats

- **Dump size + memory.** The dump streams to disk, so memory usage stays flat even for large databases. Don't bottleneck the API process by running ten parallel dumps.
- **Off-site copy still manual.** The roadmap item to ship dumps off-site (S3 / B2 / azure-blob) is unchanged — see [20-roadmap.md](20-roadmap.md).
- **Encryption.** Dumps are plaintext SQL on disk. Add `gpg` or `age` post-processing if your threat model needs it.
