import { Router } from 'express';
import { prisma } from '../lib/prisma.js';
import { authenticate } from '../middleware/auth.js';
import { requirePermission } from '../middleware/permission.js';
import { asyncHandler } from '../lib/http.js';
import { parsePagination } from '../middleware/validate.js';

const router = Router();
router.use(authenticate);

router.get(
  '/',
  requirePermission('audit.view'),
  asyncHandler(async (req, res) => {
    const { page, pageSize, skip, take } = parsePagination(req.query);
    const { entity, action, userId } = req.query;
    const where = {};
    if (entity) where.entity = String(entity);
    if (action) where.action = String(action);
    if (userId) where.userId = Number(userId);

    const [items, total] = await Promise.all([
      prisma.auditLog.findMany({
        where,
        include: { user: { select: { id: true, username: true, fullName: true } } },
        orderBy: { id: 'desc' },
        skip,
        take,
      }),
      prisma.auditLog.count({ where }),
    ]);
    res.json({ items, total, page, pageSize });
  }),
);

// Phase 4.16 follow-up — per-record audit history. Returns the audit
// trail for a specific (entity, entityId) so the record-edit dialog
// can show "who changed what when" on this row.
//
// Permission: `audit.view` (same as the global audit page). Looser
// scoping (e.g. "if you can view the entity") is a nicer-to-have but
// requires looking up the permission prefix per entity name; v2 if
// operators ask.
router.get(
  '/by-record/:entity/:entityId',
  requirePermission('audit.view'),
  asyncHandler(async (req, res) => {
    const entity = String(req.params.entity);
    const entityId = Number(req.params.entityId);
    if (!Number.isFinite(entityId) || entityId <= 0) {
      return res.json({ items: [], total: 0 });
    }
    const { page, pageSize, skip, take } = parsePagination(req.query);
    const where = { entity, entityId };
    const [items, total] = await Promise.all([
      prisma.auditLog.findMany({
        where,
        include: { user: { select: { id: true, username: true, fullName: true } } },
        orderBy: { id: 'desc' },
        skip,
        take,
      }),
      prisma.auditLog.count({ where }),
    ]);
    res.json({ items, total, page, pageSize });
  }),
);

export default router;
