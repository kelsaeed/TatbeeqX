// Phase 4.17 — workflow engine routes. CRUD + manual run + run history.
// See docs/48-workflow-engine.md.
//
// Phase 4.17 v2 — `POST /incoming/:code` is mounted BEFORE the
// authenticate middleware. The per-workflow shared secret IS the
// auth, matched in constant time against `triggerConfig.secret`.

import crypto from 'node:crypto';
import { Router } from 'express';
import rateLimit from 'express-rate-limit';
import { prisma } from '../lib/prisma.js';
import { authenticate } from '../middleware/auth.js';
import { requirePermission } from '../middleware/permission.js';
import { asyncHandler, badRequest, notFound, unauthorized } from '../lib/http.js';
import { parseId, requireFields, parsePagination } from '../middleware/validate.js';
import { writeAudit } from '../lib/audit.js';
import { computeNext } from '../lib/cron.js';
import {
  TRIGGER_TYPES, ACTION_TYPES, RECORD_OPS, runWorkflowManually, runWorkflow,
} from '../lib/workflow_engine.js';

const router = Router();

// Manual workflow runs can be expensive (DB writes, outbound webhooks,
// SMTP sends). Rate-limit per authenticated user (falls back to IP if
// somehow unauthenticated reaches here, which it shouldn't past
// `router.use(authenticate)`).
const workflowRunLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: Number(process.env.WORKFLOW_RUN_MAX) || 30,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => `wfrun:${req.user?.id ?? req.ip}`,
  message: { error: { message: 'Too many workflow runs. Try again in a few minutes.' } },
});

const SCHEDULE_FREQUENCIES = ['every_minute', 'every_5_minutes', 'hourly', 'daily', 'weekly', 'monthly', 'cron'];

// ---------------------------------------------------------------------------
// PUBLIC routes — must be declared before `router.use(authenticate)` below.
// ---------------------------------------------------------------------------

function constantTimeEquals(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string') return false;
  if (a.length !== b.length) return false;  // length leak is unavoidable; fail fast on the cheap signal
  return crypto.timingSafeEqual(Buffer.from(a, 'utf8'), Buffer.from(b, 'utf8'));
}

router.post(
  '/incoming/:code',
  asyncHandler(async (req, res) => {
    const code = String(req.params.code || '');
    const wf = await prisma.workflow.findUnique({ where: { code } });
    if (!wf || !wf.enabled || wf.triggerType !== 'webhook') throw notFound('Workflow not found');
    let cfg = {};
    try { cfg = JSON.parse(wf.triggerConfig || '{}'); } catch { /* keep {} */ }
    const expected = typeof cfg.secret === 'string' ? cfg.secret : '';
    const presented = req.get('X-Workflow-Secret') || '';
    if (!expected || !constantTimeEquals(expected, presented)) throw unauthorized('Invalid workflow secret');
    const trigger = { kind: 'webhook', payload: req.body ?? null };
    const result = await runWorkflow(wf, 'webhook', trigger);
    res.json(result);
  }),
);

// ---------------------------------------------------------------------------
// AUTHENTICATED routes — everything below requires a valid session.
// ---------------------------------------------------------------------------

router.use(authenticate);

function parseJson(s, fallback) {
  if (typeof s !== 'string' || s.length === 0) return fallback;
  try { return JSON.parse(s); } catch { return fallback; }
}

function toDto(w) {
  return {
    id: w.id,
    code: w.code,
    name: w.name,
    description: w.description,
    triggerType: w.triggerType,
    triggerConfig: parseJson(w.triggerConfig, {}),
    actions: parseJson(w.actions, []),
    enabled: w.enabled,
    nextRunAt: w.nextRunAt,
    lastRunAt: w.lastRunAt,
    createdAt: w.createdAt,
    updatedAt: w.updatedAt,
  };
}

function toRunDto(r) {
  return {
    id: r.id,
    workflowId: r.workflowId,
    triggerEvent: r.triggerEvent,
    triggerPayload: parseJson(r.triggerPayload, null),
    status: r.status,
    startedAt: r.startedAt,
    finishedAt: r.finishedAt,
    error: r.error,
    steps: Array.isArray(r.steps) ? r.steps.map(toStepDto) : undefined,
  };
}

