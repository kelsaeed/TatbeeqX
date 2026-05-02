import { Router } from 'express';
import { prisma } from '../lib/prisma.js';
import { authenticate } from '../middleware/auth.js';
import { requirePermission } from '../middleware/permission.js';
import { asyncHandler, badRequest, notFound } from '../lib/http.js';
import { parseId, parsePagination, pick, requireFields } from '../middleware/validate.js';
import { hashPassword } from '../lib/password.js';
import { writeAudit } from '../lib/audit.js';
import crypto from 'node:crypto';

const router = Router();

const userInclude = {
  company: { select: { id: true, name: true } },
  branch: { select: { id: true, name: true } },
  userRoles: { include: { role: true } },
};

function toDto(u) {
  return {
    id: u.id,
    username: u.username,
    email: u.email,
    fullName: u.fullName,
    phone: u.phone,
    avatarUrl: u.avatarUrl,
    isActive: u.isActive,
    isSuperAdmin: u.isSuperAdmin,
    companyId: u.companyId,
    branchId: u.branchId,
    company: u.company,
    branch: u.branch,
    roles: u.userRoles?.map((ur) => ({ id: ur.role.id, code: ur.role.code, name: ur.role.name })) ?? [],
    lastLoginAt: u.lastLoginAt,
    createdAt: u.createdAt,
    updatedAt: u.updatedAt,
  };
}

router.use(authenticate);

router.get(
  '/',
  requirePermission('users.view'),
  asyncHandler(async (req, res) => {
    const { page, pageSize, skip, take } = parsePagination(req.query);
    const search = (req.query.search || '').toString().trim();
    const where = search
      ? {
          OR: [
            { username: { contains: search } },
            { email: { contains: search } },
            { fullName: { contains: search } },
          ],
        }
      : {};
    const [items, total] = await Promise.all([
      prisma.user.findMany({ where, include: userInclude, skip, take, orderBy: { id: 'desc' } }),
      prisma.user.count({ where }),
    ]);
    res.json({ items: items.map(toDto), total, page, pageSize });
  }),
);

router.get(
  '/:id',
  requirePermission('users.view'),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const user = await prisma.user.findUnique({ where: { id }, include: userInclude });
    if (!user) throw notFound('User not found');
    res.json(toDto(user));
  }),
);

router.post(
  '/',
  requirePermission('users.create'),
  asyncHandler(async (req, res) => {
    requireFields(req.body, ['username', 'email', 'password', 'fullName']);
    const { password, roleIds = [], ...rest } = req.body;
    if (password.length < 8) throw badRequest('Password must be at least 8 characters');
    const data = pick(rest, [
      'username',
      'email',
      'fullName',
      'phone',
      'avatarUrl',
      'isActive',
      'companyId',
      'branchId',
    ]);
    const created = await prisma.user.create({
      data: {
        ...data,
        passwordHash: await hashPassword(password),
        userRoles: { create: roleIds.map((roleId) => ({ roleId })) },
      },
      include: userInclude,
    });
    await writeAudit({ req, action: 'create', entity: 'User', entityId: created.id });
    res.status(201).json(toDto(created));
  }),
);

router.put(
  '/:id',
  requirePermission('users.edit'),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const { password, roleIds, ...rest } = req.body;
    const data = pick(rest, [
      'username',
      'email',
      'fullName',
      'phone',
      'avatarUrl',
      'isActive',
      'companyId',
      'branchId',
    ]);
    if (password) {
      if (password.length < 8) throw badRequest('Password must be at least 8 characters');
      data.passwordHash = await hashPassword(password);
    }
    const updated = await prisma.$transaction(async (tx) => {
      const u = await tx.user.update({ where: { id }, data });
      if (Array.isArray(roleIds)) {
        await tx.userRole.deleteMany({ where: { userId: id } });
        if (roleIds.length) {
          await tx.userRole.createMany({ data: roleIds.map((roleId) => ({ userId: id, roleId })) });
        }
      }
      return tx.user.findUnique({ where: { id: u.id }, include: userInclude });
    });
    await writeAudit({ req, action: 'update', entity: 'User', entityId: id });
    res.json(toDto(updated));
  }),
);

router.delete(
  '/:id',
  requirePermission('users.delete'),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    if (id === req.user.id) throw badRequest('Cannot delete your own account');
    await prisma.user.delete({ where: { id } });
    await writeAudit({ req, action: 'delete', entity: 'User', entityId: id });
    res.json({ ok: true });
  }),
);

// Phase 4.16 follow-up — admin-token password reset (no SMTP). Generates
// a one-time, short-lived token that the admin shares with the user
// out-of-band. The plaintext is returned in the response ONCE; only
// the sha256 hash is persisted, so a DB compromise doesn't leak
// active tokens.
//
// Permission: `users.edit` (matches existing semantic for managing
// users — admin already changes passwords directly via PUT /users/:id).
const RESET_TOKEN_TTL_MS = 24 * 60 * 60 * 1000; // 24h — operators can override per-call later if needed

function hashResetToken(plaintext) {
  return crypto.createHash('sha256').update(plaintext).digest('hex');
}

router.post(
  '/:id/reset-token',
  requirePermission('users.edit'),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const target = await prisma.user.findUnique({ where: { id } });
    if (!target) throw notFound('User not found');

    // 32 bytes → 64 hex chars. Long enough that brute-force is
    // impractical even without rate limiting on the redemption
    // endpoint.
    const plaintext = crypto.randomBytes(32).toString('hex');
    const tokenHash = hashResetToken(plaintext);
    const expiresAt = new Date(Date.now() + RESET_TOKEN_TTL_MS);

    const row = await prisma.passwordResetToken.create({
      data: {
        userId: id,
        tokenHash,
        expiresAt,
        createdBy: req.user.id,
        ip: req.ip || null,
      },
    });

    await writeAudit({
      req,
      action: 'password_reset.generated',
      entity: 'User',
      entityId: id,
      metadata: { tokenId: row.id, expiresAt },
    });

    res.json({
      // Plaintext only returned here — never persisted, never logged.
      token: plaintext,
      expiresAt,
      tokenId: row.id,
      forUser: { id: target.id, username: target.username, fullName: target.fullName },
    });
  }),
);

// Phase 4.16 follow-up — admin-side 2FA reset. Disables 2FA on a
// target user without requiring their TOTP code — the admin scenario
// is "user lost their phone AND all recovery codes." Audit log
// captures the actor.
router.post(
  '/:id/2fa/reset',
  requirePermission('users.edit'),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const target = await prisma.user.findUnique({ where: { id } });
    if (!target) throw notFound('User not found');
    if (!target.totpEnabledAt) {
      // Idempotent — succeeds with a no-op so an admin who clicks
      // twice doesn't hit a confusing 400.
      return res.json({ ok: true, was2FAEnabled: false });
    }
    await prisma.$transaction([
      prisma.user.update({
        where: { id },
        data: { totpSecret: null, totpEnabledAt: null },
      }),
      prisma.recoveryCode.deleteMany({ where: { userId: id } }),
    ]);
    await writeAudit({
      req, action: '2fa.reset_by_admin', entity: 'User', entityId: id,
      metadata: { targetUsername: target.username },
    });
    res.json({ ok: true, was2FAEnabled: true });
  }),
);

export default router;
