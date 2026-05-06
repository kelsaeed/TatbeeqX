// Phase 4.22 — approval queue (?mine=true) filter end-to-end.
//
// Verifies the listing actually narrows by `<entity>.approve`. Pure
// unit tests for `approvableEntities` live in permissions.test.js;
// this file covers the route wiring against a real DB + auth.

import { afterAll, beforeAll, describe, it, expect } from 'vitest';
import request from 'supertest';
import { buildApp } from '../src/lib/app.js';
import { prisma } from '../src/lib/prisma.js';

const app = buildApp({ silent: true });

const SEED_USERNAME = process.env.SEED_SUPERADMIN_USERNAME || 'superadmin';
const SEED_PASSWORD = process.env.SEED_SUPERADMIN_PASSWORD || 'ChangeMe!2026';
const TEST_USERNAME = `test_approvals_mine_${Date.now()}`;
const TEST_PASSWORD = 'TestQueue!1234';

let adminToken;
let userToken;
let userId;
const createdApprovalIds = [];

async function grantPermission(userId, code) {
  const perm = await prisma.permission.findUnique({ where: { code } });
  if (!perm) throw new Error(`Permission "${code}" not found in seed; can't grant.`);
  await prisma.userPermissionOverride.upsert({
    where: { userId_permissionId: { userId, permissionId: perm.id } },
    create: { userId, permissionId: perm.id, granted: true },
    update: { granted: true },
  });
}

beforeAll(async () => {
  const adminLogin = await request(app)
    .post('/api/auth/login')
    .send({ username: SEED_USERNAME, password: SEED_PASSWORD });
  if (adminLogin.status !== 200) throw new Error(`admin login failed: ${adminLogin.status}`);
  adminToken = adminLogin.body.accessToken;

  // Plain user — no roles, just permission overrides we set up below.
  const created = await request(app)
    .post('/api/users')
    .set('Authorization', `Bearer ${adminToken}`)
    .send({
      username: TEST_USERNAME,
      email: `${TEST_USERNAME}@local`,
      fullName: 'Approval Queue Fixture',
      password: TEST_PASSWORD,
      isActive: true,
      isSuperAdmin: false,
    });
  if (created.status !== 201 && created.status !== 200) {
    throw new Error(`could not create test user: ${created.status} ${JSON.stringify(created.body)}`);
  }
  userId = created.body.id;

  // approvals.view is required to even hit GET /approvals.
  await grantPermission(userId, 'approvals.view');

  const userLogin = await request(app)
    .post('/api/auth/login')
    .send({ username: TEST_USERNAME, password: TEST_PASSWORD });
  if (userLogin.status !== 200) throw new Error(`user login failed: ${userLogin.status}`);
  userToken = userLogin.body.accessToken;
});

afterAll(async () => {
  // Roll back our DB scribbles. CRD is fine even if some IDs were
  // never created — deleteMany skips missing rows.
  if (createdApprovalIds.length > 0) {
    await prisma.approvalRequest.deleteMany({
      where: { id: { in: createdApprovalIds } },
    }).catch(() => {});
  }
  if (userId && adminToken) {
    await request(app)
      .delete(`/api/users/${userId}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .catch(() => {});
  }
});

async function createApproval(entity, title) {
  const res = await request(app)
    .post('/api/approvals')
    .set('Authorization', `Bearer ${adminToken}`)
    .send({ entity, title });
  expect(res.status).toBe(201);
  createdApprovalIds.push(res.body.id);
  return res.body;
}

describe('GET /approvals?mine=true — Phase 4.22', () => {
  it('returns empty for a user with no <entity>.approve permissions', async () => {
    const a = await createApproval('companies', 'Mine filter test — companies row');
    const b = await createApproval('users', 'Mine filter test — users row');
    const res = await request(app)
      .get('/api/approvals?mine=true')
      .set('Authorization', `Bearer ${userToken}`);
    expect(res.status).toBe(200);
    // The user has no .approve perms — every result must be filtered
    // out, including the rows we just created.
    const ids = res.body.items.map((i) => i.id);
    expect(ids).not.toContain(a.id);
    expect(ids).not.toContain(b.id);
    expect(res.body.total).toBe(0);
  });

  it('after granting companies.approve, returns only companies-entity rows', async () => {
    await grantPermission(userId, 'companies.approve');
    const c = await createApproval('companies', 'Mine filter test — visible companies');
    const u = await createApproval('users', 'Mine filter test — invisible users');
    const res = await request(app)
      .get('/api/approvals?mine=true')
      .set('Authorization', `Bearer ${userToken}`);
    expect(res.status).toBe(200);
    const ids = res.body.items.map((i) => i.id);
    expect(ids).toContain(c.id);
    expect(ids).not.toContain(u.id);
    // Every returned row should be in the user's approvable entity set.
    for (const item of res.body.items) {
      expect(item.entity).toBe('companies');
      expect(item.status).toBe('pending');
    }
  });

  it('super-admin sees all pending rows under mine=true (no entity filter)', async () => {
    const c = await createApproval('companies', 'Admin queue — companies');
    const u = await createApproval('users', 'Admin queue — users');
    const res = await request(app)
      .get('/api/approvals?mine=true')
      .set('Authorization', `Bearer ${adminToken}`);
    expect(res.status).toBe(200);
    const ids = res.body.items.map((i) => i.id);
    expect(ids).toContain(c.id);
    expect(ids).toContain(u.id);
    // Super-admin under mine=true should get pending rows regardless
    // of entity — but still only PENDING.
    for (const item of res.body.items) {
      expect(item.status).toBe('pending');
    }
  });

  it('mine=true ignores the status query param (always pending)', async () => {
    // Even if the caller passes status=approved, mine=true forces
    // pending. The "queue" is by definition actionable items.
    const res = await request(app)
      .get('/api/approvals?mine=true&status=approved')
      .set('Authorization', `Bearer ${userToken}`);
    expect(res.status).toBe(200);
    for (const item of res.body.items) {
      expect(item.status).toBe('pending');
    }
  });

  it('GET /pending-count?mine=true matches the listing total', async () => {
    const list = await request(app)
      .get('/api/approvals?mine=true&pageSize=100')
      .set('Authorization', `Bearer ${userToken}`);
    const count = await request(app)
      .get('/api/approvals/pending-count?mine=true')
      .set('Authorization', `Bearer ${userToken}`);
    expect(list.status).toBe(200);
    expect(count.status).toBe(200);
    expect(count.body.total).toBe(list.body.total);
  });
});
