import { Router } from 'express';
import { prisma } from '../lib/prisma.js';
import { authenticate } from '../middleware/auth.js';
import { requirePermission } from '../middleware/permission.js';
import { asyncHandler, notFound } from '../lib/http.js';
import { parseId, pick, requireFields } from '../middleware/validate.js';
import { writeAudit } from '../lib/audit.js';

const router = Router();
router.use(authenticate);

const fields = ['code', 'name', 'legalName', 'taxNumber', 'email', 'phone', 'address', 'logoUrl', 'isActive'];

router.get(
  '/',
  requirePermission('companies.view'),
  asyncHandler(async (_req, res) => {
    const items = await prisma.company.findMany({
      include: { _count: { select: { branches: true, users: true } } },
      orderBy: { id: 'asc' },
    });
    res.json({ items });
  }),
);

router.get(
  '/:id',
  requirePermission('companies.view'),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const company = await prisma.company.findUnique({
      where: { id },
      include: { branches: true, _count: { select: { users: true } } },
    });
    if (!company) throw notFound('Company not found');
    res.json(company);
  }),
);

router.post(
  '/',
  requirePermission('companies.create'),
  asyncHandler(async (req, res) => {
    requireFields(req.body, ['code', 'name']);
    const data = pick(req.body, fields);
    const created = await prisma.company.create({ data });
    await writeAudit({ req, action: 'create', entity: 'Company', entityId: created.id });
    res.status(201).json(created);
  }),
);

router.put(
  '/:id',
  requirePermission('companies.edit'),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const data = pick(req.body, fields);
    const updated = await prisma.company.update({ where: { id }, data });
    await writeAudit({ req, action: 'update', entity: 'Company', entityId: id });
    res.json(updated);
  }),
);

router.delete(
  '/:id',
  requirePermission('companies.delete'),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    await prisma.company.delete({ where: { id } });
    await writeAudit({ req, action: 'delete', entity: 'Company', entityId: id });
    res.json({ ok: true });
  }),
);

export default router;
