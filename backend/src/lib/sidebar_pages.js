// Phase 4.20 — shared sidebar-pages query.
//
// Used by:
//   - GET /api/pages/sidebar — direct call (still works for any code that
//     hasn't been migrated to the bundled auth payload).
//   - GET /api/auth/me, /auth/login, /auth/2fa/challenge — the bundled
//     boot path that lets the dashboard shell skip the dedicated GET.
//
// Filters: only active pages with showInSidebar=true. Per-page
// permissionCode is enforced here (super admins bypass).

import { prisma } from './prisma.js';
import { hasPermission } from './permissions.js';
import { parsePage } from './page_parse.js';

export async function loadSidebarPages(user, permissions) {
  const pages = await prisma.page.findMany({
    where: { isActive: true, showInSidebar: true },
    orderBy: [{ sortOrder: 'asc' }, { id: 'asc' }],
  });
  const visible = pages.filter((p) => {
    if (user?.isSuperAdmin) return true;
    if (!p.permissionCode) return true;
    return hasPermission(permissions, p.permissionCode);
  });
  return visible.map(parsePage);
}
