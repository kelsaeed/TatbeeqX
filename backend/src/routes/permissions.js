import { Router } from 'express';
import { prisma } from '../lib/prisma.js';
import { authenticate } from '../middleware/auth.js';
import { requirePermission } from '../middleware/permission.js';
import { asyncHandler } from '../lib/http.js';

const router = Router();

router.use(authenticate);

router.get(
  '/',
  requirePermission('permissions.view'),
  asyncHandler(async (_req, res) => {
    const items = await prisma.permission.findMany({ orderBy: [{ module: 'asc' }, { action: 'asc' }] });
    res.json({ items });
  }),
);

export default router;