function toStepDto(s) {
  return {
    id: s.id,
    index: s.index,
    actionType: s.actionType,
    actionName: s.actionName,
    status: s.status,
    result: parseJson(s.result, null),
    error: s.error,
    startedAt: s.startedAt,
    finishedAt: s.finishedAt,
  };
}

// Validate before write so the operator gets a clear 400 instead of a
// JSON-parse error from the engine at trigger time.
function validateDefinition({ triggerType, triggerConfig, actions }) {
  if (!TRIGGER_TYPES.includes(triggerType)) {
    throw badRequest(`triggerType must be one of ${TRIGGER_TYPES.join(', ')}`);
  }
  if (triggerConfig != null && (typeof triggerConfig !== 'object' || Array.isArray(triggerConfig))) {
    throw badRequest('triggerConfig must be a JSON object');
  }
  if (triggerType === 'record') {
    if (!triggerConfig || typeof triggerConfig.entity !== 'string') {
      throw badRequest('record trigger requires triggerConfig.entity (string)');
    }
    if (triggerConfig.on !== undefined) {
      if (!Array.isArray(triggerConfig.on) || triggerConfig.on.length === 0) {
        throw badRequest('triggerConfig.on must be a non-empty array');
      }
      const bad = triggerConfig.on.find((o) => !RECORD_OPS.includes(o));
      if (bad) throw badRequest(`Unknown record op: ${bad}`);
    }
  }
  if (triggerType === 'event') {
    if (!triggerConfig || typeof triggerConfig.event !== 'string') {
      throw badRequest('event trigger requires triggerConfig.event (string)');
    }
  }
  if (triggerType === 'schedule') {
    if (!triggerConfig || !SCHEDULE_FREQUENCIES.includes(triggerConfig.frequency)) {
      throw badRequest(`schedule trigger requires triggerConfig.frequency in ${SCHEDULE_FREQUENCIES.join(', ')}`);
    }
  }
  // Phase 4.17 v2 — webhook trigger needs a secret. We'll auto-generate
  // on create when missing (see POST handler), so validation only
  // rejects shapes that look explicitly broken (non-string secret).
  if (triggerType === 'webhook') {
    if (triggerConfig && triggerConfig.secret !== undefined && typeof triggerConfig.secret !== 'string') {
      throw badRequest('webhook trigger: secret must be a string when provided');
    }
  }
  if (!Array.isArray(actions)) throw badRequest('actions must be an array');
  for (let i = 0; i < actions.length; i++) {
    const a = actions[i];
    if (!a || typeof a !== 'object') throw badRequest(`action #${i} must be an object`);
    if (!ACTION_TYPES.includes(a.type)) throw badRequest(`action #${i}: unknown type "${a.type}"`);
  }
}

// `triggers` — operator-facing capabilities catalog. Drives the editor.
router.get(
  '/triggers',
  asyncHandler(async (_req, res) => {
    res.json({
      triggerTypes: TRIGGER_TYPES,
      actionTypes: ACTION_TYPES,
      recordOps: RECORD_OPS,
      scheduleFrequencies: SCHEDULE_FREQUENCIES,
    });
  }),
);

router.get(
  '/',
  requirePermission('workflows.view'),
  asyncHandler(async (_req, res) => {
    const items = await prisma.workflow.findMany({ orderBy: { id: 'asc' } });
    res.json({ items: items.map(toDto) });
  }),
);

router.get(
  '/:id',
  requirePermission('workflows.view'),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const w = await prisma.workflow.findUnique({ where: { id } });
    if (!w) throw notFound('Workflow not found');
    res.json(toDto(w));
  }),
);

router.get(
  '/:id/runs',
  requirePermission('workflows.view'),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const { skip, take, page, pageSize } = parsePagination(req.query);
    const [items, total] = await prisma.$transaction([
      prisma.workflowRun.findMany({
        where: { workflowId: id },
        skip,
        take,
        orderBy: { id: 'desc' },
      }),
      prisma.workflowRun.count({ where: { workflowId: id } }),
    ]);
    res.json({ items: items.map(toRunDto), total, page, pageSize });
  }),
);

router.get(
  '/runs/:runId',
  requirePermission('workflows.view'),
  asyncHandler(async (req, res) => {
    const runId = parseId(req.params.runId);
    const r = await prisma.workflowRun.findUnique({
      where: { id: runId },
      include: { steps: { orderBy: { index: 'asc' } } },
    });
    if (!r) throw notFound('Run not found');
    res.json(toRunDto(r));
  }),
);

