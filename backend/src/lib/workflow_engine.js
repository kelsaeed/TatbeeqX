// Phase 4.17 — workflow engine.
//
// Three triggers (record / event / schedule), six actions (set_field /
// create_record / http_request / dispatch_event / create_approval /
// log). Sync, fire-and-forget — same posture as `dispatchEvent`. Each
// run + step is persisted so the operator can inspect what happened.
//
// See docs/48-workflow-engine.md for the full design.

import { prisma } from './prisma.js';
import { logSystem } from './system_log.js';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

// Phase 4.17 v2 — `webhook` was added so external systems can POST to a
// public per-workflow URL (`/api/workflows/incoming/:code`) authenticated
// by a per-workflow shared secret. Same engine, just a different match
// path: incoming HTTP requests bypass trigger matching entirely (the
// route handler runs the workflow directly when the secret is valid).
export const TRIGGER_TYPES = ['record', 'event', 'schedule', 'webhook'];
export const ACTION_TYPES = [
  'set_field',
  'create_record',
  'http_request',
  'dispatch_event',
  'create_approval',
  'log',
];
export const RECORD_OPS = ['created', 'updated', 'deleted'];

const PAYLOAD_CAP = 16_000;
const RESULT_CAP = 4_000;
const HTTP_TIMEOUT_MS = 10_000;

// ---------------------------------------------------------------------------
// Path resolver — used by templating + condition DSL
// ---------------------------------------------------------------------------

// Walk a dot-path against a context object. Returns undefined if any
// segment is missing. Bracket notation isn't supported — workflow
// authors stick to identifier paths.
export function resolvePath(ctx, path) {
  if (typeof path !== 'string' || path.length === 0) return undefined;
  const parts = path.split('.');
  let cur = ctx;
  for (const p of parts) {
    if (cur == null || typeof cur !== 'object') return undefined;
    cur = cur[p];
  }
  return cur;
}

// ---------------------------------------------------------------------------
// Templating — `{{path}}` substitution inside strings
// ---------------------------------------------------------------------------

const TEMPLATE_RE = /\{\{\s*([A-Za-z_][\w.]*)\s*\}\}/g;

// If the entire string is a single `{{path}}`, return the resolved
// value as-is (preserves number/object/null types). Otherwise do
// string substitution. Missing paths render as empty string.
export function renderTemplate(s, ctx) {
  if (typeof s !== 'string') return s;
  const whole = s.match(/^\s*\{\{\s*([A-Za-z_][\w.]*)\s*\}\}\s*$/);
  if (whole) return resolvePath(ctx, whole[1]);
  return s.replace(TEMPLATE_RE, (_m, path) => {
    const v = resolvePath(ctx, path);
    if (v === undefined || v === null) return '';
    if (typeof v === 'object') return JSON.stringify(v);
    return String(v);
  });
}

// Walk a value (object/array/string/etc.) and template every string
// inside. Numbers/bools/nulls pass through. Used to render action
// params before the handler runs.
export function renderValue(v, ctx) {
  if (typeof v === 'string') return renderTemplate(v, ctx);
  if (Array.isArray(v)) return v.map((x) => renderValue(x, ctx));
  if (v && typeof v === 'object') {
    const out = {};
    for (const [k, val] of Object.entries(v)) out[k] = renderValue(val, ctx);
    return out;
  }
  return v;
}

// ---------------------------------------------------------------------------
// Condition DSL
// ---------------------------------------------------------------------------
//
// A condition is one of:
//   { all:  [cond, ...] }     — every child truthy (AND)
//   { any:  [cond, ...] }     — at least one truthy (OR)
//   { not:  cond }            — negate
//   { field: 'path', <op>: value }
//
// Operators: equals, notEquals, gt, gte, lt, lte, in (value=array),
// isNull (value ignored), isNotNull, contains (string substring or
// array.includes), matches (regex source string).
//
// Falsy condition (undefined/null/{}) → always true. A malformed
// condition logs a warning and treats as false (fail closed — better
// to skip than to fire something the operator didn't intend).

