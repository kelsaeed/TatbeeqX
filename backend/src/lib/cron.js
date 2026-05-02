// Phase 4.3 / 4.4 — minimal in-process cron with multi-instance locking + retention.
//
// Locking: each tick atomically claims schedules by stamping `lockedBy` and
// `lockedAt`. A stale lock (older than 5 minutes) is reclaimable, so a
// crashed worker doesn't block forever. Multiple API instances pointed at
// the same DB will not double-run.
//
// Retention: each tick also runs a "lazy" purge of `result` JSON blobs on
// completed runs older than the schedule's `retentionDays` (or the global
// default in `settings.system.report_retention_days`). The row is kept
// (and `resultPurged: true`) so audit history isn't lost.

import crypto from 'node:crypto';
import os from 'node:os';
import { prisma } from './prisma.js';
import { logSystem } from './system_log.js';
import { runReportById } from './reports.js';
import { sweepBackupRetention } from './backup.js';
import { runScheduledWorkflow } from './workflow_engine.js';

const TICK_MS = 60 * 1000; // one minute
const STALE_LOCK_MS = 5 * 60 * 1000; // 5 minutes
const DEFAULT_RETENTION_DAYS = 30;
const PURGE_EVERY_N_TICKS = 60; // hourly retention sweep

let started = false;
let tickCount = 0;
const WORKER_ID = `${os.hostname()}-${process.pid}-${crypto.randomBytes(4).toString('hex')}`;

export function getWorkerId() {
  return WORKER_ID;
}

export function startCronLoop() {
  if (started) return;
  started = true;
  setInterval(tick, TICK_MS).unref?.();
  setTimeout(tick, 5_000).unref?.();
}

async function tick() {
  tickCount++;
  try {
    await claimAndRun();
    await claimAndRunWorkflows();
    if (tickCount % PURGE_EVERY_N_TICKS === 1) {
      await purgeOldRunResults().catch(async (err) => {
        await logSystem('warn', 'cron', 'Retention sweep failed', { error: String(err?.message || err) });
      });
      await sweepBackupRetention().catch(async (err) => {
        await logSystem('warn', 'cron', 'Backup retention sweep failed', { error: String(err?.message || err) });
      });
    }
  } catch (err) {
    console.error('cron tick failed', err);
  }
}

async function claimAndRun() {
  const now = new Date();
  const staleCutoff = new Date(now.getTime() - STALE_LOCK_MS);

  // Find candidates due to run.
  const candidates = await prisma.reportSchedule.findMany({
    where: {
      enabled: true,
      OR: [
        { nextRunAt: null },
        { nextRunAt: { lte: now } },
      ],
      AND: [{
        OR: [
          { lockedBy: null },
          { lockedAt: { lt: staleCutoff } },
        ],
      }],
    },
    take: 100,
  });

  for (const c of candidates) {
    // Atomic claim: only succeeds if nobody else has already taken it.
    const claim = await prisma.reportSchedule.updateMany({
      where: {
        id: c.id,
        OR: [
          { lockedBy: null },
          { lockedAt: { lt: staleCutoff } },
        ],
      },
      data: { lockedBy: WORKER_ID, lockedAt: now },
    });
    if (claim.count === 0) continue;

    const fresh = await prisma.reportSchedule.findUnique({ where: { id: c.id } });
    if (!fresh) continue;

    try {
      await runOne(fresh);
    } catch (err) {
      await logSystem('error', 'cron', `Schedule ${fresh.id} (${fresh.name}) failed`, {
        error: String(err?.message || err),
      });
    } finally {
      // Release the lock regardless of outcome.
      await prisma.reportSchedule.update({
        where: { id: fresh.id },
        data: { lockedBy: null, lockedAt: null },
      }).catch(() => {});
    }
  }
}

