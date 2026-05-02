// Phase 4.17 — workflow engine integration tests.
//
// Exercises CRUD + manual run + record-trigger fan-out + condition
// gating + step ordering. Runs against the per-test isolated DB
// stamped up by tests/setup.js.

import { describe, it, expect, beforeAll, afterEach } from 'vitest';
import request from 'supertest';
import { buildApp } from '../src/lib/app.js';
import { prisma } from '../src/lib/prisma.js';
import { fireWorkflowsForRecord, runWorkflowManually } from '../src/lib/workflow_engine.js';

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
  return `wf_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`;
}

// Wait for any fire-and-forget runs to flush. The engine awaits the
// run inside the dispatcher, but `dispatchTo` schedules each runWorkflow
// without await. 30ms was enough on a fast workstation, but a cold CI
// runner needs more headroom — bumped to 250ms after seeing flakiness
// on the first GitHub Actions run.
async function flush() {
  await new Promise((resolve) => setImmediate(resolve));
  await new Promise((resolve) => setTimeout(resolve, 250));
}

describe('POST /api/workflows — CRUD + validation', () => {
  it('creates an event-trigger workflow', async () => {
    const code = uid();
    codes.push(code);
    const res = await request(app)
      .post('/api/workflows')
      .set(auth())
      .send({
        code,
        name: 'On approval approved → log',
        triggerType: 'event',
        triggerConfig: { event: 'approval.approved' },
        actions: [
          { type: 'log', name: 'note', params: { level: 'info', message: 'approved' } },
        ],
      });
    expect(res.status).toBe(201);
    expect(res.body.triggerType).toBe('event');
    expect(res.body.actions).toHaveLength(1);
  });

  it('rejects invalid trigger type', async () => {
    const res = await request(app)
      .post('/api/workflows')
      .set(auth())
      .send({ code: uid(), name: 'bad', triggerType: 'lol', triggerConfig: {}, actions: [] });
    expect(res.status).toBe(400);
  });

  it('rejects record trigger without entity', async () => {
    const res = await request(app)
      .post('/api/workflows')
      .set(auth())
      .send({ code: uid(), name: 'bad', triggerType: 'record', triggerConfig: {}, actions: [] });
    expect(res.status).toBe(400);
    expect(res.body.error.message).toMatch(/entity/);
  });

  it('rejects unknown action type', async () => {
    const res = await request(app)
      .post('/api/workflows')
      .set(auth())
      .send({
        code: uid(),
        name: 'bad',
        triggerType: 'event',
        triggerConfig: { event: '*' },
        actions: [{ type: 'send_to_mars', params: {} }],
      });
    expect(res.status).toBe(400);
  });

  it('schedule trigger sets nextRunAt on create', async () => {
    const code = uid();
    codes.push(code);
    const res = await request(app)
      .post('/api/workflows')
      .set(auth())
      .send({
        code,
        name: 'sched',
        triggerType: 'schedule',
        triggerConfig: { frequency: 'every_5_minutes' },
        actions: [{ type: 'log', params: { message: 'tick' } }],
      });
    expect(res.status).toBe(201);
    expect(res.body.nextRunAt).toBeTruthy();
  });

  it('GET /triggers returns the catalog', async () => {
    const res = await request(app).get('/api/workflows/triggers').set(auth());
    expect(res.status).toBe(200);
    expect(res.body.triggerTypes).toContain('record');
    expect(res.body.actionTypes).toContain('http_request');
    expect(res.body.recordOps).toEqual(['created', 'updated', 'deleted']);
  });
});

