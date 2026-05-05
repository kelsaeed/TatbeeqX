import { Router } from 'express';
import rateLimit, { ipKeyGenerator } from 'express-rate-limit';
import crypto from 'node:crypto';
import { prisma } from '../lib/prisma.js';
import { verifyPassword, hashPassword } from '../lib/password.js';
import { signAccessToken, signRefreshToken, verifyRefreshToken, refreshTokenExpiry, signChallengeToken, verifyChallengeToken } from '../lib/jwt.js';
import {
  decryptSecret, encryptSecret, generateSecret, generateRecoveryCodes,
  hashRecoveryCode, verifyCode, buildOtpauthUri, buildQrDataUrl,
} from '../lib/totp.js';
import { logSystem } from '../lib/system_log.js';
import { loadUserPermissions } from '../lib/permissions.js';
import { asyncHandler, badRequest, notFound, unauthorized } from '../lib/http.js';
import { parseId } from '../middleware/validate.js';
import { requireFields } from '../middleware/validate.js';
import { authenticate } from '../middleware/auth.js';
// (parseId imported above alongside notFound — same middleware/validate path)
import { writeAudit } from '../lib/audit.js';
import { recordLoginEvent } from '../lib/system_log.js';
import { env } from '../config/env.js';

const router = Router();

// Phase 4.16 follow-up — brute-force defense on /auth/login.
// 10 attempts per IP per 15 minutes. Successful logins don't count
// against the limit (skipSuccessfulRequests). The limiter responds 429
// when tripped — frontend's existing error path surfaces the message.
//
// LAN deployments may want to relax this; override via env if needed.
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: Number(process.env.AUTH_LOGIN_MAX) || 10,
  standardHeaders: true,
  legacyHeaders: false,
  skipSuccessfulRequests: true,
  message: { error: { message: 'Too many login attempts. Try again in a few minutes.' } },
});

// Phase 4.16 follow-up — fixed bcrypt hash used to equalize timing
// when the user lookup miss. Without this, a "user not found" returns
// in ~5ms while "wrong password" takes ~100ms (bcrypt run), letting an
// attacker enumerate valid usernames by timing alone. Always run the
// verify against this dummy when no real hash is available.
const DUMMY_HASH = '$2a$10$abcdefghijklmnopqrstuvwxyzABCDEF.GhIjKlMnOpQrStUvWxYz0';

// Phase 4.16 follow-up — refresh-token rotation helpers.
// Issues a refresh token + records the row, returns just the JWT.
async function issueRefreshToken({ userId, req }) {
  const { token, jti } = signRefreshToken({ sub: userId });
  await prisma.refreshToken.create({
    data: {
      jti,
      userId,
      expiresAt: refreshTokenExpiry(token),
      userAgent: req.get('user-agent') || null,
      ip: req.ip || null,
    },
  });
  return token;
}

// Reuse-detection: when a revoked token presents itself, walk forward
// through the replacedBy chain and revoke EVERY descendant. Then
// nuke any active refresh tokens for the user (the legitimate session
// is already toast — we don't know which one is the attacker).
async function detectAndHandleReuse(revokedRow, req) {
  await logSystem(
    'warn',
    'auth',
    `Refresh token reuse detected for user ${revokedRow.userId} — invalidating all sessions.`,
    { userId: revokedRow.userId, jti: revokedRow.jti, ip: req.ip },
  ).catch(() => {});
  await prisma.refreshToken.updateMany({
    where: { userId: revokedRow.userId, revokedAt: null },
    data: { revokedAt: new Date() },
  });
}

