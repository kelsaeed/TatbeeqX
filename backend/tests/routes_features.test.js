// Phase 4.7 — per-feature route smoke tests with self-cleanup.
//
// Each test creates whatever it needs, exercises the feature, and deletes
// the artifact in a finally block. This keeps the dev DB clean between runs.

import { describe, it, expect, beforeAll } from 'vitest';
import request from 'supertest';
import { buildApp } from '../src/lib/app.js';

const app = buildApp({ silent: true });

const SEED_USERNAME = process.env.SEED_SUPERADMIN_USERNAME || 'superadmin';
const SEED_PASSWORD = process.env.SEED_SUPERADMIN_PASSWORD || 'ChangeMe!2026';

let token;
const auth = () => ({ Authorization: `Bearer ${token}` });

beforeAll(async () => {
  const res = await request(app)
    .post('/api/auth/login')
    .send({ username: SEED_USERNAME, password: SEED_PASSWORD });
  if (res.status !== 200) throw new Error(`login failed: ${res.status}`);
  token = res.body.accessToken;
});

describe('Pages CRUD + analytics + reorder', () => {
  it('creates a page, adds blocks, reorders them, and deletes', async () => {
    const code = `t_${Date.now()}`;
    const create = await request(app)
      .post('/api/pages')
      .set(auth())
      .send({ code, title: 'Test Page', route: `/test-${code}` });
    expect(create.status).toBe(201);
    const pageId = create.body.id;

    try {
      // Add three blocks
      const ids = [];
      for (let i = 0; i < 3; i++) {
        const b = await request(app)
          .post(`/api/pages/${pageId}/blocks`)
          .set(auth())
          .send({ type: 'text', sortOrder: i, config: { text: `block ${i}` } });
        expect(b.status).toBe(201);
        ids.push(b.body.id);
      }

      // Reverse them
      const reorder = await request(app)
        .post(`/api/pages/${pageId}/reorder`)
        .set(auth())
        .send({ order: ids.slice().reverse().map((id) => ({ id })) });
      expect(reorder.status).toBe(200);

      // Read back and confirm order
      const read = await request(app)
        .get(`/api/pages/${pageId}`)
        .set(auth());
      expect(read.status).toBe(200);
      const sorted = read.body.blocks.slice().sort((a, b) => a.sortOrder - b.sortOrder);
      expect(sorted.map((b) => b.id)).toEqual(ids.slice().reverse());

      // Analytics should reflect at least these blocks
      const analytics = await request(app)
        .get('/api/pages/analytics')
        .set(auth());
      expect(analytics.status).toBe(200);
      expect(analytics.body.blockCount).toBeGreaterThanOrEqual(3);
    } finally {
      await request(app).delete(`/api/pages/${pageId}`).set(auth());
    }
  });

  it('sanitizes HTML blocks server-side', async () => {
    const code = `tsan_${Date.now()}`;
    const create = await request(app)
      .post('/api/pages')
      .set(auth())
      .send({ code, title: 'Sanitize Test', route: `/sanitize-${code}` });
    const pageId = create.body.id;

    try {
      const block = await request(app)
        .post(`/api/pages/${pageId}/blocks`)
        .set(auth())
        .send({
          type: 'html',
          sortOrder: 0,
          config: { html: '<p>ok</p><script>alert(1)</script><a href="javascript:bad()">x</a>' },
        });
      expect(block.status).toBe(201);
      expect(block.body.config.html).not.toContain('<script>');
      expect(block.body.config.html).not.toContain('javascript:');
      expect(block.body.config.html).toContain('<p>ok</p>');
    } finally {
      await request(app).delete(`/api/pages/${pageId}`).set(auth());
    }
  });
});

