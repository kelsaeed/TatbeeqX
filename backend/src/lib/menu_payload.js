// Phase 4.20 — extracted because /api/menus AND the /auth/me boot
// bundle now both serialize the same menu tree. Keeping the logic in
// one place avoids drift between the two responses.

import { prisma } from './prisma.js';
import { hasPermission } from './permissions.js';

export async function buildMenuPayload(permissions) {
  const [modules, menus] = await Promise.all([
    prisma.module.findMany({ where: { isActive: true }, orderBy: { sortOrder: 'asc' } }),
    prisma.menuItem.findMany({ where: { isActive: true }, orderBy: { sortOrder: 'asc' } }),
  ]);

  const allowed = menus.filter((m) => {
    if (!m.permissionCode) return true;
    return hasPermission(permissions, m.permissionCode);
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

  return {
    modules: modules.map((mo) => ({
      id: mo.id,
      code: mo.code,
      name: mo.name,
      icon: mo.icon,
      sortOrder: mo.sortOrder,
    })),
    tree: build(null),
  };
}
