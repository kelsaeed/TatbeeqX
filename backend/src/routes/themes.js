import { Router } from 'express';
import { prisma } from '../lib/prisma.js';
import { authenticate } from '../middleware/auth.js';
import { requireSuperAdmin } from '../middleware/permission.js';
import { asyncHandler, badRequest, notFound } from '../lib/http.js';
import { parseId, requireFields } from '../middleware/validate.js';
import { writeAudit } from '../lib/audit.js';
import { parseTheme } from '../lib/theme_parse.js';

const router = Router();

router.get(
  '/active',
  asyncHandler(async (req, res) => {
    const companyId = req.query.companyId ? Number(req.query.companyId) : null;
    const theme =
      (companyId &&
        (await prisma.theme.findFirst({ where: { companyId, isActive: true } }))) ||
      (await prisma.theme.findFirst({ where: { companyId: null, isActive: true } })) ||
      (await prisma.theme.findFirst({ where: { isDefault: true } }));
    if (!theme) return res.json({ theme: null });
    res.json({ theme: parseTheme(theme) });
  }),
);

router.use(authenticate);

router.get(
  '/',
  requireSuperAdmin(),
  asyncHandler(async (_req, res) => {
    const items = await prisma.theme.findMany({ orderBy: { id: 'asc' } });
    res.json({ items: items.map(parseTheme) });
  }),
);

router.get(
  '/:id',
  requireSuperAdmin(),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const theme = await prisma.theme.findUnique({ where: { id } });
    if (!theme) throw notFound('Theme not found');
    res.json(parseTheme(theme));
  }),
);

router.post(
  '/',
  requireSuperAdmin(),
  asyncHandler(async (req, res) => {
    requireFields(req.body, ['name', 'data']);
    const { name, companyId = null, data, isDefault = false, isActive = false } = req.body;
    const created = await prisma.theme.create({
      data: { name, companyId, data: JSON.stringify(data), isDefault, isActive },
    });
    await writeAudit({ req, action: 'create', entity: 'Theme', entityId: created.id });
    res.status(201).json(parseTheme(created));
  }),
);

router.put(
  '/:id',
  requireSuperAdmin(),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const { name, data, isDefault, isActive, companyId } = req.body;
    const update = {};
    if (name !== undefined) update.name = name;
    if (companyId !== undefined) update.companyId = companyId;
    if (data !== undefined) update.data = JSON.stringify(data);
    if (isDefault !== undefined) update.isDefault = isDefault;
    if (isActive !== undefined) update.isActive = isActive;
    const updated = await prisma.theme.update({ where: { id }, data: update });
    await writeAudit({ req, action: 'update', entity: 'Theme', entityId: id });
    res.json(parseTheme(updated));
  }),
);

router.post(
  '/:id/activate',
  requireSuperAdmin(),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const theme = await prisma.theme.findUnique({ where: { id } });
    if (!theme) throw notFound('Theme not found');
    await prisma.$transaction([
      prisma.theme.updateMany({ where: { companyId: theme.companyId }, data: { isActive: false } }),
      prisma.theme.update({ where: { id }, data: { isActive: true } }),
    ]);
    await writeAudit({ req, action: 'activate', entity: 'Theme', entityId: id });
    res.json({ ok: true });
  }),
);

router.post(
  '/:id/duplicate',
  requireSuperAdmin(),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const theme = await prisma.theme.findUnique({ where: { id } });
    if (!theme) throw notFound('Theme not found');
    const copy = await prisma.theme.create({
      data: {
        name: `${theme.name} (copy)`,
        companyId: theme.companyId,
        data: theme.data,
        isDefault: false,
        isActive: false,
      },
    });
    await writeAudit({ req, action: 'duplicate', entity: 'Theme', entityId: copy.id });
    res.status(201).json(parseTheme(copy));
  }),
);

router.post(
  '/:id/reset',
  requireSuperAdmin(),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const defaultTheme = await prisma.theme.findFirst({ where: { isDefault: true } });
    if (!defaultTheme) throw badRequest('No default theme available');
    const updated = await prisma.theme.update({
      where: { id },
      data: { data: defaultTheme.data },
    });
    await writeAudit({ req, action: 'reset', entity: 'Theme', entityId: id });
    res.json(parseTheme(updated));
  }),
);

router.delete(
  '/:id',
  requireSuperAdmin(),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const theme = await prisma.theme.findUnique({ where: { id } });
    if (!theme) throw notFound('Theme not found');
    if (theme.isDefault) throw badRequest('Cannot delete the default theme');
    await prisma.theme.delete({ where: { id } });
    await writeAudit({ req, action: 'delete', entity: 'Theme', entityId: id });
    res.json({ ok: true });
  }),
);

export default router;
