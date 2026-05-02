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
  requirePermission('login_events.view'),
  asyncHandler(async (req, res) => {
    const { skip, take, page, pageSize } = parsePagination(req.query);
    const where = {};
    if (req.query.userId) where.userId = Number(req.query.userId);
    if (req.query.event) where.event = String(req.query.event);
    if (req.query.success !== undefined && req.query.success !== '') {
      where.success = String(req.query.success) === 'true';
    }
    if (req.query.q) {
      where.OR = [
        { username: { contains: String(req.query.q) } },
        { ipAddress: { contains: String(req.query.q) } },
        { userAgent: { contains: String(req.query.q) } },
      ];
    }

    const [items, total] = await prisma.$transaction([
      prisma.loginEvent.findMany({ where, skip, take, orderBy: { id: 'desc' } }),
      prisma.loginEvent.count({ where }),
    ]);
    res.json({ items, total, page, pageSize });
  }),
);

export default router;