router.post(
  '/login',
  loginLimiter,
  asyncHandler(async (req, res) => {
    requireFields(req.body, ['username', 'password']);
    const { username, password } = req.body;
    if (typeof username !== 'string' || typeof password !== 'string'
        || username.trim().length === 0 || password.length === 0) {
      throw badRequest('username and password must be non-empty strings');
    }

    const user = await prisma.user.findFirst({
      where: { OR: [{ username }, { email: username }] },
      include: { company: true, branch: true },
    });
    // Always run bcrypt — even on a miss — to equalize timing. If user
    // doesn't exist, verify against the dummy hash; the result is
    // ignored, but the wall-clock delay matches the real-user path.
    const verifyOk = await verifyPassword(password, user?.passwordHash ?? DUMMY_HASH);
    if (!user || !user.isActive) {
      await recordLoginEvent({
        username,
        event: 'login',
        success: false,
        reason: !user ? 'unknown_user' : 'inactive_user',
        req,
      });
      throw unauthorized('Invalid credentials');
    }

    if (!verifyOk) {
      await recordLoginEvent({
        userId: user.id,
        username: user.username,
        event: 'login',
        success: false,
        reason: 'bad_password',
        req,
      });
      throw unauthorized('Invalid credentials');
    }

    // Phase 4.16 follow-up — 2FA gate. If the user has TOTP enabled,
    // password-only auth doesn't issue full tokens. We return a
    // short-lived challenge token instead; client trades it + a
    // valid TOTP/recovery code for the real session via
    // /auth/2fa/challenge. lastLoginAt isn't bumped until the
    // challenge succeeds — a partially-completed login shouldn't
    // count.
    if (user.totpEnabledAt) {
      const challengeToken = signChallengeToken({ sub: user.id });
      await recordLoginEvent({
        userId: user.id,
        username: user.username,
        event: 'login',
        success: false,
        reason: '2fa_required',
        req,
      });
      return res.json({ requires2FA: true, challengeToken });
    }

    await prisma.user.update({ where: { id: user.id }, data: { lastLoginAt: new Date() } });

    const accessToken = signAccessToken({ sub: user.id });
    const refreshToken = await issueRefreshToken({ userId: user.id, req });

    // Phase 4.20 — fold the unread-notifications count into the auth
    // payload so the topbar bell can render its badge without a
    // separate boot-time GET. Loaded in parallel with permissions.
    const [permissions, unreadNotifications] = await Promise.all([
      loadUserPermissions(user.id),
      prisma.notification.count({ where: { userId: user.id, readAt: null } }),
    ]);

    await writeAudit({
      req: { ...req, user },
      action: 'login',
      entity: 'User',
      entityId: user.id,
    });
    await recordLoginEvent({
      userId: user.id,
      username: user.username,
      event: 'login',
      success: true,
      req,
    });

    res.json({
      accessToken,
      refreshToken,
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        fullName: user.fullName,
        avatarUrl: user.avatarUrl,
        isSuperAdmin: user.isSuperAdmin,
        company: user.company
          ? { id: user.company.id, name: user.company.name, logoUrl: user.company.logoUrl }
          : null,
        branch: user.branch ? { id: user.branch.id, name: user.branch.name } : null,
      },
      permissions: Array.from(permissions),
      notifications: { unread: unreadNotifications },
    });
  }),
);