describe('Manual run (POST /:id/run)', () => {
  it('executes the action chain and persists run + steps', async () => {
    const code = uid();
    codes.push(code);
    const create = await request(app)
      .post('/api/workflows')
      .set(auth())
      .send({
        code,
        name: 'manual chain',
        triggerType: 'event',
        triggerConfig: { event: '*' },
        actions: [
          { type: 'log', name: 'first', params: { message: 'a' } },
          { type: 'log', name: 'second', params: { message: 'b' } },
        ],
      });
    expect(create.status).toBe(201);

    const run = await request(app)
      .post(`/api/workflows/${create.body.id}/run`)
      .set(auth())
      .send({ payload: { hello: 'world' } });
    expect(run.status).toBe(200);
    expect(run.body.status).toBe('success');

    const detail = await request(app)
      .get(`/api/workflows/runs/${run.body.runId}`)
      .set(auth());
    expect(detail.status).toBe(200);
    expect(detail.body.steps).toHaveLength(2);
    expect(detail.body.steps[0].status).toBe('success');
    expect(detail.body.steps[1].status).toBe('success');
  });

  it('condition gates a step (skipped, not failed)', async () => {
    const code = uid();
    codes.push(code);
    const create = await request(app)
      .post('/api/workflows')
      .set(auth())
      .send({
        code,
        name: 'gated',
        triggerType: 'event',
        triggerConfig: { event: '*' },
        actions: [
          {
            type: 'log',
            name: 'guarded',
            condition: { field: 'trigger.payload.go', equals: true },
            params: { message: 'should not run' },
          },
          { type: 'log', name: 'always', params: { message: 'always' } },
        ],
      });

    const run = await request(app)
      .post(`/api/workflows/${create.body.id}/run`)
      .set(auth())
      .send({ payload: { go: false } });
    expect(run.body.status).toBe('success');

    const detail = await request(app)
      .get(`/api/workflows/runs/${run.body.runId}`)
      .set(auth());
    expect(detail.body.steps[0].status).toBe('skipped');
    expect(detail.body.steps[1].status).toBe('success');
  });

  it('failed step continues by default; stopOnError halts', async () => {
    const code = uid();
    codes.push(code);
    // http_request to an invalid URL will throw — clean way to force a failure.
    const create = await request(app)
      .post('/api/workflows')
      .set(auth())
      .send({
        code,
        name: 'failure',
        triggerType: 'event',
        triggerConfig: { event: '*' },
        actions: [
          { type: 'http_request', name: 'bad', params: { url: 'not-a-url' } },
          { type: 'log', name: 'after', params: { message: 'still ran' } },
        ],
      });
    const run1 = await request(app)
      .post(`/api/workflows/${create.body.id}/run`)
      .set(auth());
    expect(run1.body.status).toBe('failed');
    const detail1 = await request(app)
      .get(`/api/workflows/runs/${run1.body.runId}`)
      .set(auth());
    expect(detail1.body.steps[0].status).toBe('failed');
    expect(detail1.body.steps[1].status).toBe('success');

    // Now flip to stopOnError on the first action.
    await request(app)
      .put(`/api/workflows/${create.body.id}`)
      .set(auth())
      .send({
        actions: [
          { type: 'http_request', name: 'bad', stopOnError: true, params: { url: 'not-a-url' } },
          { type: 'log', name: 'after', params: { message: 'should NOT run' } },
        ],
      });
    const run2 = await request(app)
      .post(`/api/workflows/${create.body.id}/run`)
      .set(auth());
    const detail2 = await request(app)
      .get(`/api/workflows/runs/${run2.body.runId}`)
      .set(auth());
    expect(detail2.body.steps).toHaveLength(1);
    expect(detail2.body.steps[0].status).toBe('failed');
  });
});

