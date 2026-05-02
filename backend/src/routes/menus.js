import { Router } from 'express';
import { prisma } from '../lib/prisma.js';
import { authenticate } from '../middleware/auth.js';
import { hasPermission } from '../lib/permissions.js';
import { asyncHandler } from '../lib/http.js';

const router = Router();

router.get(
  '/',
  authenticate,
  asyncHandler(async (req, res) => {
    const [modules, menus] = await Promise.all([
      prisma.module.findMany({ where: { isActive: true }, orderBy: { sortOrder: 'asc' } }),
      prisma.menuItem.findMany({ where: { isActive: true }, orderBy: { sortOrder: 'asc' } }),
    ]);

    const allowed = menus.filter((m) => {
      if (!m.permissionCode) return true;
      return hasPermission(req.permissions, m.permissionCode);
    });

    const byParent = new Map();
    for (const m of allowed) {
      const key = m.parentId ?? 0;
      if (!byParent.has(key)) byParent.set(key, []);
      byParent.get(key).push(m);
    }
    const build = (parentId) =>
      (byParent.get(parentId ?? 0) || []).map((m) => {
        let labels = {};
        try { labels = m.labels ? JSON.parse(m.labels) : {}; } catch { labels = {}; }
        return {
          id: m.id,
          code: m.code,
          label: m.label,
          labels,
          icon: m.icon,
          route: m.route,
          moduleId: m.moduleId,
          children: build(m.id),
        };
      });

    res.json({
      modules: modules.map((mo) => ({
        id: mo.id,
        code: mo.code,
        name: mo.name,
        icon: mo.icon,
        sortOrder: mo.sortOrder,
      })),
      tree: build(null),
    });
  }),
);

export default router;
