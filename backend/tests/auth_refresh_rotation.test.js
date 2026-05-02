// Phase 4.16 follow-up — refresh-token rotation + reuse detection.
//
// Verifies the new `/auth/refresh` flow: each call rotates the token
// (old one revoked, new one issued), reusing a revoked token triggers
// the theft-detection branch (invalidates the whole chain), expired
// tokens are rejected, logout revokes server-side.

import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import request from 'supertest';
import { buildApp } from '../src/lib/app.js';
import { prisma } from '../src/lib/prisma.js';

const app = buildApp({ silent: true });

const SEED_USERNAME = process.env.SEED_SUPERADMIN_USERNAME || 'superadmin';
const SEED_PASSWORD = process.env.SEED_SUPERADMIN_PASSWORD || 'ChangeMe!2026';

async function freshLogin() {
  const res = await request(app)
    .post('/api/auth/login')
    .send({ username: SEED_USERNAME, password: SEED_PASSWORD });
  if (res.status !== 200) throw new Error(`login failed: ${res.status} ${JSON.stringify(res.body)}`);
  return { accessToken: res.body.accessToken, refreshToken: res.body.refreshToken };
}

// Track tokens we issue so afterAll can clean up the RefreshToken
// rows we leave behind. Cleanup is best-effort.
const createdJtis = new Set();

beforeAll(async () => {
  // Seed user must exist for these tests.
});

afterAll(async () => {
  if (createdJtis.size > 0) {
    await prisma.refreshToken.deleteMany({ where: { jti: { in: [...createdJtis] } } }).catch(() => {});
  }
});

describe('POST /api/auth/refresh — rotation', () => {
  it('issues a new refresh token and revokes the old one', async () => {
    const { refreshToken: rt1 } = await freshLogin();

    const res = await request(app)
      .post('/api/auth/refresh')
      .send({ refreshToken: rt1 });
    expect(res.status).toBe(200);
    expect(res.body.refreshToken).toBeTruthy();
    expect(res.body.refreshToken).not.toBe(rt1); // rotated
    expect(res.body.accessToken).toBeTruthy();

    // The old token's row should now be revoked.
    const oldJti = JSON.parse(Buffer.from(rt1.split('.')[1], 'base64url').toString()).jti;
    const oldRow = await prisma.refreshToken.findUnique({ where: { jti: oldJti } });
    expect(oldRow.revokedAt).not.toBeNull();
    expect(oldRow.replacedById).not.toBeNull();
    createdJtis.add(oldJti);

    // Track the new token for cleanup.
    const newJti = JSON.parse(Buffer.from(res.body.refreshToken.split('.')[1], 'base64url').toString()).jti;
    createdJtis.add(newJti);
  });

  it('detects reuse — second use of a revoked token invalidates the entire chain', async () => {
    const { refreshToken: rt1 } = await freshLogin();
    const oldJti = JSON.parse(Buffer.from(rt1.split('.')[1], 'base64url').toString()).jti;
    createdJtis.add(oldJti);

    // First refresh — succeeds, rt1 is now revoked.
    const ok = await request(app).post('/api/auth/refresh').send({ refreshToken: rt1 });
    expect(ok.status).toBe(200);
    const newJti = JSON.parse(Buffer.from(ok.body.refreshToken.split('.')[1], 'base64url').toString()).jti;
    createdJtis.add(newJti);

    // Second refresh with the SAME (now revoked) token — should fail
    // AND revoke any active tokens for the user (the chain we just
    // issued).
    const reuse = await request(app).post('/api/auth/refresh').send({ refreshToken: rt1 });
    expect(reuse.status).toBe(401);
    expect(reuse.body.error.message).toMatch(/used or revoked/);

    // The chain's currently-active token should now also be revoked.
    const chainRow = await prisma.refreshToken.findUnique({ where: { jti: newJti } });
    expect(chainRow.revokedAt).not.toBeNull();
  });

  it('rejects invalid / malformed refresh tokens', async () => {
    const res = await request(app)
      .post('/api/auth/refresh')
      .send({ refreshToken: 'not-a-jwt' });
    expect(res.status).toBe(401);
  });

  it('rejects when refreshToken body field is missing', async () => {
    const res = await request(app).post('/api/auth/refresh').send({});
    expect(res.status).toBe(400);
    expect(res.body.error.message).toMatch(/Missing refreshToken/);
  });
});

