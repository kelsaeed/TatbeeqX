// Phase 4.17 v2 — incoming-webhook trigger + by-code manual run.
//
// Covers the two new HTTP surfaces:
//   - POST /api/workflows/incoming/:code  (PUBLIC, secret-auth via header)
//   - POST /api/workflows/by-code/:code/run  (auth + workflows.run)

import { describe, it, expect, beforeAll, afterEach } from 'vitest';
import request from 'supertest';
import { buildApp } from '../src/lib/app.js';
import { prisma } from '../src/lib/prisma.js';

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

const codes = [];
afterEach(async () => {
  while (codes.length) {
    const code = codes.pop();
    await prisma.workflow.deleteMany({ where: { code } }).catch(() => {});
  }
});

function uid() {
  return `wf2_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`;
}

describe('POST /api/workflows/incoming/:code', () => {
  it('auto-generates a secret when triggerType=webhook + no secret provided', async () => {
    const code = uid();
    codes.push(code);
    const res = await request(app)
      .post('/api/workflows')
      .set(auth())
      .send({
        code,
        name: 'inbound',
        triggerType: 'webhook',
        triggerConfig: {},
        actions: [{ type: 'log', name: 'note', params: { message: 'received' } }],
      });
    expect(res.status).toBe(201);
    expect(typeof res.body.triggerConfig.secret).toBe('string');
    expect(res.body.triggerConfig.secret.length).toBeGreaterThanOrEqual(32);
  });

  it('runs when X-Workflow-Secret matches; persists a WorkflowRun', async () => {
    const code = uid();
    codes.push(code);
    const create = await request(app)
      .post('/api/workflows')
      .set(auth())
      .send({
        code,
        name: 'inbound-ok',
        triggerType: 'webhook',
        triggerConfig: { secret: 'a-test-secret-string' },
        actions: [{ type: 'log', name: 'note', params: { message: 'ok' } }],
      });
    expect(create.status).toBe(201);

    const fire = await request(app)
      .post(`/api/workflows/incoming/${code}`)
      .set('X-Workflow-Secret', 'a-test-secret-string')
      .send({ source: 'unit-test' });
    expect(fire.status).toBe(200);
    expect(fire.body.status).toBe('success');

    const runs = await prisma.workflowRun.findMany({ where: { workflowId: create.body.id } });
    expect(runs).toHaveLength(1);
    expect(runs[0].triggerEvent).toBe('webhook');
  });

  it('rejects 401 when secret missing', async () => {
    const code = uid();
    codes.push(code);
    const create = await request(app)
      .post('/api/workflows')
      .set(auth())
      .send({
        code,
        name: 'inbound-no-secret',
        triggerType: 'webhook',
        triggerConfig: { secret: 'right-secret' },
        actions: [{ type: 'log', name: 'note', params: { message: 'should not run' } }],
      });

    const fire = await request(app)
      .post(`/api/workflows/incoming/${code}`)
      .send({ source: 'attacker' });
    expect(fire.status).toBe(401);

    const runs = await prisma.workflowRun.findMany({ where: { workflowId: create.body.id } });
    expect(runs).toHaveLength(0);
  });

  it('rejects 401 when secret is wrong', async () => {
    const code = uid();
    codes.push(code);
    const create = await request(app)
      .post('/api/workflows')
      .set(auth())
      .send({
        code,
        name: 'inbound-bad-secret',
        triggerType: 'webhook',
        triggerConfig: { secret: 'right-secret' },
        actions: [{ type: 'log', name: 'note', params: { message: 'should not run' } }],
      });

    const fire = await request(app)
      .post(`/api/workflows/incoming/${code}`)
      .set('X-Workflow-Secret', 'wrong-secret')
      .send({});
    expect(fire.status).toBe(401);

    const runs = await prisma.workflowRun.findMany({ where: { workflowId: create.body.id } });
    expect(runs).toHaveLength(0);
  });

  it('returns 404 for unknown code', async () => {
    const fire = await request(app)
      .post('/api/workflows/incoming/this_does_not_exist_zzz')
      .set('X-Workflow-Secret', 'whatever')
      .send({});
    expect(fire.status).toBe(404);
  });

  it('returns 404 when triggerType is not webhook', async () => {
    const code = uid();
    codes.push(code);
    await request(app)
      .post('/api/workflows')
      .set(auth())
      .send({
        code,
        name: 'event-only',
        triggerType: 'event',
        triggerConfig: { event: '*' },
        actions: [{ type: 'log', params: { message: 'x' } }],
      });
    const fire = await request(app)
      .post(`/api/workflows/incoming/${code}`)
      .set('X-Workflow-Secret', 'doesnt-matter')
      .send({});
    expect(fire.status).toBe(404);
  });

  it('returns 404 when workflow is disabled (defense in depth)', async () => {
    const code = uid();
    codes.push(code);
    const create = await request(app)
      .post('/api/workflows')
      .set(auth())
      .send({
        code,
        name: 'disabled',
        triggerType: 'webhook',
        triggerConfig: { secret: 'sec' },
        actions: [{ type: 'log', params: { message: 'x' } }],
      });
    await request(app)
      .put(`/api/workflows/${create.body.id}`)
      .set(auth())
      .send({ enabled: false });
    const fire = await request(app)
      .post(`/api/workflows/incoming/${code}`)
      .set('X-Workflow-Secret', 'sec')
      .send({});
    expect(fire.status).toBe(404);
  });

  it('does NOT require Bearer auth (route mounts before authenticate)', async () => {
    const code = uid();
    codes.push(code);
    await request(app)
      .post('/api/workflows')
      .set(auth())
      .send({
        code,
        name: 'no-bearer',
        triggerType: 'webhook',
        triggerConfig: { secret: 'sec' },
        actions: [{ type: 'log', params: { message: 'x' } }],
      });
    // Note: no Authorization header.
    const fire = await request(app)
      .post(`/api/workflows/incoming/${code}`)
      .set('X-Workflow-Secret', 'sec')
      .send({});
    expect(fire.status).toBe(200);
  });
});

describe('POST /api/workflows/by-code/:code/run', () => {
  it('runs the workflow and writes a WorkflowRun', async () => {
    const code = uid();
    codes.push(code);
    const create = await request(app)
      .post('/api/workflows')
      .set(auth())
      .send({
        code,
        name: 'page-button-target',
        triggerType: 'event',
        triggerConfig: { event: '*' },
        actions: [{ type: 'log', name: 'note', params: { message: 'tap' } }],
      });
    const fire = await request(app)
      .post(`/api/workflows/by-code/${code}/run`)
      .set(auth())
      .send({ payload: { from: 'page-button' } });
    expect(fire.status).toBe(200);
    expect(fire.body.status).toBe('success');

    const runs = await prisma.workflowRun.findMany({ where: { workflowId: create.body.id } });
    expect(runs).toHaveLength(1);
    expect(runs[0].triggerEvent).toBe('manual');
  });

  it('rejects 401 without a Bearer token', async () => {
    const fire = await request(app)
      .post(`/api/workflows/by-code/anything/run`)
      .send({});
    expect(fire.status).toBe(401);
  });

  it('returns 404 when code does not exist', async () => {
    const fire = await request(app)
      .post(`/api/workflows/by-code/never_existed_zzz/run`)
      .set(auth())
      .send({});
    expect(fire.status).toBe(404);
  });
});
