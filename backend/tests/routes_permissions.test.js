// Phase 4.7 — negative permission tests.
//
// Provisions a non-super-admin user, logs in as them, and verifies that
// Super-Admin-only endpoints return 403 even when the request is well-formed.
//
// The fixture user is created with the seeded super admin's token at suite
// setup and deleted on teardown so the dev DB stays clean.

import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import request from 'supertest';
import { buildApp } from '../src/lib/app.js';

const app = buildApp({ silent: true });

const SEED_USERNAME = process.env.SEED_SUPERADMIN_USERNAME || 'superadmin';
const SEED_PASSWORD = process.env.SEED_SUPERADMIN_PASSWORD || 'ChangeMe!2026';
const TEST_USERNAME = `test_perm_${Date.now()}`;
const TEST_PASSWORD = 'TestPerm!1234';

let adminToken;
let userId;
let userToken;

beforeAll(async () => {
  // Log in as super admin to set up the fixture.
  const adminLogin = await request(app)
    .post('/api/auth/login')
    .send({ username: SEED_USERNAME, password: SEED_PASSWORD });
  if (adminLogin.status !== 200) {
    throw new Error(`Could not log in as ${SEED_USERNAME}: ${adminLogin.status}`);
  }
  adminToken = adminLogin.body.accessToken;

  // Create a plain user with no roles assigned.
  const created = await request(app)
    .post('/api/users')
    .set('Authorization', `Bearer ${adminToken}`)
    .send({
      username: TEST_USERNAME,
      email: `${TEST_USERNAME}@local`,
      fullName: 'Permission Fixture',
      password: TEST_PASSWORD,
      isActive: true,
      isSuperAdmin: false,
    });
  if (created.status !== 201 && created.status !== 200) {
    throw new Error(`Could not create test user: ${created.status} ${JSON.stringify(created.body)}`);
  }
  userId = created.body.id;

  // Log in as the new user.
  const userLogin = await request(app)
    .post('/api/auth/login')
    .send({ username: TEST_USERNAME, password: TEST_PASSWORD });
  if (userLogin.status !== 200) {
    throw new Error(`Could not log in as ${TEST_USERNAME}: ${userLogin.status}`);
  }
  userToken = userLogin.body.accessToken;
});

afterAll(async () => {
  if (userId && adminToken) {
    await request(app)
      .delete(`/api/users/${userId}`)
      .set('Authorization', `Bearer ${adminToken}`);
  }
});

describe('non-super-admin user with no roles', () => {
  it('can call /auth/me', async () => {
    const res = await request(app)
      .get('/api/auth/me')
      .set('Authorization', `Bearer ${userToken}`);
    expect(res.status).toBe(200);
    expect(res.body.user.isSuperAdmin).toBe(false);
    expect(Array.isArray(res.body.permissions)).toBe(true);
  });

  it('cannot list users (no users.view)', async () => {
    const res = await request(app)
      .get('/api/users')
      .set('Authorization', `Bearer ${userToken}`);
    expect(res.status).toBe(403);
  });

  it('cannot create roles', async () => {
    const res = await request(app)
      .post('/api/roles')
      .set('Authorization', `Bearer ${userToken}`)
      .send({ code: 'should_fail', name: 'Should Fail' });
    expect(res.status).toBe(403);
  });

  it('cannot run SQL (Super Admin only)', async () => {
    const res = await request(app)
      .post('/api/db/query')
      .set('Authorization', `Bearer ${userToken}`)
      .send({ sql: 'SELECT 1' });
    expect(res.status).toBe(403);
  });

  it('cannot list database connections (Super Admin only)', async () => {
    const res = await request(app)
      .get('/api/system/database/connections')
      .set('Authorization', `Bearer ${userToken}`);
    expect(res.status).toBe(403);
  });

  it('cannot capture a template (Super Admin only)', async () => {
    const res = await request(app)
      .post('/api/templates/capture')
      .set('Authorization', `Bearer ${userToken}`)
      .send({ code: 'should_fail', name: 'Should Fail', kind: 'theme' });
    expect(res.status).toBe(403);
  });

  it('cannot create a webhook (no webhooks.create)', async () => {
    const res = await request(app)
      .post('/api/webhooks')
      .set('Authorization', `Bearer ${userToken}`)
      .send({ code: 'fail', name: 'fail', url: 'https://example.com', events: ['*'] });
    expect(res.status).toBe(403);
  });

  it('cannot list backups (no backups.view)', async () => {
    const res = await request(app)
      .get('/api/admin/backups')
      .set('Authorization', `Bearer ${userToken}`);
    expect(res.status).toBe(403);
  });
});