// Phase 4.17 — workflow schedules. Same atomic-claim pattern as
// ReportSchedule, against `Workflow` rows whose triggerType='schedule'.
// The schedule shape (frequency / timeOfDay / dayOfWeek / dayOfMonth /
// cron) lives inside `triggerConfig` JSON, so we pull it out then feed
// a synthetic ReportSchedule-shaped object to `computeNext`.
async function claimAndRunWorkflows() {
  const now = new Date();
  const staleCutoff = new Date(now.getTime() - STALE_LOCK_MS);

  const candidates = await prisma.workflow.findMany({
    where: {
      enabled: true,
      triggerType: 'schedule',
      OR: [
        { nextRunAt: null },
        { nextRunAt: { lte: now } },
      ],
      AND: [{
        OR: [
          { lockedBy: null },
          { lockedAt: { lt: staleCutoff } },
        ],
      }],
    },
    take: 100,
  });

  for (const c of candidates) {
    const claim = await prisma.workflow.updateMany({
      where: {
        id: c.id,
        OR: [
          { lockedBy: null },
          { lockedAt: { lt: staleCutoff } },
        ],
      },
      data: { lockedBy: WORKER_ID, lockedAt: now },
    });
    if (claim.count === 0) continue;

    const fresh = await prisma.workflow.findUnique({ where: { id: c.id } });
    if (!fresh) continue;

    const startedAt = new Date();
    try {
      await runScheduledWorkflow(fresh);
    } catch (err) {
      await logSystem('error', 'cron', `Workflow ${fresh.id} (${fresh.code}) failed`, {
        error: String(err?.message || err),
      });
    } finally {
      let cfg = {};
      try { cfg = JSON.parse(fresh.triggerConfig || '{}'); } catch { /* ignore */ }
      const next = computeNext(cfg, startedAt);
      await prisma.workflow.update({
        where: { id: fresh.id },
        data: { lastRunAt: startedAt, nextRunAt: next, lockedBy: null, lockedAt: null },
      }).catch(() => {});
    }
  }
}

async function runOne(schedule) {
  const startedAt = new Date();
  let result = null;
  let error = null;
  let success = false;

  try {
    result = await runReportById(schedule.reportId);
    success = true;
  } catch (err) {
    error = String(err?.message || err);
  }

  await prisma.scheduledReportRun.create({
    data: {
      scheduleId: schedule.id,
      runAt: startedAt,
      success,
      result: success && result ? JSON.stringify(result) : null,
      error,
    },
  });

  const next = computeNext(schedule, startedAt);
  await prisma.reportSchedule.update({
    where: { id: schedule.id },
    data: { lastRunAt: startedAt, nextRunAt: next },
  });

  await logSystem(success ? 'info' : 'warn', 'cron', `Schedule ${schedule.id} (${schedule.name}) ran`, {
    success,
    error,
    workerId: WORKER_ID,
  });
}

async function getDefaultRetentionDays() {
  try {
    const setting = await prisma.setting.findFirst({
      where: { companyId: null, key: 'system.report_retention_days' },
    });
    if (!setting) return DEFAULT_RETENTION_DAYS;
    const parsed = Number(setting.value);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : DEFAULT_RETENTION_DAYS;
  } catch {
    return DEFAULT_RETENTION_DAYS;
  }
}

export async function purgeOldRunResults() {
  const defaultDays = await getDefaultRetentionDays();
  const schedules = await prisma.reportSchedule.findMany({});

  let purged = 0;
  for (const sch of schedules) {
    const days = (sch.retentionDays != null && sch.retentionDays > 0) ? sch.retentionDays : defaultDays;
    if (!days) continue;
    const cutoff = new Date(Date.now() - days * 86_400_000);
    const res = await prisma.scheduledReportRun.updateMany({
      where: {
        scheduleId: sch.id,
        runAt: { lt: cutoff },
        resultPurged: false,
        result: { not: null },
      },
      data: { result: null, resultPurged: true },
    });
    purged += res.count;
  }

  if (purged > 0) {
    await logSystem('info', 'cron', 'Retention sweep purged old run results', { purged });
  }
  return purged;
}