describe('Approval lifecycle', () => {
  it('request → approve transitions and audits', async () => {
    const create = await request(app)
      .post('/api/approvals')
      .set(auth())
      .send({
        entity: 'test_approval',
        title: 'Test approval',
        description: 'unit test',
        payload: { foo: 'bar' },
      });
    expect(create.status).toBe(201);
    const id = create.body.id;
    expect(create.body.status).toBe('pending');

    const approved = await request(app)
      .post(`/api/approvals/${id}/approve`)
      .set(auth())
      .send({ note: 'looks good' });
    expect(approved.status).toBe(200);
    expect(approved.body.status).toBe('approved');
    expect(approved.body.decisionNote).toBe('looks good');
  });

  it('cannot decide an already-decided request', async () => {
    const create = await request(app)
      .post('/api/approvals')
      .set(auth())
      .send({ entity: 'test_approval', title: 'Already done' });
    const id = create.body.id;
    await request(app).post(`/api/approvals/${id}/reject`).set(auth());
    const second = await request(app).post(`/api/approvals/${id}/approve`).set(auth());
    expect(second.status).toBeGreaterThanOrEqual(400);
  });
});

describe('Webhook subscription test-fire', () => {
  it('creates a subscription, fires a test event, lists deliveries, deletes', async () => {
    const create = await request(app)
      .post('/api/webhooks')
      .set(auth())
      .send({
        code: `wh_${Date.now()}`,
        name: 'Test webhook',
        url: 'http://127.0.0.1:1', // unreachable on purpose — we just want a delivery row
        events: ['webhook.test'],
      });
    expect(create.status).toBe(201);
    const id = create.body.id;
    expect(typeof create.body.secret).toBe('string');
    expect(create.body.secret.length).toBeGreaterThan(8);

    try {
      const fire = await request(app).post(`/api/webhooks/${id}/test`).set(auth());
      expect(fire.status).toBe(200);

      // The dispatcher fires async; allow it a beat to write the delivery row.
      await new Promise((r) => setTimeout(r, 250));
      const deliveries = await request(app)
        .get(`/api/webhooks/${id}/deliveries`)
        .set(auth());
      expect(deliveries.status).toBe(200);
      // We don't assert deliveries.length > 0 because the fetch + retry is
      // async and may still be in flight on slow CI. The endpoint shape is
      // what matters here.
      expect(Array.isArray(deliveries.body.items)).toBe(true);
    } finally {
      await request(app).delete(`/api/webhooks/${id}`).set(auth());
    }
  });
});

describe('Report schedule run-now', () => {
  it('creates a daily schedule, runs it manually, deletes', async () => {
    // Pick the first seeded report.
    const reports = await request(app).get('/api/reports').set(auth());
    expect(reports.status).toBe(200);
    expect(reports.body.items.length).toBeGreaterThan(0);
    const reportId = reports.body.items[0].id;

    const sch = await request(app)
      .post('/api/report-schedules')
      .set(auth())
      .send({
        reportId,
        name: `t-sch-${Date.now()}`,
        frequency: 'daily',
        timeOfDay: '09:00',
      });
    expect(sch.status).toBe(201);
    const id = sch.body.id;

    try {
      const run = await request(app)
        .post(`/api/report-schedules/${id}/run-now`)
        .set(auth());
      expect(run.status).toBe(200);
      expect(run.body.success).toBe(true);

      const runs = await request(app)
        .get(`/api/report-schedules/${id}/runs`)
        .set(auth());
      expect(runs.status).toBe(200);
      expect(runs.body.items.length).toBeGreaterThan(0);
      expect(runs.body.items[0].success).toBe(true);
    } finally {
      await request(app).delete(`/api/report-schedules/${id}`).set(auth());
    }
  });
});

describe('Backups', () => {
  it('creates a backup, lists it, deletes it', async () => {
    const create = await request(app)
      .post('/api/admin/backups')
      .set(auth())
      .send({ label: `smoke-${Date.now()}` });

    if (create.status === 400 && /SQLite/i.test(create.body?.message || '')) {
      // Running against a non-SQLite primary; skip rather than fail.
      return;
    }

    expect(create.status).toBe(201);
    const name = create.body.name;
    expect(name).toMatch(/\.db$/);

    try {
      const list = await request(app).get('/api/admin/backups').set(auth());
      expect(list.status).toBe(200);
      const found = list.body.items.find((b) => b.name === name);
      expect(found).toBeDefined();
      expect(found.size).toBeGreaterThan(0);
    } finally {
      await request(app).delete(`/api/admin/backups/${name}`).set(auth());
    }
  });
});