router.post(
  '/refresh',
  asyncHandler(async (req, res) => {
    const { refreshToken } = req.body || {};
    if (!refreshToken) throw badRequest('Missing refreshToken');
    let payload;
    try {
      payload = verifyRefreshToken(refreshToken);
    } catch {
      throw unauthorized('Invalid refresh token');
    }
    const jti = typeof payload?.jti === 'string' ? payload.jti : null;
    if (!jti) {
      // Legacy refresh tokens (issued before this rotation feature
      // shipped) lack a jti. Reject — operators just have to log in
      // again once. Cleaner than maintaining two code paths.
      throw unauthorized('Refresh token missing jti — please log in again.');
    }

    const row = await prisma.refreshToken.findUnique({ where: { jti } });
    if (!row) throw unauthorized('Refresh token not recognized');

    // Reuse detection — a previously-rotated token shouldn't appear
    // again. If it does, the chain has been compromised; revoke
    // everything and force the user to re-login.
    if (row.revokedAt) {
      await detectAndHandleReuse(row, req);
      throw unauthorized('Refresh token has been used or revoked. Please log in again.');
    }
    if (row.expiresAt < new Date()) {
      await prisma.refreshToken.update({ where: { id: row.id }, data: { revokedAt: new Date() } });
      throw unauthorized('Refresh token expired');
    }

    const user = await prisma.user.findUnique({ where: { id: row.userId } });
    if (!user || !user.isActive) throw unauthorized('User inactive');

    // Rotate: issue new pair, mark old token revoked + linked.
    const newRefreshToken = await issueRefreshToken({ userId: user.id, req });
    const newRow = await prisma.refreshToken.findUnique({
      where: { jti: verifyRefreshToken(newRefreshToken).jti },
    });
    await prisma.refreshToken.update({
      where: { id: row.id },
      data: { revokedAt: new Date(), replacedById: newRow?.id ?? null },
    });

    await recordLoginEvent({
      userId: user.id,
      username: user.username,
      event: 'refresh',
      success: true,
      req,
    });
    res.json({
      accessToken: signAccessToken({ sub: user.id }),
      refreshToken: newRefreshToken,
    });
  }),
);

router.post(
  '/logout',
  authenticate,
  asyncHandler(async (req, res) => {
    // Phase 4.16 follow-up — if the client passes its current refresh
    // token, revoke that specific row. If `everywhere: true`, revoke
    // every active refresh token for this user (panic-button "log
    // out from all devices"). Either way, the access token is
    // already client-side-only and just gets cleared by the caller.
    const { refreshToken, everywhere } = req.body || {};
    if (everywhere === true) {
      await prisma.refreshToken.updateMany({
        where: { userId: req.user.id, revokedAt: null },
        data: { revokedAt: new Date() },
      });
    } else if (typeof refreshToken === 'string' && refreshToken.length > 0) {
      try {
        const payload = verifyRefreshToken(refreshToken);
        if (payload?.jti && payload?.sub === req.user.id) {
          await prisma.refreshToken.updateMany({
            where: { jti: payload.jti, revokedAt: null },
            data: { revokedAt: new Date() },
          });
        }
      } catch { /* token invalid/expired — ignore, just log out client-side */ }
    }

    await writeAudit({ req, action: 'logout', entity: 'User', entityId: req.user.id, metadata: { everywhere: everywhere === true } });
    await recordLoginEvent({
      userId: req.user.id,
      username: req.user.username,
      event: 'logout',
      success: true,
      req,
    });
    res.json({ ok: true });
  }),
);

router.get(
  '/me',
  authenticate,
  asyncHandler(async (req, res) => {
    // Phase 4.20 — fetch user + unread count in parallel so the bell
    // badge is seeded straight from the bootstrap call. See same
    // payload shape on /auth/login and /auth/2fa/challenge.
    const [user, unreadNotifications] = await Promise.all([
      prisma.user.findUnique({
        where: { id: req.user.id },
        include: { company: true, branch: true },
      }),
      prisma.notification.count({ where: { userId: req.user.id, readAt: null } }),
    ]);
    res.json({
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        fullName: user.fullName,
        avatarUrl: user.avatarUrl,
        isSuperAdmin: user.isSuperAdmin,
        company: user.company
          ? { id: user.company.id, name: user.company.name, logoUrl: user.company.logoUrl }
          : null,
        branch: user.branch ? { id: user.branch.id, name: user.branch.name } : null,
        // Phase 4.16 follow-up — surface 2FA state so the frontend
        // Security page can show "Enable / Disable 2FA" appropriately.
        totpEnabled: !!user.totpEnabledAt,
        totpEnabledAt: user.totpEnabledAt,
      },
      permissions: Array.from(req.permissions),
      notifications: { unread: unreadNotifications },
    });
  }),
);

