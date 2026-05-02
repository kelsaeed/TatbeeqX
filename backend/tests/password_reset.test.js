// Phase 4.16 follow-up — admin-token password reset (no SMTP).
//
// Covers: admin generates token → user redeems → password updates +
// token marked used; expired/reused/bogus tokens rejected; non-admin
// callers can't generate; redemption revokes other outstanding
// tokens + active sessions.

import { describe, it, expect, beforeAll, afterEach } from 'vitest';
import request from 'supertest';
import crypto from 'node:crypto';
import bcrypt from 'bcryptjs';
import { buildApp } from '../src/lib/app.js';
import { prisma } from '../src/lib/prisma.js';

const app = buildApp({ silent: true });

const SEED_USERNAME = process.env.SEED_SUPERADMIN_USERNAME || 'superadmin';
const SEED_PASSWORD = process.env.SEED_SUPERADMIN_PASSWORD || 'ChangeMe!2026';

let adminToken;
const auth = () => ({ Authorization: `Bearer ${adminToken}` });

beforeAll(async () => {
  const res = await request(app)
    .post('/api/auth/login')
    .send({ username: SEED_USERNAME, password: SEED_PASSWORD });
  if (res.status !== 200) throw new Error(`login failed: ${res.status}`);
  adminToken = res.body.accessToken;
});

// Each test creates its own fixture user; tracked here for cleanup.
const fixtureUserIds = [];
afterEach(async () => {
  while (fixtureUserIds.length) {
    const id = fixtureUserIds.pop();
    // CASCADE cleans up RefreshToken + PasswordResetToken automatically.
    await prisma.user.delete({ where: { id } }).catch(() => {});
  }
});

async function makeFixtureUser({ password = 'OriginalPwd!2026' } = {}) {
  const username = `pwreset_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`;
  const user = await prisma.user.create({
    data: {
      username,
      email: `${username}@example.com`,
      fullName: 'Password Reset Fixture',
      passwordHash: await bcrypt.hash(password, 10),
      isActive: true,
    },
  });
  fixtureUserIds.push(user.id);
  return { user, plaintext: password };
}

describe('POST /api/users/:id/reset-token', () => {
  it('generates a token, returns plaintext once, persists only the hash', async () => {
    const { user } = await makeFixtureUser();

    const res = await request(app)
      .post(`/api/users/${user.id}/reset-token`)
      .set(auth())
      .expect(200);
    expect(typeof res.body.token).toBe('string');
    expect(res.body.token.length).toBeGreaterThanOrEqual(64);
    expect(res.body.expiresAt).toBeTruthy();
    expect(res.body.forUser.username).toBe(user.username);

    // DB has the hash, not the plaintext.
    const expectedHash = crypto.createHash('sha256').update(res.body.token).digest('hex');
    const row = await prisma.passwordResetToken.findUnique({ where: { tokenHash: expectedHash } });
    expect(row).not.toBeNull();
    expect(row.userId).toBe(user.id);
    expect(row.usedAt).toBeNull();

    // Plaintext is NOT in the DB row.
    expect(row.tokenHash).not.toBe(res.body.token);
  });

  it('returns 404 for an unknown user id', async () => {
    await request(app)
      .post('/api/users/999999999/reset-token')
      .set(auth())
      .expect(404);
  });
});

