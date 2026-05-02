// Phase 4.5 — server-side handler registry for approval decisions.
//
// Domain code can call `registerApprovalHandler(entity, handler)` once at
// boot. When an `ApprovalRequest` for that entity flips to approved or
// rejected, the handler is invoked with the full DTO. The handler runs
// inline after the decide endpoint commits, before the HTTP response
// returns — so callers can rely on the side-effect having happened.
//
// Why both webhooks AND handlers?
//   - Webhooks notify external systems (other services, Slack, etc).
//   - Handlers run *inside this process*, with access to the Prisma client,
//     so they can apply domain mutations transactionally and synchronously.
//   - The two are complementary; both fire for the same decision.

import { logSystem } from './system_log.js';

const handlers = new Map(); // entity -> Set<{ name, fn }>

export function registerApprovalHandler(entity, handler, name = null) {
  if (!entity || typeof entity !== 'string') throw new Error('entity required');
  if (typeof handler !== 'function') throw new Error('handler must be a function');
  if (!handlers.has(entity)) handlers.set(entity, new Set());
  handlers.get(entity).add({ name: name ?? handler.name ?? 'anonymous', fn: handler });
}

export function unregisterApprovalHandler(entity, handler) {
  const set = handlers.get(entity);
  if (!set) return;
  for (const entry of set) {
    if (entry.fn === handler) {
      set.delete(entry);
      return;
    }
  }
}

export function listHandlers() {
  const out = {};
  for (const [entity, set] of handlers.entries()) {
    out[entity] = Array.from(set).map((e) => e.name);
  }
  return out;
}

export async function runHandlers(decision, dto) {
  const set = handlers.get(dto.entity);
  if (!set || set.size === 0) return { ran: 0, errors: [] };
  let ran = 0;
  const errors = [];
  for (const entry of set) {
    try {
      await entry.fn({ decision, request: dto });
      ran++;
    } catch (err) {
      errors.push({ name: entry.name, error: String(err?.message || err) });
      await logSystem('warn', 'approval_handlers', `Handler ${entry.name} for ${dto.entity} threw`, {
        decision,
        requestId: dto.id,
        error: String(err?.message || err),
      });
    }
  }
  return { ran, errors };
}