router.post(
  '/change-password',
  authenticate,
  asyncHandler(async (req, res) => {
    requireFields(req.body, ['currentPassword', 'newPassword']);
    const { currentPassword, newPassword } = req.body;
    if (newPassword.length < 8) throw badRequest('Password must be at least 8 characters');
    const user = await prisma.user.findUnique({ where: { id: req.user.id } });
    const ok = await verifyPassword(currentPassword, user.passwordHash);
    if (!ok) throw unauthorized('Current password incorrect');
    await prisma.user.update({
      where: { id: user.id },
      data: { passwordHash: await hashPassword(newPassword) },
    });
    await writeAudit({ req, action: 'change_password', entity: 'User', entityId: user.id });
    res.json({ ok: true });
  }),
);

// Phase 4.16 follow-up — Sessions UI. Lists the caller's own active
// refresh-token rows (= active devices) with metadata captured at
// issue time (userAgent, ip, issuedAt, expiresAt). Frontend can
// optionally pass `?currentJti=<jti>` so the row matching the
// caller's current refresh token gets `current: true`.
//
// Permission: just `authenticate` — every user can manage their own
// sessions. The `userId` filter in the where clause makes
// cross-tenant access impossible regardless of the caller's role.
router.get(
  '/sessions',
  authenticate,
  asyncHandler(async (req, res) => {
    const currentJti = typeof req.query.currentJti === 'string' ? req.query.currentJti : null;
    const sessions = await prisma.refreshToken.findMany({
      where: {
        userId: req.user.id,
        revokedAt: null,
        expiresAt: { gt: new Date() },
      },
      orderBy: { issuedAt: 'desc' },
      select: {
        id: true,
        jti: true,
        issuedAt: true,
        expiresAt: true,
        userAgent: true,
        ip: true,
      },
    });
    res.json({
      items: sessions.map((s) => ({
        id: s.id,
        issuedAt: s.issuedAt,
        expiresAt: s.expiresAt,
        userAgent: s.userAgent,
        ip: s.ip,
        current: currentJti != null && s.jti === currentJti,
        // jti is the internal identifier — never leak it out.
      })),
    });
  }),
);

// Phase 4.16 follow-up — 2FA / TOTP endpoints.
//
// Enrollment is a two-step opt-in: enroll generates secret + recovery
// codes (returned ONCE), verify-enrollment activates them after the
// user's authenticator confirms it works. Login becomes two-step for
// enrolled users: password → challengeToken → /2fa/challenge with
// code → access+refresh tokens. Disable requires a valid current code
// (proves possession). Admin reset is in routes/users.js.

const TWOFA_RECOVERY_PLACEHOLDER_HASH = crypto.createHash('sha256').update('placeholder').digest('hex');

// Per-user limit: prevents the "many IPs, one user" brute attack
// against TOTP. The challenge token is short-lived but a real attacker
// can mint fresh tokens by re-running the password phase. Falling back
// to IP keeps the limiter effective when the body is missing or the
// token can't be verified (the route handler will reject those anyway).
const challengeLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: Number(process.env.AUTH_2FA_MAX) || 10,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req, res) => {
    try {
      const t = req.body?.challengeToken;
      if (typeof t === 'string' && t.length > 0) {
        const payload = verifyChallengeToken(t);
        if (payload?.sub) return `2fa:user:${payload.sub}`;
      }
    } catch { /* fall through to IP */ }
    // Use the library's helper so IPv6 keys are normalized to a /64
    // prefix; otherwise each /128 address gets its own bucket and a
    // single IPv6 host can trivially exceed the limit.
    return `2fa:ip:${ipKeyGenerator(req, res)}`;
  },
  message: { error: { message: 'Too many 2FA attempts. Try again in a few minutes.' } },
});

