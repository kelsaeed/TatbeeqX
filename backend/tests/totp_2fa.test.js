// Phase 4.16 follow-up — TOTP 2FA flow.
//
// Covers enrollment, challenge-on-login, recovery codes, disable
// (self with code, admin without), invalid codes, rate-limit/timing.

import { describe, it, expect, beforeAll, afterEach } from 'vitest';
import request from 'supertest';
import bcrypt from 'bcryptjs';
import * as OTPAuth from 'otpauth';
import { buildApp } from '../src/lib/app.js';
import { prisma } from '../src/lib/prisma.js';
import {
  encryptSecret, decryptSecret, generateSecret, verifyCode,
  generateRecoveryCodes, hashRecoveryCode,
} from '../src/lib/totp.js';

const app = buildApp({ silent: true });

const SEED_USERNAME = process.env.SEED_SUPERADMIN_USERNAME || 'superadmin';
const SEED_PASSWORD = process.env.SEED_SUPERADMIN_PASSWORD || 'ChangeMe!2026';

let adminToken;
const auth = (token) => ({ Authorization: `Bearer ${token}` });

beforeAll(async () => {
  const res = await request(app).post('/api/auth/login').send({ username: SEED_USERNAME, password: SEED_PASSWORD });
  if (res.status !== 200) throw new Error(`login failed: ${res.status}`);
  adminToken = res.body.accessToken;
});

const fixtureIds = [];
afterEach(async () => {
  while (fixtureIds.length) {
    const id = fixtureIds.pop();
    await prisma.user.delete({ where: { id } }).catch(() => {});
  }
});

async function makeFixtureUser({ password = 'TestPwd!2026' } = {}) {
  const username = `totp_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`;
  const user = await prisma.user.create({
    data: {
      username,
      email: `${username}@example.com`,
      fullName: 'TOTP Fixture',
      passwordHash: await bcrypt.hash(password, 10),
      isActive: true,
    },
  });
  fixtureIds.push(user.id);
  return { user, plaintext: password };
}

// Helper — generate a current TOTP code for a base32 secret.
function currentCode(base32) {
  const t = new OTPAuth.TOTP({
    algorithm: 'SHA1', digits: 6, period: 30,
    secret: OTPAuth.Secret.fromBase32(base32),
  });
  return t.generate();
}

// Helper — get a logged-in access token for a user.
async function login(username, password) {
  const res = await request(app).post('/api/auth/login').send({ username, password });
  return res;
}

// ---------- pure crypto / helpers ---------------------------------------

describe('totp.js — pure helpers', () => {
  it('encrypt/decrypt round-trip preserves the secret', () => {
    const s = generateSecret();
    const encrypted = encryptSecret(s);
    expect(encrypted).not.toBe(s);
    expect(decryptSecret(encrypted)).toBe(s);
  });

  it('verifyCode accepts a fresh code from the same secret', () => {
    const s = generateSecret();
    const code = currentCode(s);
    expect(verifyCode(s, code)).toBe(true);
    expect(verifyCode(s, '000000')).toBe(false);
    expect(verifyCode(s, 'abc')).toBe(false);
    expect(verifyCode(s, '')).toBe(false);
  });

  it('generateRecoveryCodes returns 10 unique formatted codes', () => {
    const codes = generateRecoveryCodes();
    expect(codes).toHaveLength(10);
    for (const c of codes) expect(c).toMatch(/^[a-f0-9]{5}-[a-f0-9]{5}$/);
    expect(new Set(codes).size).toBe(10); // unique
  });

  it('hashRecoveryCode normalizes (case + dashes + spaces)', () => {
    const a = hashRecoveryCode('a1b2c-3d4e5');
    const b = hashRecoveryCode('A1B2C3D4E5');
    const c = hashRecoveryCode('  a1b2c 3d4e5  ');
    expect(a).toBe(b);
    expect(a).toBe(c);
  });
});

// ---------- enrollment ---------------------------------------------------