function asArray(v) { return Array.isArray(v) ? v : [v]; }

export function evalCondition(cond, ctx) {
  if (cond == null) return true;
  if (typeof cond !== 'object') return false;
  if (Object.keys(cond).length === 0) return true;

  if (Array.isArray(cond.all)) return cond.all.every((c) => evalCondition(c, ctx));
  if (Array.isArray(cond.any)) return cond.any.some((c) => evalCondition(c, ctx));
  if (cond.not !== undefined) return !evalCondition(cond.not, ctx);

  if (typeof cond.field !== 'string') return false;
  const left = resolvePath(ctx, cond.field);

  if (cond.isNull === true) return left == null;
  if (cond.isNotNull === true) return left != null;
  if (cond.equals !== undefined) return left === cond.equals;
  if (cond.notEquals !== undefined) return left !== cond.notEquals;
  if (cond.gt !== undefined) return Number(left) > Number(cond.gt);
  if (cond.gte !== undefined) return Number(left) >= Number(cond.gte);
  if (cond.lt !== undefined) return Number(left) < Number(cond.lt);
  if (cond.lte !== undefined) return Number(left) <= Number(cond.lte);
  if (Array.isArray(cond.in)) return cond.in.includes(left);
  if (cond.contains !== undefined) {
    if (typeof left === 'string') return left.includes(String(cond.contains));
    if (Array.isArray(left)) return left.includes(cond.contains);
    return false;
  }
  if (cond.matches !== undefined) {
    try { return new RegExp(String(cond.matches)).test(String(left ?? '')); }
    catch { return false; }
  }
  return false;
}

// ---------------------------------------------------------------------------
// Trigger matching
// ---------------------------------------------------------------------------

function matchesRecordTrigger(cfg, trigger) {
  if (!cfg || typeof cfg !== 'object') return false;
  if (cfg.entity !== trigger.entity) return false;
  const ops = Array.isArray(cfg.on) && cfg.on.length > 0 ? cfg.on : RECORD_OPS;
  if (!ops.includes(trigger.op)) return false;
  if (cfg.filter) {
    // Filter sees the trigger payload — same shape passed to actions.
    return evalCondition(cfg.filter, { trigger });
  }
  return true;
}

function matchesEventTrigger(cfg, trigger) {
  if (!cfg || typeof cfg !== 'object') return false;
  if (cfg.event === '*') return true;
  return cfg.event === trigger.event;
}

// ---------------------------------------------------------------------------
// Action handlers
// ---------------------------------------------------------------------------
//
// Each handler receives ALREADY-RENDERED params (templating done by the
// runner) plus `ctx` for actions that want to peek at trigger state.
// Handlers return a JSON-serializable result that becomes available to
// later steps via `{{steps.<name>.<key>}}`.

// Late import of custom_entity_engine to avoid circular load (the
// engine imports this file too, indirectly, via dispatch).
async function getEntity(code) {
  const e = await prisma.customEntity.findUnique({ where: { code } });
  if (!e) throw new Error(`Custom entity "${code}" not found`);
  if (!e.isActive) throw new Error(`Custom entity "${code}" is disabled`);
  return e;
}

