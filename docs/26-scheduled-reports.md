# 26 — Scheduled reports

Run any report on a recurring cadence. The cron loop ticks every minute inside the API process. Each run stores its result so you can browse history.

- Page: `/report-schedules`
- Backend: [routes/report_schedules.js](../backend/src/routes/report_schedules.js), [lib/cron.js](../backend/src/lib/cron.js), `runReportById` in [lib/reports.js](../backend/src/lib/reports.js)
- Models: `ReportSchedule`, `ScheduledReportRun` in [schema.prisma](../backend/prisma/schema.prisma)
- Permissions: `report_schedules.view` / `.create` / `.edit` / `.delete`

## How the loop works

`startCronLoop()` is called at the end of `server.js` boot. It registers a single `setInterval(tick, 60_000)` and runs an initial tick 5 seconds after startup so any schedules with `nextRunAt` in the past run immediately.

Each tick:

1. Selects up to 100 schedules where `enabled = true` AND (`nextRunAt IS NULL OR nextRunAt <= now`).
2. For each, calls `runReportById(reportId)`.
3. Writes a `ScheduledReportRun` row with the result (or error) and the run timestamp.
4. Computes `nextRunAt` from the schedule's frequency fields and updates the schedule.

Failures inside one schedule do not stop the loop or affect other schedules. Each failure is also logged at `level: 'warn', source: 'cron'` so you can find them in `/system-logs`.

## Frequencies

```js
const SUPPORTED_FREQUENCIES = [
  'every_minute',
  'every_5_minutes',
  'hourly',
  'daily',          // uses timeOfDay "HH:MM"
  'weekly',         // uses timeOfDay + dayOfWeek (0=Sun..6=Sat)
  'monthly',        // uses timeOfDay + dayOfMonth (1-28)
  'cron',           // uses cron field; 5-field standard cron, minute precision
];
```

`computeNext(schedule, from)` in `lib/cron.js` is the single source of truth. The route calls it on create/update so `nextRunAt` is set up front, and the loop calls it after each run to step forward.

## Cron expression syntax

Standard 5-field cron, minute precision. Supports `*`, comma lists, `a-b` ranges, and `*/N` step. The fields are:

```
 minute   hour   dayOfMonth   month   dayOfWeek
   0-59    0-23      1-31      1-12     0-6 (Sun=0)
```

Example: `0 9 * * 1-5` → 09:00 every weekday.

The parser is in [lib/cron.js](../backend/src/lib/cron.js) — no `node-cron` dependency.

## Endpoints

| Method | Path | Permission |
|---|---|---|
| GET | `/api/report-schedules` | `report_schedules.view` |
| GET | `/api/report-schedules/frequencies` | auth — canonical list |
| GET | `/api/report-schedules/:id` | `report_schedules.view` (includes last 25 runs) |
| GET | `/api/report-schedules/:id/runs` | `report_schedules.view` (last 100) |
| POST | `/api/report-schedules` | `report_schedules.create` |
| PUT | `/api/report-schedules/:id` | `report_schedules.edit` (recomputes `nextRunAt` if any timing field changed) |
| POST | `/api/report-schedules/:id/run-now` | `report_schedules.edit` — manual trigger; writes a `ScheduledReportRun` row exactly like the cron loop does |
| DELETE | `/api/report-schedules/:id` | `report_schedules.delete` (cascade deletes runs) |

## Run storage

Runs go to `ScheduledReportRun`:

```
id  scheduleId  runAt              success  result (JSON | null)  error
1    7          2026-04-30 09:00   true     {columns,rows}         null
2    7          2026-05-01 09:00   false    null                   "Unknown report builder: …"
```

`result` is the full `{ columns, rows }` payload from the report builder, JSON-serialized. There's no auto-purge — see [20-roadmap.md](20-roadmap.md) for retention.

## Multi-instance locking (Phase 4.4)

Each tick **atomically claims** schedules by stamping `lockedBy` (`<host>-<pid>-<rand>`) and `lockedAt` via a conditional `updateMany`. Multiple API instances pointed at the same DB will not double-run — only one wins the claim. A stale lock (older than 5 minutes) is reclaimable, so a crashed worker doesn't block forever.

The lock is released in a `finally` block so a failure inside the report builder still frees the schedule for the next tick.

## Retention sweep (Phase 4.4)

Once an hour, the loop calls `purgeOldRunResults()`:

1. Reads the global default from `settings.system.report_retention_days` (default `30`).
2. For each schedule, applies the schedule's own `retentionDays` if set, otherwise the default.
3. Sets `result = null, resultPurged = true` on runs older than the cutoff.

The row is **kept** so audit history isn't lost — only the (potentially huge) result blob is dropped. Use `resultPurged` to distinguish "never had a result" from "result was purged".

To set a per-schedule retention:

```sql
UPDATE report_schedules SET retention_days = 7 WHERE id = 12;
```

To set the global default through the UI: write to `settings.system.report_retention_days` (Settings page → key/value).

## Caveats

- **Loop stops if the process stops.** No external scheduler. `pm2`/`nssm` keep the process alive across reboots; otherwise the loop only runs while `npm start` is up.
- **`computeNext` for monthly is clamped to day-of-month 1–28** to avoid the "Feb 30th" trap. If you need true end-of-month, use a cron expression.
- **Result rows can be large.** Even with retention, large recent results can occupy significant DB. Tune `retentionDays` per schedule for hot reports.

## Wiring a new builder

Schedules don't need anything special — they just call `runReportById(reportId)`, which delegates to the registry in `lib/reports.js`. Add a builder there, register a `Report` row pointing at it, and any schedule on that report will use it.
