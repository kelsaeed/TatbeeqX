// Phase 4.18 — in-app notifications.
//
// CRUD, per-user gating, and the workflow `notify_user` action wired
// end-to-end. Notifications are per-account state — there is no
// admin-sees-everyone view.

import { describe, it, expect, beforeAll, beforeEach, afterEach } from 'vitest';
import request from 'supertest';
import { buildApp } from '../src/lib/app.js';
import { prisma } from '../src/lib/prisma.js';
import bcrypt from 'bcryptjs';

const app = buildApp({ silent: true });

const SEED_USERNAME = process.env.SEED_SUPERADMIN_USERNAME || 'superadmin';
const SEED_PASSWORD = process.env.SEED_SUPERADMIN_PASSWORD || 'ChangeMe!2026';

let adminToken;
let adminId;
const adminAuth = () => ({ Authorization: `Bearer ${adminToken}` });

// A second user we use to verify per-account isolation.
let otherToken;
let otherId;
let otherUsername;
const otherAuth = () => ({ Authorization: `Bearer ${otherToken}` });

beforeAll(async () => {
  const login = await request(app)
    .post('/api/auth/login')
    .send({ username: SEED_USERNAME, password: SEED_PASSWORD });
  if (login.status !== 200) throw new Error(`admin login failed: ${login.status}`);
  adminToken = login.body.accessToken;
  adminId = login.body.user.id;

  // Create a second user inline (avoid depending on a particular
  // pre-seeded test account being present).
  otherUsername = `notif_test_${Date.now()}`;
  const passwordHash = await bcrypt.hash('Notif!2026Pass', 10);
  const u = await prisma.user.create({
    data: {
      username: otherUsername,
      email: `${otherUsername}@local`,
      fullName: 'Notif Test',
      passwordHash,
      isActive: true,
    },
  });
  otherId = u.id;

  const login2 = await request(app)
    .post('/api/auth/login')
    .send({ username: otherUsername, password: 'Notif!2026Pass' });
  if (login2.status !== 200) throw new Error(`other login failed: ${login2.status}`);
  otherToken = login2.body.accessToken;
});

// Wipe before AND after each test. Approval-decision flows in other
// test files (Phase 4.19) create notifications for the same admin user
// id, and those leak into "expected only N items" assertions here.
async function wipe() {
  await prisma.notification.deleteMany({
    where: { userId: { in: [adminId, otherId].filter(Boolean) } },
  }).catch(() => {});
}
beforeEach(wipe);
afterEach(wipe);

describe('GET /api/notifications', () => {
  it('returns only the caller\'s notifications', async () => {
    await prisma.notification.create({ data: { userId: adminId, title: 'mine' } });
    await prisma.notification.create({ data: { userId: otherId, title: 'theirs' } });

    const mine = await request(app).get('/api/notifications').set(adminAuth());
    const theirs = await request(app).get('/api/notifications').set(otherAuth());

    expect(mine.body.items.map((n) => n.title)).toEqual(['mine']);
    expect(theirs.body.items.map((n) => n.title)).toEqual(['theirs']);
  });

  it('orders unread first, then newest', async () => {
    await prisma.notification.create({
      data: { userId: adminId, title: 'old-read', readAt: new Date('2026-04-01') },
    });
    await prisma.notification.create({ data: { userId: adminId, title: 'middle-unread' } });
    await prisma.notification.create({ data: { userId: adminId, title: 'newest-unread' } });

    const res = await request(app).get('/api/notifications').set(adminAuth());
    const titles = res.body.items.map((n) => n.title);
    // Both unread come before the read one.
    expect(titles.indexOf('old-read')).toBe(2);
    // Within unread, newer id wins (orderBy id desc).
    expect(titles[0]).toBe('newest-unread');
  });

  it('?unread=true filters to only unread', async () => {
    await prisma.notification.create({
      data: { userId: adminId, title: 'read', readAt: new Date() },
    });
    await prisma.notification.create({ data: { userId: adminId, title: 'unread' } });

    const res = await request(app)
      .get('/api/notifications')
      .query({ unread: 'true' })
      .set(adminAuth());
    expect(res.body.items.map((n) => n.title)).toEqual(['unread']);
  });
});

describe('GET /api/notifications/unread-count', () => {
  it('counts only unread for the caller', async () => {
    await prisma.notification.create({ data: { userId: adminId, title: 'a' } });
    await prisma.notification.create({ data: { userId: adminId, title: 'b' } });
    await prisma.notification.create({
      data: { userId: adminId, title: 'c', readAt: new Date() },
    });
    await prisma.notification.create({ data: { userId: otherId, title: 'theirs' } });

    const mine = await request(app).get('/api/notifications/unread-count').set(adminAuth());
    expect(mine.body.count).toBe(2);

    const theirs = await request(app).get('/api/notifications/unread-count').set(otherAuth());
    expect(theirs.body.count).toBe(1);
  });
});