export function computeNext(schedule, from = new Date()) {
  const t = new Date(from.getTime());
  const [hh, mm] = parseTimeOfDay(schedule.timeOfDay);

  switch (schedule.frequency) {
    case 'every_minute':
      return new Date(t.getTime() + 60_000);
    case 'every_5_minutes':
      return new Date(t.getTime() + 5 * 60_000);
    case 'hourly': {
      const n = new Date(t);
      n.setMinutes(0, 0, 0);
      n.setHours(t.getHours() + 1);
      return n;
    }
    case 'daily': {
      const n = new Date(t);
      n.setHours(hh, mm, 0, 0);
      if (n <= t) n.setDate(n.getDate() + 1);
      return n;
    }
    case 'weekly': {
      const dow = clampInt(schedule.dayOfWeek, 0, 6, 1);
      const n = new Date(t);
      n.setHours(hh, mm, 0, 0);
      const delta = (dow - n.getDay() + 7) % 7;
      n.setDate(n.getDate() + (delta === 0 && n <= t ? 7 : delta));
      return n;
    }
    case 'monthly': {
      const dom = clampInt(schedule.dayOfMonth, 1, 28, 1);
      const n = new Date(t);
      n.setDate(dom);
      n.setHours(hh, mm, 0, 0);
      if (n <= t) n.setMonth(n.getMonth() + 1);
      return n;
    }
    case 'cron':
      return computeCronNext(schedule.cron, t);
    default:
      return new Date(t.getTime() + 60 * 60_000);
  }
}

function parseTimeOfDay(s) {
  const m = String(s || '00:00').match(/^(\d{1,2}):(\d{2})$/);
  if (!m) return [0, 0];
  return [Math.min(23, Math.max(0, Number(m[1]))), Math.min(59, Math.max(0, Number(m[2])))];
}

function clampInt(v, min, max, fallback) {
  const n = Number(v);
  if (!Number.isFinite(n)) return fallback;
  return Math.min(max, Math.max(min, Math.round(n)));
}

function computeCronNext(expr, from) {
  if (!expr || typeof expr !== 'string') return new Date(from.getTime() + 60 * 60_000);
  const parts = expr.trim().split(/\s+/);
  if (parts.length !== 5) return new Date(from.getTime() + 60 * 60_000);
  const minutes = expandCronField(parts[0], 0, 59);
  const hours   = expandCronField(parts[1], 0, 23);
  const days    = expandCronField(parts[2], 1, 31);
  const months  = expandCronField(parts[3], 1, 12);
  const dows    = expandCronField(parts[4], 0, 6);

  const t = new Date(from.getTime() + 60_000);
  t.setSeconds(0, 0);
  for (let i = 0; i < 366 * 24 * 60; i++) {
    if (
      minutes.has(t.getMinutes()) &&
      hours.has(t.getHours()) &&
      days.has(t.getDate()) &&
      months.has(t.getMonth() + 1) &&
      dows.has(t.getDay())
    ) {
      return t;
    }
    t.setMinutes(t.getMinutes() + 1);
  }
  return new Date(from.getTime() + 60 * 60_000);
}

function expandCronField(field, lo, hi) {
  const out = new Set();
  for (const part of field.split(',')) {
    if (part === '*') {
      for (let i = lo; i <= hi; i++) out.add(i);
      continue;
    }
    const stepMatch = part.match(/^(\*|\d+(?:-\d+)?)\/(\d+)$/);
    if (stepMatch) {
      const step = Math.max(1, Number(stepMatch[2]));
      let s = lo;
      let e = hi;
      if (stepMatch[1] !== '*') {
        const [a, b] = stepMatch[1].split('-').map(Number);
        s = a;
        e = b ?? hi;
      }
      for (let i = s; i <= e; i += step) out.add(i);
      continue;
    }
    if (part.includes('-')) {
      const [a, b] = part.split('-').map(Number);
      for (let i = a; i <= b; i++) out.add(i);
      continue;
    }
    const n = Number(part);
    if (Number.isFinite(n)) out.add(n);
  }
  return out;
}
