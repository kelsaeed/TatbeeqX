import { Router } from 'express';
import { prisma } from '../lib/prisma.js';
import { authenticate } from '../middleware/auth.js';
import { requirePermission } from '../middleware/permission.js';
import { asyncHandler, notFound } from '../lib/http.js';
import { parseId, pick, requireFields } from '../middleware/validate.js';
import { writeAudit } from '../lib/audit.js';

const router = Router();
router.use(authenticate);

const fields = ['companyId', 'code', 'name', 'address', 'phone', 'isActive'];

router.get(
  '/',
  requirePermission('branches.view'),
  asyncHandler(async (req, res) => {
    const where = req.query.companyId ? { companyId: parseId(req.query.companyId) } : {};
    const items = await prisma.branch.findMany({
      where,
      include: { company: { select: { id: true, name: true } } },
      orderBy: { id: 'asc' },
    });
    res.json({ items });
  }),
);

router.get(
  '/:id',
  requirePermission('branches.view'),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const branch = await prisma.branch.findUnique({ where: { id } });
    if (!branch) throw notFound('Branch not found');
    res.json(branch);
  }),
);

router.post(
  '/',
  requirePermission('branches.create'),
  asyncHandler(async (req, res) => {
    requireFields(req.body, ['companyId', 'code', 'name']);
    const data = pick(req.body, fields);
    const created = await prisma.branch.create({ data });
    await writeAudit({ req, action: 'create', entity: 'Branch', entityId: created.id });
    res.status(201).json(created);
  }),
);

router.put(
  '/:id',
  requirePermission('branches.edit'),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const data = pick(req.body, fields);
    const updated = await prisma.branch.update({ where: { id }, data });
    await writeAudit({ req, action: 'update', entity: 'Branch', entityId: id });
    res.json(updated);
  }),
);

router.delete(
  '/:id',
  requirePermission('branches.delete'),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    await prisma.branch.delete({ where: { id } });
    await writeAudit({ req, action: 'delete', entity: 'Branch', entityId: id });
    res.json({ ok: true });
  }),
);

export default router;
