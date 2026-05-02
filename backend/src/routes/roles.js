import { Router } from 'express';
import { prisma } from '../lib/prisma.js';
import { authenticate } from '../middleware/auth.js';
import { requirePermission } from '../middleware/permission.js';
import { asyncHandler, badRequest, forbidden, notFound } from '../lib/http.js';
import { parseId, pick, requireFields } from '../middleware/validate.js';
import { writeAudit } from '../lib/audit.js';

const router = Router();

function toDto(r) {
  let labels = {};
  try { labels = r.labels ? JSON.parse(r.labels) : {}; } catch { labels = {}; }
  return {
    id: r.id,
    code: r.code,
    name: r.name,
    labels,
    description: r.description,
    isSystem: r.isSystem,
    permissionIds: r.rolePermissions?.map((rp) => rp.permissionId) ?? [],
    permissions: r.rolePermissions?.map((rp) => rp.permission.code) ?? [],
    userCount: r._count?.userRoles,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
  };
}

router.use(authenticate);

router.get(
  '/',
  requirePermission('roles.view'),
  asyncHandler(async (_req, res) => {
    const roles = await prisma.role.findMany({
      include: {
        rolePermissions: { include: { permission: true } },
        _count: { select: { userRoles: true } },
      },
      orderBy: { id: 'asc' },
    });
    res.json({ items: roles.map(toDto) });
  }),
);

router.get(
  '/:id',
  requirePermission('roles.view'),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const role = await prisma.role.findUnique({
      where: { id },
      include: {
        rolePermissions: { include: { permission: true } },
        _count: { select: { userRoles: true } },
      },
    });
    if (!role) throw notFound('Role not found');
    res.json(toDto(role));
  }),
);

router.post(
  '/',
  requirePermission('roles.create'),
  asyncHandler(async (req, res) => {
    requireFields(req.body, ['code', 'name']);
    const { permissionIds = [], ...rest } = req.body;
    const data = pick(rest, ['code', 'name', 'description']);
    const role = await prisma.role.create({
      data: {
        ...data,
        rolePermissions: { create: permissionIds.map((permissionId) => ({ permissionId })) },
      },
      include: {
        rolePermissions: { include: { permission: true } },
        _count: { select: { userRoles: true } },
      },
    });
    await writeAudit({ req, action: 'create', entity: 'Role', entityId: role.id });
    res.status(201).json(toDto(role));
  }),
);

router.put(
  '/:id',
  requirePermission('roles.edit'),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const existing = await prisma.role.findUnique({ where: { id } });
    if (!existing) throw notFound('Role not found');
    const { permissionIds, ...rest } = req.body;
    const data = pick(rest, ['name', 'description']);
    if (existing.isSystem && rest.code && rest.code !== existing.code) {
      throw forbidden('Cannot change code of a system role');
    }
    if (!existing.isSystem && rest.code) data.code = rest.code;

    const updated = await prisma.$transaction(async (tx) => {
      const r = await tx.role.update({ where: { id }, data });
      if (Array.isArray(permissionIds)) {
        await tx.rolePermission.deleteMany({ where: { roleId: id } });
        if (permissionIds.length) {
          await tx.rolePermission.createMany({
            data: permissionIds.map((permissionId) => ({ roleId: id, permissionId })),
          });
        }
      }
      return tx.role.findUnique({
        where: { id: r.id },
        include: {
          rolePermissions: { include: { permission: true } },
          _count: { select: { userRoles: true } },
        },
      });
    });
    await writeAudit({ req, action: 'update', entity: 'Role', entityId: id });
    res.json(toDto(updated));
  }),
);

const PRESET_ACTIONS = {
  none: [],
  view: ['view'],
  view_edit: ['view', 'create', 'edit'],
  view_edit_delete: ['view', 'create', 'edit', 'delete'],
  full: ['view', 'create', 'edit', 'delete', 'approve', 'export', 'print', 'manage_settings', 'manage_users', 'manage_roles'],
};

router.post(
  '/:id/presets',
  requirePermission('roles.manage_roles'),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const role = await prisma.role.findUnique({ where: { id } });
    if (!role) throw notFound('Role not found');
    if (role.code === 'super_admin') throw forbidden('Super Admin permissions are computed and cannot be edited');

    const presets = Array.isArray(req.body.presets) ? req.body.presets : [];
    const replace = req.body.replace !== false;
    if (!presets.length) throw badRequest('No presets provided');

    const allModules = [...new Set(presets.map((p) => p.module))];
    const allActions = [...new Set(presets.flatMap((p) => PRESET_ACTIONS[p.level] ?? []))];
    const candidates = await prisma.permission.findMany({
      where: { module: { in: allModules }, action: { in: allActions } },
    });
    const byKey = new Map(candidates.map((p) => [`${p.module}.${p.action}`, p.id]));

    const newPermissionIds = new Set();
    for (const item of presets) {
      const actions = PRESET_ACTIONS[item.level] ?? null;
      if (!actions) throw badRequest(`Invalid level: ${item.level}`);
      for (const action of actions) {
        const id = byKey.get(`${item.module}.${action}`);
        if (id) newPermissionIds.add(id);
      }
    }

    await prisma.$transaction(async (tx) => {
      if (replace) {
        const modules = [...new Set(presets.map((p) => p.module))];
        const modulePerms = await tx.permission.findMany({ where: { module: { in: modules } } });
        await tx.rolePermission.deleteMany({
          where: { roleId: id, permissionId: { in: modulePerms.map((p) => p.id) } },
        });
      }
      if (newPermissionIds.size) {
        await tx.rolePermission.createMany({
          data: [...newPermissionIds].map((permissionId) => ({ roleId: id, permissionId })),
          skipDuplicates: true,
        });
      }
    });

    await writeAudit({ req, action: 'apply_preset', entity: 'Role', entityId: id, metadata: { presets } });
    const fresh = await prisma.role.findUnique({
      where: { id },
      include: {
        rolePermissions: { include: { permission: true } },
        _count: { select: { userRoles: true } },
      },
    });
    res.json(toDto(fresh));
  }),
);

router.delete(
  '/:id',
  requirePermission('roles.delete'),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const role = await prisma.role.findUnique({ where: { id } });
    if (!role) throw notFound('Role not found');
    if (role.isSystem) throw forbidden('Cannot delete a system role');
    const used = await prisma.userRole.count({ where: { roleId: id } });
    if (used) throw badRequest('Role is assigned to users');
    await prisma.role.delete({ where: { id } });
    await writeAudit({ req, action: 'delete', entity: 'Role', entityId: id });
    res.json({ ok: true });
  }),
);

export default router;