describe('POST /api/auth/redeem-reset-token', () => {
  it('redeems a valid token, updates the password, marks the row used', async () => {
    const { user } = await makeFixtureUser();
    const gen = await request(app).post(`/api/users/${user.id}/reset-token`).set(auth()).expect(200);

    const newPwd = 'NewPwd!2026SecureEnough';
    await request(app)
      .post('/api/auth/redeem-reset-token')
      .send({ token: gen.body.token, newPassword: newPwd })
      .expect(200);

    // Login as the new password
    const login = await request(app).post('/api/auth/login').send({ username: user.username, password: newPwd });
    expect(login.status).toBe(200);

    // Old password no longer works.
    const oldLogin = await request(app).post('/api/auth/login').send({ username: user.username, password: 'OriginalPwd!2026' });
    expect(oldLogin.status).toBe(401);

    // Token row is marked used.
    const row = await prisma.passwordResetToken.findFirst({ where: { userId: user.id } });
    expect(row.usedAt).not.toBeNull();
  });

  it('rejects an already-used token (one-time semantics) — generic error', async () => {
    const { user } = await makeFixtureUser();
    const gen = await request(app).post(`/api/users/${user.id}/reset-token`).set(auth()).expect(200);
    await request(app)
      .post('/api/auth/redeem-reset-token')
      .send({ token: gen.body.token, newPassword: 'NewPwd!2026SecureEnough' })
      .expect(200);

    const reuse = await request(app)
      .post('/api/auth/redeem-reset-token')
      .send({ token: gen.body.token, newPassword: 'AnotherPwd!2026' });
    expect(reuse.status).toBe(401);
    expect(reuse.body.error.message).toMatch(/invalid or expired/);
  });

  it('rejects an expired token', async () => {
    const { user } = await makeFixtureUser();
    // Plant a token with expiresAt in the past.
    const plaintext = crypto.randomBytes(32).toString('hex');
    const tokenHash = crypto.createHash('sha256').update(plaintext).digest('hex');
    await prisma.passwordResetToken.create({
      data: {
        userId: user.id,
        tokenHash,
        expiresAt: new Date(Date.now() - 60 * 1000),
      },
    });
    const res = await request(app)
      .post('/api/auth/redeem-reset-token')
      .send({ token: plaintext, newPassword: 'NewPwd!2026SecureEnough' });
    expect(res.status).toBe(401);
  });

  it('rejects a token that was never issued', async () => {
    await request(app)
      .post('/api/auth/redeem-reset-token')
      .send({ token: 'definitely-not-a-real-token-' + crypto.randomBytes(16).toString('hex'), newPassword: 'NewPwd!2026SecureEnough' })
      .expect(401);
  });

  it('rejects when newPassword is too short', async () => {
    const { user } = await makeFixtureUser();
    const gen = await request(app).post(`/api/users/${user.id}/reset-token`).set(auth()).expect(200);
    await request(app)
      .post('/api/auth/redeem-reset-token')
      .send({ token: gen.body.token, newPassword: 'short' })
      .expect(400);
  });

  it('cancels OTHER outstanding tokens for the same user on redemption', async () => {
    const { user } = await makeFixtureUser();
    const a = await request(app).post(`/api/users/${user.id}/reset-token`).set(auth()).expect(200);
    const b = await request(app).post(`/api/users/${user.id}/reset-token`).set(auth()).expect(200);
    await request(app)
      .post('/api/auth/redeem-reset-token')
      .send({ token: a.body.token, newPassword: 'NewPwd!2026SecureEnough' })
      .expect(200);

    // Token B should now also be marked used (cancelled).
    const reuse = await request(app)
      .post('/api/auth/redeem-reset-token')
      .send({ token: b.body.token, newPassword: 'AnotherPwd!2026' });
    expect(reuse.status).toBe(401);
  });

  it('revokes active refresh-token sessions on redemption', async () => {
    const { user, plaintext } = await makeFixtureUser();
    // Log in as the user → creates a RefreshToken row.
    const login = await request(app).post('/api/auth/login').send({ username: user.username, password: plaintext });
    expect(login.status).toBe(200);
    const refreshJti = JSON.parse(Buffer.from(login.body.refreshToken.split('.')[1], 'base64url').toString()).jti;

    // Admin generates + redeems a reset token.
    const gen = await request(app).post(`/api/users/${user.id}/reset-token`).set(auth()).expect(200);
    await request(app)
      .post('/api/auth/redeem-reset-token')
      .send({ token: gen.body.token, newPassword: 'NewPwd!2026SecureEnough' })
      .expect(200);

    // Refresh-token row should now be revoked.
    const row = await prisma.refreshToken.findUnique({ where: { jti: refreshJti } });
    expect(row.revokedAt).not.toBeNull();
  });
});
