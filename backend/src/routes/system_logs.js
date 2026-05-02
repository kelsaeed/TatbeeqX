import { Router } from 'express';
import { prisma } from '../lib/prisma.js';
import { authenticate } from '../middleware/auth.js';
import { requirePermission } from '../middleware/permission.js';
import { asyncHandler } from '../lib/http.js';
import { parseId, parsePagination } from '../middleware/validate.js';
import { writeAudit } from '../lib/audit.js';

const router = Router();

router.use(authenticate);

router.get(
  '/',
  requirePermission('system_logs.view'),
  asyncHandler(async (req, res) => {
    const { skip, take, page, pageSize } = parsePagination(req.query);
    const where = {};
    if (req.query.level) where.level = String(req.query.level);
    if (req.query.source) where.source = String(req.query.source);
    if (req.query.q) {
      where.OR = [
        { message: { contains: String(req.query.q) } },
        { context: { contains: String(req.query.q) } },
      ];
    }
    if (req.query.from) where.createdAt = { ...(where.createdAt || {}), gte: new Date(String(req.query.from)) };
    if (req.query.to) where.createdAt = { ...(where.createdAt || {}), lte: new Date(String(req.query.to)) };

    const [items, total] = await prisma.$transaction([
      prisma.systemLog.findMany({ where, skip, take, orderBy: { id: 'desc' } }),
      prisma.systemLog.count({ where }),
    ]);
    res.json({ items, total, page, pageSize });
  }),
);

router.get(
  '/sources',
  requirePermission('system_logs.view'),
  asyncHandler(async (_req, res) => {
    const rows = await prisma.systemLog.groupBy({
      by: ['source'],
      _count: { _all: true },
      orderBy: { source: 'asc' },
    });
    res.json({ items: rows.map((r) => ({ source: r.source, count: r._count._all })) });
  }),
);

router.delete(
  '/:id',
  requirePermission('system_logs.delete'),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    await prisma.systemLog.delete({ where: { id } });
    await writeAudit({ req, action: 'delete', entity: 'SystemLog', entityId: id });
    res.json({ ok: true });
  }),
);

router.post(
  '/clear',
  requirePermission('system_logs.delete'),
  asyncHandler(async (req, res) => {
    const where = {};
    if (req.body.olderThanDays) {
      const cutoff = new Date(Date.now() - Number(req.body.olderThanDays) * 86400 * 1000);
      where.createdAt = { lte: cutoff };
    }
    if (req.body.level) where.level = String(req.body.level);
    const result = await prisma.systemLog.deleteMany({ where });
    await writeAudit({ req, action: 'clear', entity: 'SystemLog', metadata: { ...where, deleted: result.count } });
    res.json({ ok: true, deleted: result.count });
  }),
);

export default router;
