import { Router } from 'express';
import { prisma } from '../lib/prisma.js';
import { authenticate } from '../middleware/auth.js';
import { requirePermission } from '../middleware/permission.js';
import { asyncHandler, badRequest, notFound } from '../lib/http.js';
import { parseId, requireFields } from '../middleware/validate.js';
import { writeAudit } from '../lib/audit.js';
import { computeNext } from '../lib/cron.js';
import { runReportById } from '../lib/reports.js';

const router = Router();
router.use(authenticate);

const SUPPORTED_FREQUENCIES = ['every_minute', 'every_5_minutes', 'hourly', 'daily', 'weekly', 'monthly', 'cron'];

function parseRun(r) {
  let result = null;
  try { result = r.result ? JSON.parse(r.result) : null; } catch { result = null; }
  return { ...r, result };
}

router.get(
  '/',
  requirePermission('report_schedules.view'),
  asyncHandler(async (_req, res) => {
    const items = await prisma.reportSchedule.findMany({
      include: { report: { select: { id: true, code: true, name: true } } },
      orderBy: { id: 'asc' },
    });
    res.json({ items });
  }),
);

router.get(
  '/frequencies',
  asyncHandler(async (_req, res) => {
    res.json({ items: SUPPORTED_FREQUENCIES });
  }),
);

router.get(
  '/:id',
  requirePermission('report_schedules.view'),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const item = await prisma.reportSchedule.findUnique({
      where: { id },
      include: {
        report: { select: { id: true, code: true, name: true } },
        runs: { orderBy: { id: 'desc' }, take: 25 },
      },
    });
    if (!item) throw notFound('Schedule not found');
    res.json({ ...item, runs: item.runs.map(parseRun) });
  }),
);

router.post(
  '/',
  requirePermission('report_schedules.create'),
  asyncHandler(async (req, res) => {
    requireFields(req.body, ['reportId', 'name', 'frequency']);
    const { reportId, name, frequency, cron = null, timeOfDay = null, dayOfWeek = null, dayOfMonth = null, enabled = true } = req.body;
    if (!SUPPORTED_FREQUENCIES.includes(frequency)) throw badRequest(`Unknown frequency: ${frequency}`);
    if (frequency === 'cron' && !cron) throw badRequest('cron field is required when frequency=cron');

    const report = await prisma.report.findUnique({ where: { id: Number(reportId) } });
    if (!report) throw notFound('Report not found');

    const draft = { frequency, cron, timeOfDay, dayOfWeek, dayOfMonth };
    const nextRunAt = computeNext(draft);

    const created = await prisma.reportSchedule.create({
      data: {
        reportId: Number(reportId),
        name,
        frequency,
        cron,
        timeOfDay,
        dayOfWeek: dayOfWeek != null ? Number(dayOfWeek) : null,
        dayOfMonth: dayOfMonth != null ? Number(dayOfMonth) : null,
        enabled,
        nextRunAt,
      },
    });
    await writeAudit({ req, action: 'create', entity: 'ReportSchedule', entityId: created.id });
    res.status(201).json(created);
  }),
);

router.put(
  '/:id',
  requirePermission('report_schedules.edit'),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const existing = await prisma.reportSchedule.findUnique({ where: { id } });
    if (!existing) throw notFound('Schedule not found');

    const update = {};
    for (const f of ['name', 'frequency', 'cron', 'timeOfDay', 'enabled']) {
      if (req.body[f] !== undefined) update[f] = req.body[f];
    }
    if (req.body.dayOfWeek !== undefined) update.dayOfWeek = req.body.dayOfWeek != null ? Number(req.body.dayOfWeek) : null;
    if (req.body.dayOfMonth !== undefined) update.dayOfMonth = req.body.dayOfMonth != null ? Number(req.body.dayOfMonth) : null;
    if (update.frequency && !SUPPORTED_FREQUENCIES.includes(update.frequency)) {
      throw badRequest(`Unknown frequency: ${update.frequency}`);
    }

    // Recompute nextRunAt if any timing field changed
    const merged = { ...existing, ...update };
    update.nextRunAt = computeNext(merged);

    const updated = await prisma.reportSchedule.update({ where: { id }, data: update });
    await writeAudit({ req, action: 'update', entity: 'ReportSchedule', entityId: id });
    res.json(updated);
  }),
);

router.delete(
  '/:id',
  requirePermission('report_schedules.delete'),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    await prisma.reportSchedule.delete({ where: { id } });
    await writeAudit({ req, action: 'delete', entity: 'ReportSchedule', entityId: id });
    res.json({ ok: true });
  }),
);

router.post(
  '/:id/run-now',
  requirePermission('report_schedules.edit'),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const sch = await prisma.reportSchedule.findUnique({ where: { id } });
    if (!sch) throw notFound('Schedule not found');

    const startedAt = new Date();
    let success = false;
    let result = null;
    let errMsg = null;
    try {
      result = await runReportById(sch.reportId);
      success = true;
    } catch (err) {
      errMsg = String(err?.message || err);
    }
    await prisma.scheduledReportRun.create({
      data: {
        scheduleId: id,
        runAt: startedAt,
        success,
        result: success && result ? JSON.stringify(result) : null,
        error: errMsg,
      },
    });
    await prisma.reportSchedule.update({
      where: { id },
      data: { lastRunAt: startedAt, nextRunAt: computeNext(sch) },
    });
    await writeAudit({ req, action: 'run_now', entity: 'ReportSchedule', entityId: id, metadata: { success } });
    res.json({ ok: true, success, error: errMsg });
  }),
);

router.get(
  '/:id/runs',
  requirePermission('report_schedules.view'),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const items = await prisma.scheduledReportRun.findMany({
      where: { scheduleId: id },
      orderBy: { id: 'desc' },
      take: 100,
    });
    res.json({ items: items.map(parseRun) });
  }),
);

export default router;