router.post(
  '/2fa/challenge',
  challengeLimiter,
  asyncHandler(async (req, res) => {
    const { challengeToken, code, recoveryCode } = req.body || {};
    if (typeof challengeToken !== 'string' || challengeToken.length === 0) {
      throw badRequest('challengeToken is required');
    }
    let payload;
    try {
      payload = verifyChallengeToken(challengeToken);
    } catch {
      throw unauthorized('Invalid or expired challenge token');
    }
    const user = await prisma.user.findUnique({
      where: { id: payload.sub },
      include: { company: true, branch: true },
    });
    if (!user || !user.isActive || !user.totpEnabledAt || !user.totpSecret) {
      throw unauthorized('Invalid or expired challenge token');
    }

    // Equalize timing between the two paths so an observer can't tell
    // whether a recovery code or a TOTP code was attempted.
    let success = false;
    if (typeof recoveryCode === 'string' && recoveryCode.trim().length > 0) {
      const hash = hashRecoveryCode(recoveryCode);
      // Look up the hash + mark used in one transaction. updateMany
      // returns count=1 on hit, 0 on miss/already-used.
      const result = await prisma.recoveryCode.updateMany({
        where: { codeHash: hash, userId: user.id, usedAt: null },
        data: { usedAt: new Date() },
      });
      success = result.count > 0;
      if (success) {
        await writeAudit({
          req: { ...req, user },
          action: '2fa.recovery_code_used',
          entity: 'User',
          entityId: user.id,
        });
      }
    } else if (typeof code === 'string' && code.length > 0) {
      let secret;
      try { secret = decryptSecret(user.totpSecret); } catch { secret = null; }
      success = secret ? verifyCode(secret, code) : false;
    } else {
      // Neither code nor recoveryCode present — still run a no-op
      // hash to keep timing roughly constant.
      crypto.timingSafeEqual(Buffer.from(TWOFA_RECOVERY_PLACEHOLDER_HASH), Buffer.from(TWOFA_RECOVERY_PLACEHOLDER_HASH));
      throw badRequest('code or recoveryCode is required');
    }

    if (!success) {
      await recordLoginEvent({
        userId: user.id, username: user.username,
        event: 'login', success: false, reason: '2fa_invalid', req,
      });
      throw unauthorized('Invalid 2FA code');
    }

    await prisma.user.update({ where: { id: user.id }, data: { lastLoginAt: new Date() } });
    const accessToken = signAccessToken({ sub: user.id });
    const refreshToken = await issueRefreshToken({ userId: user.id, req });
    // Phase 4.20 — same boot-fetch fold as /auth/login.
    const [permissions, unreadNotifications] = await Promise.all([
      loadUserPermissions(user.id),
      prisma.notification.count({ where: { userId: user.id, readAt: null } }),
    ]);
    await writeAudit({ req: { ...req, user }, action: 'login', entity: 'User', entityId: user.id, metadata: { with2FA: true } });
    await recordLoginEvent({ userId: user.id, username: user.username, event: 'login', success: true, req });

    res.json({
      accessToken,
      refreshToken,
      user: {
        id: user.id, username: user.username, email: user.email,
        fullName: user.fullName, avatarUrl: user.avatarUrl, isSuperAdmin: user.isSuperAdmin,
        company: user.company ? { id: user.company.id, name: user.company.name, logoUrl: user.company.logoUrl } : null,
        branch: user.branch ? { id: user.branch.id, name: user.branch.name } : null,
      },
      permissions: Array.from(permissions),
      notifications: { unread: unreadNotifications },
    });
  }),
);