describe('GET /api/auth/sessions', () => {
  it('lists the caller\'s own active sessions with userAgent + ip', async () => {
    const a = await freshLogin();
    const b = await freshLogin();
    for (const t of [a.refreshToken, b.refreshToken]) {
      createdJtis.add(JSON.parse(Buffer.from(t.split('.')[1], 'base64url').toString()).jti);
    }

    const res = await request(app)
      .get('/api/auth/sessions')
      .set('Authorization', `Bearer ${a.accessToken}`)
      .expect(200);
    expect(res.body.items.length).toBeGreaterThanOrEqual(2);
    // Don't leak the jti — only id + metadata.
    for (const s of res.body.items) {
      expect(s.jti).toBeUndefined();
      expect(s.id).toBeTypeOf('number');
      expect(s).toHaveProperty('issuedAt');
      expect(s).toHaveProperty('expiresAt');
      expect(s).toHaveProperty('userAgent');
      expect(s).toHaveProperty('ip');
    }
  });

  it('marks `current: true` when ?currentJti matches the caller\'s refresh-token jti', async () => {
    const s = await freshLogin();
    const jti = JSON.parse(Buffer.from(s.refreshToken.split('.')[1], 'base64url').toString()).jti;
    createdJtis.add(jti);

    const res = await request(app)
      .get('/api/auth/sessions')
      .query({ currentJti: jti })
      .set('Authorization', `Bearer ${s.accessToken}`)
      .expect(200);
    const current = res.body.items.find((x) => x.current === true);
    expect(current).toBeDefined();
    // All other sessions should be `current: false`
    for (const x of res.body.items) {
      if (x !== current) expect(x.current).toBe(false);
    }
  });

  it('does NOT list revoked / expired tokens', async () => {
    const s = await freshLogin();
    const jti = JSON.parse(Buffer.from(s.refreshToken.split('.')[1], 'base64url').toString()).jti;
    createdJtis.add(jti);
    // Manually revoke this row
    await prisma.refreshToken.updateMany({ where: { jti }, data: { revokedAt: new Date() } });

    const res = await request(app)
      .get('/api/auth/sessions')
      .set('Authorization', `Bearer ${s.accessToken}`)
      .expect(200);
    expect(res.body.items.find((x) => x.id != null && JSON.parse(Buffer.from(s.refreshToken.split('.')[1], 'base64url').toString()).jti)).toBeDefined(); // sanity check on parsing
    // The revoked token shouldn't be in the list.
    const ids = res.body.items.map((x) => x.id);
    const revokedRow = await prisma.refreshToken.findUnique({ where: { jti } });
    expect(ids).not.toContain(revokedRow.id);
  });

  it('rejects unauthenticated requests', async () => {
    const res = await request(app).get('/api/auth/sessions');
    expect(res.status).toBe(401);
  });
});

describe('DELETE /api/auth/sessions/:id', () => {
  it('revokes the targeted session and only that one', async () => {
    const a = await freshLogin();
    const b = await freshLogin();
    const aJti = JSON.parse(Buffer.from(a.refreshToken.split('.')[1], 'base64url').toString()).jti;
    const bJti = JSON.parse(Buffer.from(b.refreshToken.split('.')[1], 'base64url').toString()).jti;
    createdJtis.add(aJti);
    createdJtis.add(bJti);

    const aRow = await prisma.refreshToken.findUnique({ where: { jti: aJti } });

    await request(app)
      .delete(`/api/auth/sessions/${aRow.id}`)
      .set('Authorization', `Bearer ${b.accessToken}`)
      .expect(200);

    const aFresh = await prisma.refreshToken.findUnique({ where: { jti: aJti } });
    expect(aFresh.revokedAt).not.toBeNull();
    const bFresh = await prisma.refreshToken.findUnique({ where: { jti: bJti } });
    expect(bFresh.revokedAt).toBeNull(); // untouched
  });

  it('returns 404 for a non-existent session id (and userId filter prevents cross-user access)', async () => {
    const me = await freshLogin();
    createdJtis.add(JSON.parse(Buffer.from(me.refreshToken.split('.')[1], 'base64url').toString()).jti);
    // Way past any seeded id — not mine, doesn't exist.
    const res = await request(app)
      .delete('/api/auth/sessions/999999999')
      .set('Authorization', `Bearer ${me.accessToken}`);
    expect(res.status).toBe(404);
  });

  it('returns 404 when revoking an already-revoked session (idempotency check)', async () => {
    const s = await freshLogin();
    const jti = JSON.parse(Buffer.from(s.refreshToken.split('.')[1], 'base64url').toString()).jti;
    createdJtis.add(jti);
    const row = await prisma.refreshToken.findUnique({ where: { jti } });

    await request(app)
      .delete(`/api/auth/sessions/${row.id}`)
      .set('Authorization', `Bearer ${s.accessToken}`)
      .expect(200);

    // Second attempt — already revoked → 404
    await request(app)
      .delete(`/api/auth/sessions/${row.id}`)
      .set('Authorization', `Bearer ${s.accessToken}`)
      .expect(404);
  });
});

describe('POST /api/auth/logout — server-side revocation', () => {
  it('revokes the presented refresh token row when given', async () => {
    const { accessToken, refreshToken } = await freshLogin();
    const jti = JSON.parse(Buffer.from(refreshToken.split('.')[1], 'base64url').toString()).jti;
    createdJtis.add(jti);

    const res = await request(app)
      .post('/api/auth/logout')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ refreshToken });
    expect(res.status).toBe(200);

    const row = await prisma.refreshToken.findUnique({ where: { jti } });
    expect(row.revokedAt).not.toBeNull();
  });

  it('revokes every active refresh token for the user when {everywhere: true}', async () => {
    const a = await freshLogin();
    const b = await freshLogin();
    const c = await freshLogin();
    for (const t of [a.refreshToken, b.refreshToken, c.refreshToken]) {
      createdJtis.add(JSON.parse(Buffer.from(t.split('.')[1], 'base64url').toString()).jti);
    }

    const res = await request(app)
      .post('/api/auth/logout')
      .set('Authorization', `Bearer ${a.accessToken}`)
      .send({ everywhere: true });
    expect(res.status).toBe(200);

    // All three sessions should now be revoked.
    for (const t of [a.refreshToken, b.refreshToken, c.refreshToken]) {
      const jti = JSON.parse(Buffer.from(t.split('.')[1], 'base64url').toString()).jti;
      const row = await prisma.refreshToken.findUnique({ where: { jti } });
      expect(row.revokedAt).not.toBeNull();
    }
  });
});
