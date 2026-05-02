// Phase 4.6 — route-layer integration tests.
//
// We mount the live Express app via supertest (no port binding). Tests run
// against the dev SQLite primary that the seeder already populated, so the
// suite is read-mostly. The few writes (login → updates lastLoginAt and
// records a LoginEvent) are intentionally additive and idempotent — they
// don't corrupt fixture state.

import { describe, it, expect, beforeAll } from 'vitest';
import request from 'supertest';
import { buildApp } from '../src/lib/app.js';

const app = buildApp({ silent: true });

const SEED_USERNAME = process.env.SEED_SUPERADMIN_USERNAME || 'superadmin';
const SEED_PASSWORD = process.env.SEED_SUPERADMIN_PASSWORD || 'ChangeMe!2026';

let accessToken;
let refreshToken;

beforeAll(async () => {
  const res = await request(app)
    .post('/api/auth/login')
    .send({ username: SEED_USERNAME, password: SEED_PASSWORD });
  if (res.status !== 200) {
    throw new Error(
      `Test bootstrap failed — could not log in as ${SEED_USERNAME}. ` +
      `Run 'npm run db:seed' first. Status was ${res.status}, body: ${JSON.stringify(res.body)}`,
    );
  }
  accessToken = res.body.accessToken;
  refreshToken = res.body.refreshToken;
});

describe('GET /api/health', () => {
  it('is publicly reachable and returns ok:true', async () => {
    const res = await request(app).get('/api/health');
    expect(res.status).toBe(200);
    expect(res.body.ok).toBe(true);
    expect(typeof res.body.time).toBe('string');
  });
});

describe('POST /api/auth/login', () => {
  it('rejects bad credentials with 401', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ username: 'definitely-not-a-user', password: 'nope' });
    expect(res.status).toBe(401);
  });

  it('returns a session for the seeded super admin', async () => {
    expect(accessToken).toBeTruthy();
    expect(refreshToken).toBeTruthy();
  });

  it('login records a LoginEvent (visible via /login-events)', async () => {
    const res = await request(app)
      .get('/api/login-events?event=login&pageSize=5')
      .set('Authorization', `Bearer ${accessToken}`);
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body.items)).toBe(true);
    expect(res.body.items.length).toBeGreaterThan(0);
    const recent = res.body.items[0];
    expect(recent.event).toBe('login');
  });
});

describe('GET /api/auth/me', () => {
  it('rejects when no token is sent', async () => {
    const res = await request(app).get('/api/auth/me');
    expect(res.status).toBe(401);
  });

  it('returns the user + permissions with a valid token', async () => {
    const res = await request(app)
      .get('/api/auth/me')
      .set('Authorization', `Bearer ${accessToken}`);
    expect(res.status).toBe(200);
    expect(res.body.user.username).toBe(SEED_USERNAME);
    expect(res.body.user.isSuperAdmin).toBe(true);
    expect(Array.isArray(res.body.permissions)).toBe(true);
    expect(res.body.permissions.length).toBeGreaterThan(0);
  });
});

describe('GET /api/permissions', () => {
  it('lists the seeded permission catalog', async () => {
    const res = await request(app)
      .get('/api/permissions')
      .set('Authorization', `Bearer ${accessToken}`);
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body.items)).toBe(true);
    expect(res.body.items.length).toBeGreaterThan(0);
    // Sample sanity: 'users.view' should always be present.
    const codes = res.body.items.map((p) => p.code);
    expect(codes).toContain('users.view');
  });
});

describe('GET /api/menus', () => {
  it('returns a tree the super admin can see all of', async () => {
    const res = await request(app)
      .get('/api/menus')
      .set('Authorization', `Bearer ${accessToken}`);
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body.tree)).toBe(true);
    expect(res.body.tree.length).toBeGreaterThan(0);
  });
});

describe('GET /api/templates/kinds', () => {
  it('exposes the supported kinds (Phase 4.2)', async () => {
    const res = await request(app)
      .get('/api/templates/kinds')
      .set('Authorization', `Bearer ${accessToken}`);
    expect(res.status).toBe(200);
    expect(res.body.items).toEqual(
      expect.arrayContaining(['theme', 'business', 'pages', 'reports', 'queries', 'full']),
    );
  });
});

describe('POST /api/auth/refresh', () => {
  it('returns a new access token when given the refresh token', async () => {
    const res = await request(app)
      .post('/api/auth/refresh')
      .send({ refreshToken });
    expect(res.status).toBe(200);
    expect(typeof res.body.accessToken).toBe('string');
    expect(typeof res.body.refreshToken).toBe('string');
  });

  it('rejects an empty body', async () => {
    const res = await request(app).post('/api/auth/refresh').send({});
    expect(res.status).toBe(400);
  });

  it('rejects an invalid refresh token', async () => {
    const res = await request(app)
      .post('/api/auth/refresh')
      .send({ refreshToken: 'not-a-real-token' });
    expect(res.status).toBe(401);
  });
});

describe('POST /api/db/query (Super Admin only)', () => {
  it('runs a read-only SELECT against the primary', async () => {
    const res = await request(app)
      .post('/api/db/query')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ sql: 'SELECT 1 as x' });
    expect(res.status).toBe(200);
    expect(res.body.kind).toBe('rows');
    expect(res.body.rows[0].x).toBe(1);
    expect(res.body.secondary).toBe(false);
  });

  it('blocks an UPDATE on auth tables even with allowWrite', async () => {
    const res = await request(app)
      .post('/api/db/query')
      .set('Authorization', `Bearer ${accessToken}`)
      .send({ sql: 'UPDATE users SET fullName = "x"', allowWrite: true });
    expect(res.status).toBe(400);
  });
});
