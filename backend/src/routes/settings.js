import { Router } from 'express';
import { prisma } from '../lib/prisma.js';
import { authenticate } from '../middleware/auth.js';
import { requirePermission } from '../middleware/permission.js';
import { asyncHandler } from '../lib/http.js';
import { writeAudit } from '../lib/audit.js';

const router = Router();
router.use(authenticate);

router.get(
  '/',
  requirePermission('settings.view'),
  asyncHandler(async (req, res) => {
    const companyId = req.query.companyId ? Number(req.query.companyId) : null;
    const items = await prisma.setting.findMany({
      where: { companyId },
      orderBy: { key: 'asc' },
    });
    res.json({ items });
  }),
);

router.get(
  '/public',
  asyncHandler(async (_req, res) => {
    const items = await prisma.setting.findMany({ where: { isPublic: true } });
    const map = {};
    for (const s of items) map[s.key] = s.value;
    res.json(map);
  }),
);

router.put(
  '/',
  requirePermission('settings.manage_settings'),
  asyncHandler(async (req, res) => {
    const { companyId = null, items = [] } = req.body || {};
    // Phase 4.16 follow-up — was 2N sequential queries (findFirst +
    // update/create per item). Now: single batched lookup of existing
    // rows by key, then update/create each row inside one transaction
    // so they commit atomically and the writes can pipeline.
    const validItems = items.filter((i) => i && i.key);
    if (validItems.length === 0) {
      res.json({ items: [] });
      return;
    }
    const keys = validItems.map((i) => i.key);
    const existing = await prisma.setting.findMany({
      where: { companyId, key: { in: keys } },
    });
    const byKey = new Map(existing.map((e) => [e.key, e]));

    const results = await prisma.$transaction(
      validItems.map((item) => {
        const { key, value, type = 'string', isPublic = false } = item;
        const existingRow = byKey.get(key);
        const data = { value: String(value ?? ''), type, isPublic };
        return existingRow
          ? prisma.setting.update({ where: { id: existingRow.id }, data })
          : prisma.setting.create({ data: { companyId, key, ...data } });
      }),
    );
    await writeAudit({ req, action: 'update', entity: 'Setting', metadata: { count: results.length } });
    res.json({ items: results });
  }),
);

export default router;