router.post(
  '/2fa/enroll',
  authenticate,
  asyncHandler(async (req, res) => {
    const user = await prisma.user.findUnique({ where: { id: req.user.id } });
    // Re-enrolling overwrites — supports the "I lost my QR" recovery
    // path. Operators wanting to bar this can layer their own gate.
    const base32Secret = generateSecret();
    const otpauthUri = buildOtpauthUri({
      base32Secret,
      accountLabel: user.username,
      issuer: process.env.TOTP_ISSUER || 'TatbeeqX',
    });
    const qrDataUrl = await buildQrDataUrl(otpauthUri);
    const recoveryCodes = generateRecoveryCodes();

    await prisma.$transaction([
      prisma.user.update({
        where: { id: user.id },
        data: {
          totpSecret: encryptSecret(base32Secret),
          totpEnabledAt: null, // not yet — verify-enrollment activates
        },
      }),
      // Wipe any existing recovery codes from a prior incomplete enroll
      prisma.recoveryCode.deleteMany({ where: { userId: user.id } }),
      ...recoveryCodes.map((code) =>
        prisma.recoveryCode.create({
          data: { userId: user.id, codeHash: hashRecoveryCode(code) },
        }),
      ),
    ]);

    await writeAudit({ req, action: '2fa.enroll_started', entity: 'User', entityId: user.id });

    res.json({
      // base32Secret returned so power users can paste into a manual-
      // entry authenticator if QR scanning isn't an option.
      secret: base32Secret,
      otpauthUri,
      qrDataUrl,
      recoveryCodes, // shown ONCE
    });
  }),
);

router.post(
  '/2fa/verify-enrollment',
  authenticate,
  asyncHandler(async (req, res) => {
    const { code } = req.body || {};
    if (typeof code !== 'string') throw badRequest('code is required');
    const user = await prisma.user.findUnique({ where: { id: req.user.id } });
    if (!user.totpSecret) throw badRequest('No enrollment in progress');
    if (user.totpEnabledAt) throw badRequest('2FA is already enabled');

    let secret;
    try { secret = decryptSecret(user.totpSecret); } catch { throw badRequest('Stored secret is corrupted; restart enrollment'); }
    if (!verifyCode(secret, code)) throw unauthorized('Invalid code — try again with a fresh one from your authenticator');

    await prisma.user.update({ where: { id: user.id }, data: { totpEnabledAt: new Date() } });
    await writeAudit({ req, action: '2fa.enabled', entity: 'User', entityId: user.id });
    res.json({ ok: true, enabledAt: new Date() });
  }),
);

router.post(
  '/2fa/disable',
  authenticate,
  asyncHandler(async (req, res) => {
    const { code, recoveryCode } = req.body || {};
    const user = await prisma.user.findUnique({ where: { id: req.user.id } });
    if (!user.totpEnabledAt) throw badRequest('2FA is not enabled');

    let success = false;
    if (typeof recoveryCode === 'string' && recoveryCode.trim().length > 0) {
      const hash = hashRecoveryCode(recoveryCode);
      const result = await prisma.recoveryCode.updateMany({
        where: { codeHash: hash, userId: user.id, usedAt: null },
        data: { usedAt: new Date() },
      });
      success = result.count > 0;
    } else if (typeof code === 'string' && code.length > 0 && user.totpSecret) {
      try {
        const secret = decryptSecret(user.totpSecret);
        success = verifyCode(secret, code);
      } catch { /* leave success false */ }
    }
    if (!success) throw unauthorized('Invalid code — disable requires a valid TOTP or recovery code to prove possession');

    await prisma.$transaction([
      prisma.user.update({
        where: { id: user.id },
        data: { totpSecret: null, totpEnabledAt: null },
      }),
      prisma.recoveryCode.deleteMany({ where: { userId: user.id } }),
    ]);
    await writeAudit({ req, action: '2fa.disabled', entity: 'User', entityId: user.id });
    res.json({ ok: true });
  }),
);

// Phase 4.16 follow-up — admin-token password reset redemption.
// Public endpoint (the user redeeming may not be logged in). Rate
// limited per IP to mitigate brute-force, though the 32-byte token
// space already makes guessing infeasible.
const resetRedeemLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: Number(process.env.AUTH_RESET_REDEEM_MAX) || 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: { message: 'Too many redemption attempts. Try again in a few minutes.' } },
});

