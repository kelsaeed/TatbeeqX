import crypto from 'node:crypto';
import { prisma } from './prisma.js';
import { logSystem } from './system_log.js';

// Phase 4.4 — webhook dispatcher.
//
// Subscriptions live in `webhook_subscriptions`. On every supported event
// (today: approval.approved, approval.rejected, approval.cancelled), we
// look up active subscriptions whose `events` JSON array contains the
// event (or "*"), POST the payload to their URL, and record the delivery
// in `webhook_deliveries`. Signing uses an HMAC-SHA256 of the raw body
// with the per-subscription `secret` and is sent as `X-Money-Signature`.
//
// The dispatch is fire-and-forget — we do not await on the call site.

const MAX_ATTEMPTS = 3;
const RETRY_DELAY_MS = [0, 5_000, 30_000]; // first try immediate, then 5s, then 30s

function matches(events, event) {
  if (!Array.isArray(events) || events.length === 0) return false;
  return events.includes('*') || events.includes(event);
}

function signBody(secret, body) {
  if (!secret) return null;
  return crypto.createHmac('sha256', secret).update(body).digest('hex');
}

async function deliverOnce(sub, event, body, attempt) {
  const signature = signBody(sub.secret, body);
  let status = null;
  let error = null;
  let responseBody = null;
  try {
    const res = await fetch(sub.url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Money-Event': event,
        'X-Money-Attempt': String(attempt),
        ...(signature ? { 'X-Money-Signature': `sha256=${signature}` } : {}),
      },
      body,
      // 10s overall — the rest of the system shouldn't wait longer.
      signal: AbortSignal.timeout(10_000),
    });
    status = res.status;
    try {
      const text = await res.text();
      responseBody = text.slice(0, 2000);
    } catch (_) { /* ignore body read errors */ }
  } catch (err) {
    error = String(err?.message || err);
  }

  await prisma.webhookDelivery.create({
    data: {
      subscriptionId: sub.id,
      event,
      payload: body.slice(0, 16_000),
      status: status ?? null,
      responseBody: responseBody ?? null,
      error,
      attempt,
    },
  });

  // Retry on network error or 5xx.
  const ok = status != null && status >= 200 && status < 300;
  if (!ok && attempt < MAX_ATTEMPTS) {
    setTimeout(() => {
      deliverOnce(sub, event, body, attempt + 1).catch(() => {});
    }, RETRY_DELAY_MS[attempt] ?? 30_000).unref?.();
  } else if (!ok) {
    await logSystem('warn', 'webhooks', `Delivery exhausted retries for ${sub.code}`, { event, status, error });
  }
}

export async function dispatchEvent(event, payload) {
  try {
    const subs = await prisma.webhookSubscription.findMany({ where: { enabled: true } });
    const interested = subs.filter((s) => {
      try { return matches(JSON.parse(s.events || '[]'), event); }
      catch { return false; }
    });
    if (interested.length > 0) {
      const body = JSON.stringify({ event, occurredAt: new Date().toISOString(), payload });
      for (const sub of interested) {
        // fire and forget
        deliverOnce(sub, event, body, 1).catch(() => {});
      }
    }
  } catch (err) {
    await logSystem('error', 'webhooks', 'Dispatch failed', { event, error: String(err?.message || err) });
  }
  // Phase 4.17 — workflow engine subscribes to the same event funnel.
  // Late import to dodge a circular load (workflow_engine → webhooks
  // for its dispatch_event action).
  try {
    const { fireWorkflowsForEvent } = await import('./workflow_engine.js');
    await fireWorkflowsForEvent(event, payload);
  } catch (err) {
    await logSystem('error', 'workflow', 'fireWorkflowsForEvent failed', { event, error: String(err?.message || err) });
  }
}

export function fireAndForget(event, payload) {
  // Tiny wrapper so callers don't have to write the same noop catch.
  dispatchEvent(event, payload).catch(() => {});
}
