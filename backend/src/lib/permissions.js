import { prisma } from './prisma.js';

export async function loadUserPermissions(userId) {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    include: {
      userRoles: {
        include: {
          role: {
            include: {
              rolePermissions: { include: { permission: true } },
            },
          },
        },
      },
      overrides: { include: { permission: true } },
    },
  });

  if (!user) return new Set();
  if (user.isSuperAdmin) return new Set(['*']);

  const set = new Set();
  for (const ur of user.userRoles) {
    for (const rp of ur.role.rolePermissions) {
      set.add(rp.permission.code);
    }
  }
  for (const ov of user.overrides) {
    if (ov.granted) set.add(ov.permission.code);
    else set.delete(ov.permission.code);
  }
  return set;
}

export function hasPermission(perms, code) {
  if (perms.has('*')) return true;
  return perms.has(code);
}

// Phase 4.22 — surface the entities a permission set lets the holder
// approve. Callers use this to filter the approvals list to "things
// I can act on" (the My queue tab on /approvals). Super-admins
// (perms.has('*')) get null back — caller treats that as "no entity
// filter" rather than a list with one entry.
export function approvableEntities(perms) {
  if (!perms || typeof perms.has !== 'function') return new Set();
  if (perms.has('*')) return null;
  const out = new Set();
  for (const code of perms) {
    const m = /^(.+)\.approve$/.exec(code);
    if (m) out.add(m[1]);
  }
  return out;
}