router.post(
  '/redeem-reset-token',
  resetRedeemLimiter,
  asyncHandler(async (req, res) => {
    const { token, newPassword } = req.body || {};
    if (typeof token !== 'string' || token.trim().length === 0) {
      throw badRequest('token is required');
    }
    if (typeof newPassword !== 'string' || newPassword.length < 8) {
      throw badRequest('newPassword must be at least 8 characters');
    }

    const tokenHash = crypto.createHash('sha256').update(token).digest('hex');
    const row = await prisma.passwordResetToken.findUnique({
      where: { tokenHash },
      include: { user: true },
    });
    if (!row) {
      // Generic message — don't leak whether the token ever existed.
      throw unauthorized('Token is invalid or expired');
    }
    if (row.usedAt) {
      // Re-use of a one-time token is a theft signal. Audit it but
      // return the same generic error so attackers can't tell apart
      // "wrong token" vs "already-used token".
      await logSystem(
        'warn', 'auth',
        `Already-used password-reset token presented for user ${row.userId}`,
        { tokenId: row.id, userId: row.userId, ip: req.ip },
      ).catch(() => {});
      throw unauthorized('Token is invalid or expired');
    }
    if (row.expiresAt < new Date()) {
      throw unauthorized('Token is invalid or expired');
    }
    if (!row.user || !row.user.isActive) {
      throw unauthorized('Token is invalid or expired');
    }

    // Atomic-ish: mark used, swap password. If the password update
    // races with another redemption, the second `usedAt` write will
    // see a non-null usedAt and we'll have already used the token —
    // not catastrophic, but a transaction makes intent clear.
    await prisma.$transaction([
      prisma.user.update({
        where: { id: row.userId },
        data: { passwordHash: await hashPassword(newPassword) },
      }),
      prisma.passwordResetToken.update({
        where: { id: row.id },
        data: { usedAt: new Date() },
      }),
      // Cancel any OTHER outstanding tokens for this user — operators
      // shouldn't expect to redeem two reset links in a row.
      prisma.passwordResetToken.updateMany({
        where: { userId: row.userId, usedAt: null, id: { not: row.id } },
        data: { usedAt: new Date() },
      }),
      // Revoke active sessions — a password reset implies the user
      // (or someone the admin handed the token to) wants a clean
      // slate. Forces re-login everywhere.
      prisma.refreshToken.updateMany({
        where: { userId: row.userId, revokedAt: null },
        data: { revokedAt: new Date() },
      }),
    ]);

    await writeAudit({
      // No req.user here — redemption is unauthenticated. Synthesize
      // an entry attributing the action to the target user.
      req: { ...req, user: { id: row.userId, username: row.user.username, isSuperAdmin: false } },
      action: 'password_reset.used',
      entity: 'User',
      entityId: row.userId,
      metadata: { tokenId: row.id, ip: req.ip },
    });

    res.json({ ok: true });
  }),
);

// Phase 4.19 — self-serve forgot-password. Public endpoint that emails
// a single-use, short-TTL reset link. Rate-limited per IP. Always
// returns 200 with a generic message, regardless of whether the
// account exists, so an attacker can't enumerate registered emails or
// usernames. SMTP must be configured — without it the endpoint
// returns 503 so the operator knows to wire it up.
const forgotPasswordLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: Number(process.env.AUTH_FORGOT_PASSWORD_MAX) || 5,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: { message: 'Too many requests. Try again in a few minutes.' } },
});

