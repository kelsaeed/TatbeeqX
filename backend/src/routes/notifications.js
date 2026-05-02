// Phase 4.18 — in-app notifications.
//
// Each authenticated user manages their own. There is no admin
// "see everyone's" view — sessions UI sets the precedent that
// per-account state stays per-account.

import { Router } from 'express';
import { prisma } from '../lib/prisma.js';
import { authenticate } from '../middleware/auth.js';
import { asyncHandler, notFound, forbidden } from '../lib/http.js';
import { parseId, parsePagination } from '../middleware/validate.js';

const router = Router();
router.use(authenticate);

function toDto(n) {
  return {
    id: n.id,
    kind: n.kind,
    title: n.title,
    body: n.body,
    link: n.link,
    readAt: n.readAt,
    createdAt: n.createdAt,
  };
}

router.get(
  '/',
  asyncHandler(async (req, res) => {
    const { skip, take, page, pageSize } = parsePagination(req.query);
    const onlyUnread = String(req.query.unread || '').toLowerCase() === 'true';
    const where = { userId: req.user.id, ...(onlyUnread ? { readAt: null } : {}) };
    const [items, total] = await prisma.$transaction([
      prisma.notification.findMany({
        where,
        orderBy: [{ readAt: 'asc' }, { id: 'desc' }],  // unread first, then newest
        skip,
        take,
      }),
      prisma.notification.count({ where }),
    ]);
    res.json({ items: items.map(toDto), total, page, pageSize });
  }),
);

router.get(
  '/unread-count',
  asyncHandler(async (req, res) => {
    // Cheap query for the topbar badge — uses the (userId, readAt) index.
    const count = await prisma.notification.count({
      where: { userId: req.user.id, readAt: null },
    });
    res.json({ count });
  }),
);

async function loadOwn(req) {
  const id = parseId(req.params.id);
  const n = await prisma.notification.findUnique({ where: { id } });
  if (!n) throw notFound('Notification not found');
  if (n.userId !== req.user.id) throw forbidden('Not your notification');
  return n;
}

router.post(
  '/:id/read',
  asyncHandler(async (req, res) => {
    const n = await loadOwn(req);
    if (n.readAt) return res.json(toDto(n));  // already read; no-op
    const updated = await prisma.notification.update({
      where: { id: n.id },
      data: { readAt: new Date() },
    });
    res.json(toDto(updated));
  }),
);

router.post(
  '/read-all',
  asyncHandler(async (req, res) => {
    const result = await prisma.notification.updateMany({
      where: { userId: req.user.id, readAt: null },
      data: { readAt: new Date() },
    });
    res.json({ marked: result.count });
  }),
);

router.delete(
  '/:id',
  asyncHandler(async (req, res) => {
    const n = await loadOwn(req);
    await prisma.notification.delete({ where: { id: n.id } });
    res.json({ ok: true });
  }),
);

router.delete(
  '/',
  asyncHandler(async (req, res) => {
    // Bulk dismiss — lets the user clear their tray. Limited to read
    // notifications by default; pass `?all=true` to nuke unread too.
    const wipeAll = String(req.query.all || '').toLowerCase() === 'true';
    const where = wipeAll
      ? { userId: req.user.id }
      : { userId: req.user.id, readAt: { not: null } };
    const result = await prisma.notification.deleteMany({ where });
    res.json({ deleted: result.count });
  }),
);

export default router;