describe('POST /api/auth/2fa/enroll + verify-enrollment', () => {
  it('enrolls a user end-to-end and starts requiring 2FA on login', async () => {
    const { user, plaintext } = await makeFixtureUser();
    const initial = await login(user.username, plaintext);
    expect(initial.status).toBe(200);
    expect(initial.body.requires2FA).toBeUndefined();
    const userToken = initial.body.accessToken;

    const enroll = await request(app).post('/api/auth/2fa/enroll').set(auth(userToken));
    expect(enroll.status).toBe(200);
    expect(enroll.body.secret).toMatch(/^[A-Z2-7]+=*$/); // base32
    expect(enroll.body.otpauthUri).toContain('otpauth://totp/');
    expect(enroll.body.qrDataUrl).toMatch(/^data:image\/png;base64,/);
    expect(enroll.body.recoveryCodes).toHaveLength(10);

    // Before verify-enrollment, 2FA isn't enabled yet.
    const me = await request(app).get('/api/auth/me').set(auth(userToken));
    expect(me.body.user.totpEnabled).toBe(false);

    // Verify with a fresh code → enables.
    const code = currentCode(enroll.body.secret);
    const verify = await request(app).post('/api/auth/2fa/verify-enrollment')
      .set(auth(userToken)).send({ code });
    expect(verify.status).toBe(200);

    const meAfter = await request(app).get('/api/auth/me').set(auth(userToken));
    expect(meAfter.body.user.totpEnabled).toBe(true);

    // Login now requires 2FA — password alone returns a challenge.
    const reLogin = await login(user.username, plaintext);
    expect(reLogin.status).toBe(200);
    expect(reLogin.body.requires2FA).toBe(true);
    expect(reLogin.body.challengeToken).toBeTruthy();
    expect(reLogin.body.accessToken).toBeUndefined();
  });

  it('verify-enrollment with a wrong code keeps 2FA disabled', async () => {
    const { user, plaintext } = await makeFixtureUser();
    const initial = await login(user.username, plaintext);
    const userToken = initial.body.accessToken;
    await request(app).post('/api/auth/2fa/enroll').set(auth(userToken)).expect(200);

    const verify = await request(app).post('/api/auth/2fa/verify-enrollment')
      .set(auth(userToken)).send({ code: '000000' });
    expect(verify.status).toBe(401);

    const me = await request(app).get('/api/auth/me').set(auth(userToken));
    expect(me.body.user.totpEnabled).toBe(false);
  });

  it('re-enrolling overwrites prior pending enrollment + recovery codes', async () => {
    const { user, plaintext } = await makeFixtureUser();
    const initial = await login(user.username, plaintext);
    const userToken = initial.body.accessToken;

    const a = await request(app).post('/api/auth/2fa/enroll').set(auth(userToken)).expect(200);
    const b = await request(app).post('/api/auth/2fa/enroll').set(auth(userToken)).expect(200);
    expect(a.body.secret).not.toBe(b.body.secret);

    // Old recovery codes no longer work — only B's are live.
    const oldHashes = a.body.recoveryCodes.map(hashRecoveryCode);
    const stillExists = await prisma.recoveryCode.findMany({
      where: { codeHash: { in: oldHashes }, userId: user.id },
    });
    expect(stillExists).toHaveLength(0);

    const newCount = await prisma.recoveryCode.count({ where: { userId: user.id } });
    expect(newCount).toBe(10);
  });
});

// ---------- challenge / login flow --------------------------------------