router.post(
  '/',
  requirePermission('workflows.create'),
  asyncHandler(async (req, res) => {
    requireFields(req.body, ['code', 'name', 'triggerType']);
    const { code, name, description, triggerType, triggerConfig = {}, actions = [], enabled = true } = req.body;
    validateDefinition({ triggerType, triggerConfig, actions });
    // Phase 4.17 v2 — webhook trigger auto-secret. Mirrors the
    // WebhookSubscription create path: the secret is revealed once in
    // the response so the operator can copy it; subsequent reads return
    // it as well, since this is admin-only.
    if (triggerType === 'webhook' && !triggerConfig.secret) {
      triggerConfig.secret = crypto.randomBytes(24).toString('hex');
    }
    let nextRunAt = null;
    if (triggerType === 'schedule') nextRunAt = computeNext(triggerConfig, new Date());
    const created = await prisma.workflow.create({
      data: {
        code,
        name,
        description: description ?? null,
        triggerType,
        triggerConfig: JSON.stringify(triggerConfig),
        actions: JSON.stringify(actions),
        enabled: enabled !== false,
        nextRunAt,
      },
    });
    await writeAudit({ req, action: 'create', entity: 'Workflow', entityId: created.id });
    res.status(201).json(toDto(created));
  }),
);

router.put(
  '/:id',
  requirePermission('workflows.edit'),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const existing = await prisma.workflow.findUnique({ where: { id } });
    if (!existing) throw notFound('Workflow not found');

    const next = {
      triggerType: req.body.triggerType ?? existing.triggerType,
      triggerConfig: req.body.triggerConfig ?? parseJson(existing.triggerConfig, {}),
      actions: req.body.actions ?? parseJson(existing.actions, []),
    };
    validateDefinition(next);

    const update = {};
    if (req.body.name !== undefined) update.name = req.body.name;
    if (req.body.description !== undefined) update.description = req.body.description;
    if (req.body.enabled !== undefined) update.enabled = !!req.body.enabled;
    if (req.body.triggerType !== undefined) update.triggerType = req.body.triggerType;
    if (req.body.triggerConfig !== undefined) update.triggerConfig = JSON.stringify(req.body.triggerConfig);
    if (req.body.actions !== undefined) update.actions = JSON.stringify(req.body.actions);

    // If schedule fields changed (or trigger type became schedule), recompute nextRunAt.
    const reschedule = next.triggerType === 'schedule' && (
      req.body.triggerConfig !== undefined || req.body.triggerType !== undefined || req.body.enabled === true
    );
    if (reschedule) update.nextRunAt = computeNext(next.triggerConfig, new Date());
    if (next.triggerType !== 'schedule') update.nextRunAt = null;

    const updated = await prisma.workflow.update({ where: { id }, data: update });
    await writeAudit({ req, action: 'update', entity: 'Workflow', entityId: id });
    res.json(toDto(updated));
  }),
);

router.delete(
  '/:id',
  requirePermission('workflows.delete'),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    await prisma.workflow.delete({ where: { id } });
    await writeAudit({ req, action: 'delete', entity: 'Workflow', entityId: id });
    res.json({ ok: true });
  }),
);

router.post(
  '/:id/run',
  workflowRunLimiter,
  requirePermission('workflows.run'),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const w = await prisma.workflow.findUnique({ where: { id } });
    if (!w) throw notFound('Workflow not found');
    const result = await runWorkflowManually(w, req.body?.payload ?? null);
    await writeAudit({ req, action: 'run', entity: 'Workflow', entityId: id, metadata: result });
    res.json(result);
  }),
);

// Phase 4.17 v2 — by-code manual run. Consumed by the page-builder
// `button` block, whose runtime config carries `workflowCode` (not id —
// codes are stable across template apply / subsystem re-seeds, ids are
// not). Same permission gate as the by-id route.
router.post(
  '/by-code/:code/run',
  workflowRunLimiter,
  requirePermission('workflows.run'),
  asyncHandler(async (req, res) => {
    const code = String(req.params.code || '');
    const w = await prisma.workflow.findUnique({ where: { code } });
    if (!w) throw notFound('Workflow not found');
    const result = await runWorkflowManually(w, req.body?.payload ?? null);
    await writeAudit({ req, action: 'run', entity: 'Workflow', entityId: w.id, metadata: result });
    res.json(result);
  }),
);

export default router;
