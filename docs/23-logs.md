# 23 — Logs

The system records three kinds of logs, each in its own table:

| Table | What it captures | Module / page | Permission |
|---|---|---|---|
| `audit_logs` | every business mutation (create/update/delete/approve/login/…) | `audit` → `/audit` | `audit.view` |
| `system_logs` | server-side events (info/warn/error, source-tagged) | `system_logs` → `/system-logs` | `system_logs.view` |
| `login_events` | every login, logout, refresh, and failed attempt | `login_events` → `/login-events` | `login_events.view` |

Three tables, not one, because they answer different questions:
- "Who changed this record?" → audit log
- "What is the server doing? Did anything fail?" → system log
- "Has this account had failed logins overnight?" → login events

## Audit log

Already covered in [05-permissions.md](05-permissions.md) and [07-api-reference.md](07-api-reference.md). Every mutating route calls `writeAudit({ req, action, entity, entityId, metadata })` after the mutation succeeds.

## System log

`backend/src/lib/system_log.js` exports `logSystem(level, source, message, context?)`. Levels: `debug`, `info`, `warn`, `error`. Source is a free-form short string (e.g. `system`, `auth`, `business_presets`). Context is anything JSON-serializable.

Call sites that exist today:
- DB connection promote (`source: 'system'`)
- DB init SQL (`source: 'system'`)
- DB connection create (`source: 'system'`)

Add more from any backend file: imports/installs, slow queries, retries, rate-limit hits, anything you want to inspect later.

| Method | Path | Permission |
|---|---|---|
| GET | `/api/system-logs` | `system_logs.view` (filters: `level`, `source`, `q`, `from`, `to`, `page`, `pageSize`) |
| GET | `/api/system-logs/sources` | `system_logs.view` (distinct sources with counts) |
| DELETE | `/api/system-logs/:id` | `system_logs.delete` |
| POST | `/api/system-logs/clear` | `system_logs.delete` (body: `{ olderThanDays?, level? }`) |

The viewer at `/system-logs` exposes level + source filters and a global search box.

## Login events

Recorded by `recordLoginEvent` in `backend/src/lib/system_log.js`. Captured automatically:

| When | event | success | reason on failure |
|---|---|---|---|
| `/auth/login` succeeds | `login` | true | — |
| `/auth/login` user not found | `login` | false | `unknown_user` |
| `/auth/login` user inactive | `login` | false | `inactive_user` |
| `/auth/login` wrong password | `login` | false | `bad_password` |
| `/auth/refresh` succeeds | `refresh` | true | — |
| `/auth/logout` succeeds | `logout` | true | — |

Each row stores `userId` (when known), `username`, `ipAddress`, `userAgent`. Indexed on `userId`, `event`, `createdAt`.

| Method | Path | Permission |
|---|---|---|
| GET | `/api/login-events` | `login_events.view` (filters: `userId`, `event`, `success`, `q`, `page`, `pageSize`) |

The viewer at `/login-events` exposes event + success filters and a search box (matches username / IP / user agent).

## What about per-user activity timeline

The audit log's `userId` field already gives you "everything user X did". A per-user view in the Users module that filters audit + login events by `userId` is the natural addition; it's on the [roadmap](20-roadmap.md).

## Retention

Right now: nothing is auto-purged. The `Clear older than 30 days` action on `/system-logs` deletes by age; analogous actions for audit and login events are easy to add — just `prisma.<table>.deleteMany({ where: { createdAt: { lt: cutoff } } })` behind a `*.delete` permission.

If the DB grows large (millions of rows), pre-create indexes on `createdAt` (already done) and consider a nightly cron + a "log archive" target.