const HANDLERS = {
  async set_field(params) {
    const { entity, id, fields } = params;
    if (!entity) throw new Error('set_field: entity required');
    if (!id) throw new Error('set_field: id required');
    if (!fields || typeof fields !== 'object') throw new Error('set_field: fields object required');
    const ent = await getEntity(entity);
    const { updateRow } = await import('./custom_entity_engine.js');
    const updated = await updateRow(ent, Number(id), fields);
    return updated ? { id: updated.id } : { id: null };
  },

  async create_record(params) {
    const { entity, fields } = params;
    if (!entity) throw new Error('create_record: entity required');
    const ent = await getEntity(entity);
    const { insertRow } = await import('./custom_entity_engine.js');
    const created = await insertRow(ent, fields ?? {});
    return { id: created?.id ?? null };
  },

  async http_request(params) {
    const { method = 'POST', url, headers = {}, body } = params;
    if (!url || typeof url !== 'string') throw new Error('http_request: url required');
    if (!/^https?:\/\//i.test(url)) throw new Error('http_request: url must be http(s)://');
    let payload;
    let finalHeaders = { ...headers };
    if (body === undefined || body === null) {
      payload = undefined;
    } else if (typeof body === 'string') {
      payload = body;
    } else {
      payload = JSON.stringify(body);
      if (!Object.keys(finalHeaders).some((k) => k.toLowerCase() === 'content-type')) {
        finalHeaders['Content-Type'] = 'application/json';
      }
    }
    const res = await fetch(url, {
      method: method.toUpperCase(),
      headers: finalHeaders,
      body: payload,
      signal: AbortSignal.timeout(HTTP_TIMEOUT_MS),
    });
    let responseBody = null;
    try {
      const text = await res.text();
      responseBody = text.slice(0, 2000);
    } catch { /* swallow */ }
    if (!res.ok) {
      const err = new Error(`http_request: ${res.status} ${res.statusText}`);
      err.result = { status: res.status, body: responseBody };
      throw err;
    }
    return { status: res.status, body: responseBody };
  },

  async dispatch_event(params) {
    const { event, payload } = params;
    if (!event || typeof event !== 'string') throw new Error('dispatch_event: event required');
    // Late import to avoid circular load.
    const { dispatchEvent } = await import('./webhooks.js');
    await dispatchEvent(event, payload ?? {});
    return { event };
  },

  async create_approval(params) {
    const { entity, entityId, title, description, payload, requestedById } = params;
    if (!entity) throw new Error('create_approval: entity required');
    if (!title) throw new Error('create_approval: title required');
    // Workflow runs system-privileged — pin requestedBy to the system
    // user (id=1, the seeded superadmin) when the workflow doesn't
    // specify. This row is only used as the FK target.
    const reqById = Number.isFinite(Number(requestedById)) ? Number(requestedById) : 1;
    const created = await prisma.approvalRequest.create({
      data: {
        entity,
        entityId: entityId != null ? String(entityId) : null,
        title,
        description: description ?? null,
        payload: typeof payload === 'string' ? payload : JSON.stringify(payload ?? {}),
        status: 'pending',
        requestedById: reqById,
      },
    });
    return { id: created.id };
  },

  async log(params) {
    const { level = 'info', message = '', context } = params;
    const lvl = ['info', 'warn', 'error', 'debug'].includes(level) ? level : 'info';
    await logSystem(lvl, 'workflow', String(message).slice(0, 500), context ?? null);
    return { ok: true };
  },
};

// ---------------------------------------------------------------------------
// Run executor — sync, persists run + steps
// ---------------------------------------------------------------------------

function clipForStorage(v, cap) {
  if (v == null) return null;
  const s = typeof v === 'string' ? v : JSON.stringify(v);
  return s.length > cap ? s.slice(0, cap) : s;
}

export async function runWorkflow(workflow, triggerEvent, trigger) {
  const actions = parseJson(workflow.actions, []);
  const ctx = { trigger, env: { now: new Date().toISOString() }, steps: {} };

  const run = await prisma.workflowRun.create({
    data: {
      workflowId: workflow.id,
      triggerEvent,
      triggerPayload: clipForStorage(trigger, PAYLOAD_CAP),
      status: 'running',
    },
  });

  let runStatus = 'success';
  let runError = null;

  for (let i = 0; i < actions.length; i++) {
    const action = actions[i];
    const startedAt = new Date();
    let stepStatus = 'success';
    let stepResult = null;
    let stepError = null;

    try {
      if (!action || typeof action !== 'object') {
        throw new Error(`Action #${i} is not an object`);
      }
      if (!ACTION_TYPES.includes(action.type)) {
        throw new Error(`Unknown action type: ${action.type}`);
      }
      if (!evalCondition(action.condition, ctx)) {
        stepStatus = 'skipped';
      } else {
        const params = renderValue(action.params ?? {}, ctx);
        const handler = HANDLERS[action.type];
        stepResult = await handler(params, ctx);
        if (action.name) ctx.steps[action.name] = stepResult ?? {};
      }
    } catch (err) {
      stepStatus = 'failed';
      stepError = String(err?.message || err);
      runStatus = 'failed';
      if (runError == null) runError = stepError;
    }

    await prisma.workflowRunStep.create({
      data: {
        runId: run.id,
        index: i,
        actionType: action?.type ?? 'unknown',
        actionName: action?.name ?? null,
        status: stepStatus,
        result: clipForStorage(stepResult, RESULT_CAP),
        error: stepError,
        startedAt,
        finishedAt: new Date(),
      },
    });

    if (stepStatus === 'failed' && action?.stopOnError === true) break;
  }

  await prisma.workflowRun.update({
    where: { id: run.id },
    data: { status: runStatus, error: runError, finishedAt: new Date() },
  });

  return { runId: run.id, status: runStatus, error: runError };
}

function parseJson(s, fallback) {
  if (typeof s !== 'string' || s.length === 0) return fallback;
  try { return JSON.parse(s); } catch { return fallback; }
}

// ---------------------------------------------------------------------------
// Public dispatch — called from custom_entity_engine + webhooks + cron
// ---------------------------------------------------------------------------

async function findEnabled(triggerType) {
  return prisma.workflow.findMany({ where: { enabled: true, triggerType } });
}

async function dispatchTo(workflows, matcher, triggerEvent, trigger) {
  for (const wf of workflows) {
    const cfg = parseJson(wf.triggerConfig, {});
    let matched;
    try { matched = matcher(cfg, trigger); }
    catch (err) {
      await logSystem('warn', 'workflow', `Matcher failed for ${wf.code}`, { error: String(err?.message || err) });
      continue;
    }
    if (!matched) continue;
    runWorkflow(wf, triggerEvent, trigger).catch(async (err) => {
      await logSystem('error', 'workflow', `Run failed for ${wf.code}`, { error: String(err?.message || err) });
    });
  }
}

export async function fireWorkflowsForRecord(entityCode, op, row, before) {
  try {
    const wfs = await findEnabled('record');
    if (wfs.length === 0) return;
    const trigger = { kind: 'record', entity: entityCode, op, row: row ?? null, before: before ?? null };
    await dispatchTo(wfs, matchesRecordTrigger, `record.${op}`, trigger);
  } catch (err) {
    await logSystem('error', 'workflow', 'fireWorkflowsForRecord failed', {
      entity: entityCode, op, error: String(err?.message || err),
    }).catch(() => {});
  }
}

export async function fireWorkflowsForEvent(event, payload) {
  try {
    const wfs = await findEnabled('event');
    if (wfs.length === 0) return;
    const trigger = { kind: 'event', event, payload: payload ?? null };
    await dispatchTo(wfs, matchesEventTrigger, event, trigger);
  } catch (err) {
    await logSystem('error', 'workflow', 'fireWorkflowsForEvent failed', {
      event, error: String(err?.message || err),
    }).catch(() => {});
  }
}

// Manual fire (from `POST /workflows/:id/run`) — bypasses trigger
// matching, since the operator explicitly asked to run this one.
export async function runWorkflowManually(workflow, payload) {
  const trigger = { kind: 'manual', payload: payload ?? null };
  return runWorkflow(workflow, 'manual', trigger);
}

// Schedule-trigger entry, called from cron.js after it claims a row.
export async function runScheduledWorkflow(workflow) {
  const trigger = { kind: 'schedule', firedAt: new Date().toISOString() };
  return runWorkflow(workflow, 'schedule', trigger);
}
