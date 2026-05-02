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
