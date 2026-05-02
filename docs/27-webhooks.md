# 27 — Webhooks

POST notifications to external URLs when system events fire. HMAC-signed, retried with backoff, every delivery recorded for audit.

- Page: `/webhooks` (Super Admin / `webhooks.*`)
- Backend: [routes/webhooks.js](../backend/src/routes/webhooks.js), [lib/webhooks.js](../backend/src/lib/webhooks.js)
- Models: `WebhookSubscription`, `WebhookDelivery` in [schema.prisma](../backend/prisma/schema.prisma)
- Permissions: `webhooks.view`, `webhooks.create`, `webhooks.edit`, `webhooks.delete`

## Supported events (today)

```
*                       — match-all
approval.requested
approval.approved
approval.rejected
approval.cancelled
webhook.test            — fired by the "Send test event" button
```

Adding a new event is a one-line change: call `fireAndForget('your.event', payload)` from the producing route and append the event code to `SUPPORTED_EVENTS` in [routes/webhooks.js](../backend/src/routes/webhooks.js).

## Subscription shape

| Field | Notes |
|---|---|
| `code` | unique slug (lowercase, snake_case) |
| `name` | display label |
| `url` | http(s) only — validated server-side |
| `secret` | auto-generated 24-byte hex if not supplied; **revealed once on create**, then redacted as `***` on every read |
| `events` | array of event codes from the supported list, or `["*"]` |
| `enabled` | toggle without deleting |

## Wire format

Every delivery is a `POST` to the subscriber URL with:

```
Content-Type:    application/json
X-Money-Event:   <event-code>
X-Money-Attempt: <1..3>
X-Money-Signature: sha256=<hmac>
```

Body:

```json
{
  "event": "approval.approved",
  "occurredAt": "2026-04-30T18:55:00.000Z",
  "payload": { /* matches the relevant DTO */ }
}
```

The HMAC is computed as `HMAC-SHA256(secret, body)` over the raw bytes of the JSON-stringified body. To verify on the receiver:

```js
import crypto from 'node:crypto';

const expected = 'sha256=' + crypto
  .createHmac('sha256', SECRET)
  .update(rawBodyBuffer)   // not the parsed JSON — raw bytes
  .digest('hex');

if (expected !== req.headers['x-money-signature']) reject();
```

## Retries

If the response is a network error or HTTP 5xx, the dispatcher retries up to **3 attempts total** with backoff: immediate → 5 s → 30 s. Each attempt writes its own `WebhookDelivery` row (with the `attempt` number). 4xx responses are recorded but **not retried** — they indicate a permanent receiver-side error.

Timeout per attempt: **10 seconds** (via `AbortSignal.timeout`).

The dispatch is fire-and-forget — the call site does not await it, so producing routes return immediately even if a subscriber is slow.

## Delivery history

`GET /api/webhooks/:id/deliveries?page=1&pageSize=50` returns the most recent attempts, including HTTP status, the truncated response body, and any error. The UI exposes this via the **history** icon on each subscription row.

## Endpoints

| Method | Path | Permission |
|---|---|---|
| GET | `/api/webhooks` | `webhooks.view` |
| GET | `/api/webhooks/events` | auth — canonical event list |
| GET | `/api/webhooks/:id` | `webhooks.view` (secret redacted) |
| POST | `/api/webhooks` | `webhooks.create` (secret revealed once) |
| PUT | `/api/webhooks/:id` | `webhooks.edit` (rotate secret by passing `secret`) |
| DELETE | `/api/webhooks/:id` | `webhooks.delete` |
| POST | `/api/webhooks/:id/test` | `webhooks.edit` — dispatches a synthetic `webhook.test` event |
| GET | `/api/webhooks/:id/deliveries` | `webhooks.view` |

## Operational notes

- **Secrets are stored plaintext in the DB.** They are never returned over the API after creation. Treat the DB the same way you treat `.env`.
- **The receiver should be idempotent.** A 502 in the middle of a 200 means you may legitimately receive the same event up to 3 times (with different `X-Money-Attempt` headers).
- **No queue.** Delivery is in-process. If the API process restarts mid-retry, the in-flight retries are lost — but the original delivery row is preserved with whatever status was reached.
- **No fan-out throttling.** A subscription wired to `*` will receive every event. Plan the receiver accordingly.

## Quickstart — listening on Node

```js
import express from 'express';
import crypto from 'node:crypto';

const app = express();
app.post('/hook', express.raw({ type: 'application/json' }), (req, res) => {
  const sig = 'sha256=' + crypto.createHmac('sha256', process.env.SECRET).update(req.body).digest('hex');
  if (sig !== req.headers['x-money-signature']) return res.status(401).end();
  const event = JSON.parse(req.body.toString());
  console.log(event.event, event.payload);
  res.status(204).end();
});
app.listen(3001);
```

## Verifying from non-Node receivers

Reference helpers for Python, Go, PHP, and Bash live under
[`tools/webhook-verify/`](../tools/webhook-verify/). Each is stdlib-only
(no package-manager step), each ships its own per-language unit test, and
all four implement the same `verify(rawBody, signatureHeader, secret) →
bool` interface using language-native constant-time compares (with one
caveat for the bash helper, documented in its source).

A cross-language test at
[`backend/tests/webhook_verify_helpers.test.js`](../backend/tests/webhook_verify_helpers.test.js)
generates a known-good body+signature using the same crypto path the
dispatcher uses, then spawns each helper as a subprocess and checks the
exit code. Helpers whose toolchain isn't installed are skipped, so a
Node-only dev box still gets the helpers it can run.

See [tools/webhook-verify/README.md](../tools/webhook-verify/README.md)
for per-language quickstarts and instructions for adding a new language.