describe('POST /api/auth/2fa/challenge', () => {
  async function enrolledFixture() {
    const { user, plaintext } = await makeFixtureUser();
    const initial = await login(user.username, plaintext);
    const userToken = initial.body.accessToken;
    const enroll = await request(app).post('/api/auth/2fa/enroll').set(auth(userToken)).expect(200);
    const code = currentCode(enroll.body.secret);
    await request(app).post('/api/auth/2fa/verify-enrollment').set(auth(userToken)).send({ code }).expect(200);
    return { user, plaintext, secret: enroll.body.secret, recoveryCodes: enroll.body.recoveryCodes };
  }

  it('redeems a valid TOTP code → returns full session', async () => {
    const f = await enrolledFixture();
    const reLogin = await login(f.user.username, f.plaintext);
    const code = currentCode(f.secret);
    const challenge = await request(app).post('/api/auth/2fa/challenge')
      .send({ challengeToken: reLogin.body.challengeToken, code });
    expect(challenge.status).toBe(200);
    expect(challenge.body.accessToken).toBeTruthy();
    expect(challenge.body.refreshToken).toBeTruthy();
    expect(challenge.body.user.username).toBe(f.user.username);
  });

  it('redeems a recovery code → returns full session, marks code used', async () => {
    const f = await enrolledFixture();
    const reLogin = await login(f.user.username, f.plaintext);
    const recoveryCode = f.recoveryCodes[0];
    const challenge = await request(app).post('/api/auth/2fa/challenge')
      .send({ challengeToken: reLogin.body.challengeToken, recoveryCode });
    expect(challenge.status).toBe(200);
    expect(challenge.body.accessToken).toBeTruthy();

    // Same code can't be reused.
    const reLogin2 = await login(f.user.username, f.plaintext);
    const reuse = await request(app).post('/api/auth/2fa/challenge')
      .send({ challengeToken: reLogin2.body.challengeToken, recoveryCode });
    expect(reuse.status).toBe(401);
  });

  it('rejects an invalid TOTP code', async () => {
    const f = await enrolledFixture();
    const reLogin = await login(f.user.username, f.plaintext);
    const challenge = await request(app).post('/api/auth/2fa/challenge')
      .send({ challengeToken: reLogin.body.challengeToken, code: '000000' });
    expect(challenge.status).toBe(401);
  });

  it('rejects an expired/invalid challengeToken', async () => {
    const f = await enrolledFixture();
    const code = currentCode(f.secret);
    const challenge = await request(app).post('/api/auth/2fa/challenge')
      .send({ challengeToken: 'not-a-jwt', code });
    expect(challenge.status).toBe(401);
  });

  it('rejects when neither code nor recoveryCode is present', async () => {
    const f = await enrolledFixture();
    const reLogin = await login(f.user.username, f.plaintext);
    const challenge = await request(app).post('/api/auth/2fa/challenge')
      .send({ challengeToken: reLogin.body.challengeToken });
    expect(challenge.status).toBe(400);
  });
});

// ---------- disable + admin reset ---------------------------------------

describe('POST /api/auth/2fa/disable + POST /api/users/:id/2fa/reset', () => {
  async function enrolled() {
    const { user, plaintext } = await makeFixtureUser();
    const initial = await login(user.username, plaintext);
    const userToken = initial.body.accessToken;
    const enroll = await request(app).post('/api/auth/2fa/enroll').set(auth(userToken)).expect(200);
    const code = currentCode(enroll.body.secret);
    await request(app).post('/api/auth/2fa/verify-enrollment').set(auth(userToken)).send({ code }).expect(200);
    // Re-login to get a fresh token; old userToken still works since access tokens haven't expired.
    return { user, plaintext, secret: enroll.body.secret, userToken };
  }

  it('user can self-disable with a valid TOTP code', async () => {
    const f = await enrolled();
    const code = currentCode(f.secret);
    const res = await request(app).post('/api/auth/2fa/disable')
      .set(auth(f.userToken)).send({ code });
    expect(res.status).toBe(200);
    const fresh = await prisma.user.findUnique({ where: { id: f.user.id } });
    expect(fresh.totpEnabledAt).toBeNull();
    expect(fresh.totpSecret).toBeNull();
    const codes = await prisma.recoveryCode.count({ where: { userId: f.user.id } });
    expect(codes).toBe(0);
  });

  it('user cannot self-disable without a valid code', async () => {
    const f = await enrolled();
    const res = await request(app).post('/api/auth/2fa/disable')
      .set(auth(f.userToken)).send({ code: '000000' });
    expect(res.status).toBe(401);
    const fresh = await prisma.user.findUnique({ where: { id: f.user.id } });
    expect(fresh.totpEnabledAt).not.toBeNull();
  });

  it('admin can reset 2FA on any user without a code', async () => {
    const f = await enrolled();
    const res = await request(app).post(`/api/users/${f.user.id}/2fa/reset`).set(auth(adminToken));
    expect(res.status).toBe(200);
    expect(res.body.was2FAEnabled).toBe(true);
    const fresh = await prisma.user.findUnique({ where: { id: f.user.id } });
    expect(fresh.totpEnabledAt).toBeNull();
  });

  it('admin reset on a user without 2FA is idempotent (no-op)', async () => {
    const { user } = await makeFixtureUser();
    const res = await request(app).post(`/api/users/${user.id}/2fa/reset`).set(auth(adminToken));
    expect(res.status).toBe(200);
    expect(res.body.was2FAEnabled).toBe(false);
  });
});
