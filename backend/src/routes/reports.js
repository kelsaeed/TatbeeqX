import { Router } from 'express';
import { prisma } from '../lib/prisma.js';
import { authenticate } from '../middleware/auth.js';
import { requirePermission } from '../middleware/permission.js';
import { asyncHandler, badRequest, forbidden, notFound } from '../lib/http.js';
import { parseId, pick, requireFields } from '../middleware/validate.js';
import { writeAudit } from '../lib/audit.js';
import { listBuilders, runReport } from '../lib/reports.js';

const router = Router();
router.use(authenticate);

function toDto(r) {
  let cfg = {};
  try {
    cfg = r.config ? JSON.parse(r.config) : {};
  } catch {
    cfg = {};
  }
  return {
    id: r.id,
    code: r.code,
    name: r.name,
    description: r.description,
    category: r.category,
    builder: r.builder,
    config: cfg,
    isSystem: r.isSystem,
    isActive: r.isActive,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
  };
}

router.get(
  '/builders',
  requirePermission('reports.view'),
  asyncHandler(async (_req, res) => {
    res.json({ items: listBuilders() });
  }),
);

router.get(
  '/',
  requirePermission('reports.view'),
  asyncHandler(async (req, res) => {
    const where = { isActive: true };
    if (req.query.category) where.category = String(req.query.category);
    const items = await prisma.report.findMany({ where, orderBy: [{ category: 'asc' }, { name: 'asc' }] });
    res.json({ items: items.map(toDto) });
  }),
);

router.get(
  '/:id',
  requirePermission('reports.view'),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const report = await prisma.report.findUnique({ where: { id } });
    if (!report) throw notFound('Report not found');
    res.json(toDto(report));
  }),
);

router.post(
  '/:id/run',
  requirePermission('reports.view'),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const report = await prisma.report.findUnique({ where: { id } });
    if (!report) throw notFound('Report not found');
    let config = {};
    try {
      config = report.config ? JSON.parse(report.config) : {};
    } catch {
      config = {};
    }
    const params = req.body && typeof req.body === 'object' ? req.body : {};
    const result = await runReport(report.builder, { ...config, ...params });
    await writeAudit({ req, action: 'run', entity: 'Report', entityId: report.id });
    res.json(result);
  }),
);

router.post(
  '/',
  requirePermission('reports.create'),
  asyncHandler(async (req, res) => {
    requireFields(req.body, ['code', 'name', 'builder']);
    const builders = listBuilders();
    if (!builders.includes(req.body.builder)) throw badRequest(`Unknown builder. Allowed: ${builders.join(', ')}`);
    const data = pick(req.body, ['code', 'name', 'description', 'category', 'builder', 'isActive']);
    data.config = JSON.stringify(req.body.config ?? {});
    const created = await prisma.report.create({ data });
    await writeAudit({ req, action: 'create', entity: 'Report', entityId: created.id });
    res.status(201).json(toDto(created));
  }),
);

router.put(
  '/:id',
  requirePermission('reports.edit'),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const existing = await prisma.report.findUnique({ where: { id } });
    if (!existing) throw notFound('Report not found');
    if (existing.isSystem && req.body.builder && req.body.builder !== existing.builder) {
      throw forbidden('Cannot change the builder of a system report');
    }
    const data = pick(req.body, ['name', 'description', 'category', 'builder', 'isActive']);
    if (req.body.config !== undefined) data.config = JSON.stringify(req.body.config);
    const updated = await prisma.report.update({ where: { id }, data });
    await writeAudit({ req, action: 'update', entity: 'Report', entityId: id });
    res.json(toDto(updated));
  }),
);

router.delete(
  '/:id',
  requirePermission('reports.delete'),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const existing = await prisma.report.findUnique({ where: { id } });
    if (!existing) throw notFound('Report not found');
    if (existing.isSystem) throw forbidden('Cannot delete a system report');
    await prisma.report.delete({ where: { id } });
    await writeAudit({ req, action: 'delete', entity: 'Report', entityId: id });
    res.json({ ok: true });
  }),
);

export default router;