router.post(
  '/forgot-password',
  forgotPasswordLimiter,
  asyncHandler(async (req, res) => {
    const { isConfigured, sendEmail, wrapEmail } = await import('../lib/email.js');
    if (!isConfigured()) {
      // Distinct status so the frontend can surface "ask your admin to
      // wire up SMTP" instead of a generic error.
      return res.status(503).json({
        error: { message: 'Email is not configured on this server. Ask an admin to reset your password manually.' },
      });
    }

    const identifier = (req.body?.identifier ?? req.body?.username ?? req.body?.email ?? '').toString().trim();
    // Always succeed at the API surface — the actual lookup happens
    // below, and any miss gets the same response. The 200 below is
    // unconditional even when SMTP errored, to keep enumeration off
    // the table.
    //
    // Anti-enumeration timing: pad every response to a fixed minimum
    // floor so an observer can't distinguish "user exists" from "user
    // missing" by latency. The DB writes + audit on the real-user path
    // run faster than the floor; the empty-identifier and missing-user
    // paths are essentially instant. Without the floor, the *missing*
    // path was paradoxically the slowest (80 ms sleep) — the opposite
    // of what we want.
    const startedAt = Date.now();
    const minLatencyMs = Number(process.env.AUTH_FORGOT_PASSWORD_MIN_MS) || 200;
    const ack = async () => {
      const elapsed = Date.now() - startedAt;
      if (elapsed < minLatencyMs) await new Promise((r) => setTimeout(r, minLatencyMs - elapsed));
      return res.json({
        ok: true,
        message: 'If that account exists and has email configured, a reset link has been sent.',
      });
    };

    if (!identifier) return ack();

    const user = await prisma.user.findFirst({
      where: {
        isActive: true,
        OR: [{ username: identifier }, { email: identifier }],
      },
    });
    if (!user || !user.email) return ack();

    const token = crypto.randomBytes(32).toString('hex');
    const tokenHash = crypto.createHash('sha256').update(token).digest('hex');
    const ttlMs = Number(process.env.AUTH_FORGOT_PASSWORD_TTL_MS) || 60 * 60 * 1000;  // 1h default

    await prisma.passwordResetToken.create({
      data: {
        userId: user.id,
        tokenHash,
        expiresAt: new Date(Date.now() + ttlMs),
        createdBy: null,  // self-serve, no admin actor
        ip: req.ip || null,
      },
    });

    const url = `${env.appUrl.replace(/\/+$/, '')}/reset-password?token=${encodeURIComponent(token)}`;
    const subject = 'Reset your TatbeeqX password';
    const text =
      `Hi ${user.fullName || user.username},\n\n` +
      `A password reset was requested for your account.\n\n` +
      `Click this link to set a new password (valid for ${Math.round(ttlMs / 60000)} minutes):\n${url}\n\n` +
      `If you didn't request this, you can ignore this email — no changes will be made.`;
    const html = wrapEmail({
      heading: 'Reset your password',
      bodyHtml: `<p>Hi ${user.fullName || user.username},</p><p>A password reset was requested for your account. Click the button below to set a new password — the link is valid for <strong>${Math.round(ttlMs / 60000)} minutes</strong> and can only be used once.</p><p style="color:#64748b;font-size:13px;">If you didn't request this, you can ignore this email — no changes will be made.</p>`,
      ctaUrl: url,
      ctaLabel: 'Reset password',
    });

    // Fire-and-forget the actual send so timing doesn't depend on
    // SMTP latency. Failures land in SystemLog via sendEmail itself.
    sendEmail({ to: user.email, subject, text, html }).catch(() => {});

    await writeAudit({
      req: { ...req, user: { id: user.id, username: user.username, isSuperAdmin: false } },
      action: 'password_reset.requested',
      entity: 'User',
      entityId: user.id,
      metadata: { method: 'self-serve', ip: req.ip },
    });

    return ack();
  }),
);

router.delete(
  '/sessions/:id',
  authenticate,
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    // updateMany with a userId filter — guarantees a user can only
    // revoke their own sessions even if they guess another row's id.
    const result = await prisma.refreshToken.updateMany({
      where: { id, userId: req.user.id, revokedAt: null },
      data: { revokedAt: new Date() },
    });
    if (result.count === 0) throw notFound('Session not found or already revoked');
    await writeAudit({ req, action: 'revoke_session', entity: 'RefreshToken', entityId: id });
    res.json({ ok: true });
  }),
);

export default router;