describe('POST /api/notifications/:id/read', () => {
  it('marks a notification read', async () => {
    const n = await prisma.notification.create({
      data: { userId: adminId, title: 'mark me' },
    });
    const res = await request(app)
      .post(`/api/notifications/${n.id}/read`)
      .set(adminAuth());
    expect(res.status).toBe(200);
    expect(res.body.readAt).toBeTruthy();
  });

  it('forbids marking another user\'s notification', async () => {
    const n = await prisma.notification.create({
      data: { userId: otherId, title: 'not yours' },
    });
    const res = await request(app)
      .post(`/api/notifications/${n.id}/read`)
      .set(adminAuth());
    expect(res.status).toBe(403);
  });
});

describe('POST /api/notifications/read-all', () => {
  it('marks every unread for the caller (and only the caller)', async () => {
    await prisma.notification.createMany({
      data: [
        { userId: adminId, title: 'a' },
        { userId: adminId, title: 'b' },
        { userId: otherId, title: 'theirs' },
      ],
    });
    const res = await request(app).post('/api/notifications/read-all').set(adminAuth());
    expect(res.body.marked).toBe(2);

    const adminUnread = await prisma.notification.count({ where: { userId: adminId, readAt: null } });
    const otherUnread = await prisma.notification.count({ where: { userId: otherId, readAt: null } });
    expect(adminUnread).toBe(0);
    expect(otherUnread).toBe(1);
  });
});

describe('DELETE /api/notifications/:id', () => {
  it('dismisses a single notification', async () => {
    const n = await prisma.notification.create({
      data: { userId: adminId, title: 'gone' },
    });
    const res = await request(app)
      .delete(`/api/notifications/${n.id}`)
      .set(adminAuth());
    expect(res.body.ok).toBe(true);
    const after = await prisma.notification.findUnique({ where: { id: n.id } });
    expect(after).toBeNull();
  });

  it('forbids dismissing another user\'s notification', async () => {
    const n = await prisma.notification.create({
      data: { userId: otherId, title: 'not yours' },
    });
    const res = await request(app)
      .delete(`/api/notifications/${n.id}`)
      .set(adminAuth());
    expect(res.status).toBe(403);
  });
});

describe('DELETE /api/notifications (bulk)', () => {
  it('clears read by default; spares unread', async () => {
    await prisma.notification.createMany({
      data: [
        { userId: adminId, title: 'r1', readAt: new Date() },
        { userId: adminId, title: 'r2', readAt: new Date() },
        { userId: adminId, title: 'unread' },
      ],
    });
    const res = await request(app).delete('/api/notifications').set(adminAuth());
    expect(res.body.deleted).toBe(2);
    const remaining = await prisma.notification.findMany({ where: { userId: adminId } });
    expect(remaining.map((n) => n.title)).toEqual(['unread']);
  });

  it('?all=true clears unread too', async () => {
    await prisma.notification.createMany({
      data: [
        { userId: adminId, title: 'r', readAt: new Date() },
        { userId: adminId, title: 'u' },
      ],
    });
    const res = await request(app).delete('/api/notifications').query({ all: 'true' }).set(adminAuth());
    expect(res.body.deleted).toBe(2);
  });
});

describe('Workflow notify_user action', () => {
  it('creates a notification for the resolved user', async () => {
    const code = `wfnotif_${Date.now()}`;
    const create = await request(app)
      .post('/api/workflows')
      .set(adminAuth())
      .send({
        code,
        name: 'ping other',
        triggerType: 'event',
        triggerConfig: { event: '*' },
        actions: [
          {
            type: 'notify_user',
            name: 'ping',
            params: {
              username: otherUsername,
              kind: 'workflow',
              title: 'You have a new task',
              body: 'See the approvals queue.',
              link: '/approvals',
            },
          },
        ],
      });
    expect(create.status).toBe(201);

    const fire = await request(app)
      .post(`/api/workflows/${create.body.id}/run`)
      .set(adminAuth())
      .send({ payload: {} });
    expect(fire.body.status).toBe('success');

    const list = await request(app).get('/api/notifications').set(otherAuth());
    expect(list.body.items).toHaveLength(1);
    expect(list.body.items[0].title).toBe('You have a new task');
    expect(list.body.items[0].link).toBe('/approvals');
    expect(list.body.items[0].kind).toBe('workflow');

    await prisma.workflow.delete({ where: { id: create.body.id } }).catch(() => {});
  });

  it('fails the step when no user resolves', async () => {
    const code = `wfnotif_bad_${Date.now()}`;
    const create = await request(app)
      .post('/api/workflows')
      .set(adminAuth())
      .send({
        code,
        name: 'ping ghost',
        triggerType: 'event',
        triggerConfig: { event: '*' },
        actions: [
          {
            type: 'notify_user',
            name: 'ping',
            params: { username: 'absolutely_does_not_exist_zzz', title: 'hi' },
          },
        ],
      });
    const fire = await request(app)
      .post(`/api/workflows/${create.body.id}/run`)
      .set(adminAuth());
    expect(fire.body.status).toBe('failed');
    expect(fire.body.error).toMatch(/could not resolve user/i);

    await prisma.workflow.delete({ where: { id: create.body.id } }).catch(() => {});
  });
});