describe('record.* trigger end-to-end', () => {
  let entity;
  const entityCode = `wf_test_leads`;

  beforeAll(async () => {
    // Build a tiny entity directly via the engine — keeps the test
    // independent of route-permission churn for `custom_entities`.
    const { registerCustomEntity } = await import('../src/lib/business_presets.js');
    await registerCustomEntity({
      code: entityCode,
      tableName: entityCode,
      label: 'WF Test Leads',
      singular: 'Lead',
      icon: 'reports',
      category: 'custom',
      columns: [
        { name: 'name', type: 'text' },
        { name: 'amount', type: 'number' },
        { name: 'status', type: 'text' },
      ],
      sortOrder: 999,
    });
    entity = await prisma.customEntity.findUnique({ where: { code: entityCode } });
  });

  it('fires a workflow when filter matches; skips when it does not', async () => {
    const code = uid();
    codes.push(code);

    await request(app)
      .post('/api/workflows')
      .set(auth())
      .send({
        code,
        name: 'on big lead',
        triggerType: 'record',
        triggerConfig: {
          entity: entityCode,
          on: ['created'],
          filter: { field: 'trigger.row.amount', gt: 100 },
        },
        actions: [
          { type: 'log', name: 'note', params: { message: 'big lead {{trigger.row.id}}' } },
        ],
      });

    // Above-threshold row → workflow runs.
    await fireWorkflowsForRecord(entityCode, 'created', { id: 1, amount: 500, name: 'A', status: 'pending' }, null);
    // Below-threshold row → workflow skipped at trigger match.
    await fireWorkflowsForRecord(entityCode, 'created', { id: 2, amount: 50, name: 'B', status: 'pending' }, null);
    await flush();

    const wf = await prisma.workflow.findUnique({ where: { code } });
    const runs = await prisma.workflowRun.findMany({ where: { workflowId: wf.id } });
    expect(runs).toHaveLength(1);
    expect(runs[0].status).toBe('success');
  });

  it('record.updated supplies trigger.before', async () => {
    const code = uid();
    codes.push(code);
    await request(app)
      .post('/api/workflows')
      .set(auth())
      .send({
        code,
        name: 'on status flip to closed',
        triggerType: 'record',
        triggerConfig: {
          entity: entityCode,
          on: ['updated'],
          filter: {
            all: [
              { field: 'trigger.row.status', equals: 'closed' },
              { field: 'trigger.before.status', notEquals: 'closed' },
            ],
          },
        },
        actions: [{ type: 'log', name: 'flipped', params: { message: 'closed' } }],
      });

    await fireWorkflowsForRecord(
      entityCode, 'updated',
      { id: 7, status: 'closed' }, { id: 7, status: 'pending' },
    );
    // Same row already closed → no transition → no fire.
    await fireWorkflowsForRecord(
      entityCode, 'updated',
      { id: 7, status: 'closed' }, { id: 7, status: 'closed' },
    );
    await flush();

    const wf = await prisma.workflow.findUnique({ where: { code } });
    const runs = await prisma.workflowRun.findMany({ where: { workflowId: wf.id } });
    expect(runs).toHaveLength(1);
  });
});

describe('templating + step chaining', () => {
  it('later step reads earlier step.result via {{steps.x.id}}', async () => {
    const code = uid();
    codes.push(code);
    const create = await request(app)
      .post('/api/workflows')
      .set(auth())
      .send({
        code,
        name: 'chain',
        triggerType: 'event',
        triggerConfig: { event: '*' },
        actions: [
          { type: 'log', name: 'first', params: { message: 'one' } },
          // Note: log's result is { ok: true } — not very illustrative.
          // We use create_approval which returns { id: <int> } and read it.
          {
            type: 'create_approval',
            name: 'mk',
            params: { entity: 'unit_test', title: 'wf-test {{trigger.payload.who}}' },
          },
          {
            type: 'log',
            name: 'after',
            params: { message: 'approval id={{steps.mk.id}}' },
          },
        ],
      });

    const run = await request(app)
      .post(`/api/workflows/${create.body.id}/run`)
      .set(auth())
      .send({ payload: { who: 'alice' } });
    expect(run.body.status).toBe('success');

    const detail = await request(app)
      .get(`/api/workflows/runs/${run.body.runId}`)
      .set(auth());
    const mkStep = detail.body.steps.find((s) => s.actionName === 'mk');
    expect(mkStep.result.id).toBeGreaterThan(0);

    // Cleanup — the manually-run create_approval action persisted a real row.
    await prisma.approvalRequest.delete({ where: { id: mkStep.result.id } }).catch(() => {});
  });
});
