# 29 — Approval claim handlers

Server-side hook so domain code can react to approval decisions **inside this process**, with synchronous Prisma access and transactional control. Webhooks ([27-webhooks.md](27-webhooks.md)) cover external receivers; claim handlers cover the domain logic that needs to stay in-process.

- Lib: [backend/src/lib/approval_handlers.js](../backend/src/lib/approval_handlers.js)
- Wired from: [backend/src/routes/approvals.js](../backend/src/routes/approvals.js) — `runHandlers(decision, dto)` is awaited inside the decide endpoints, **before** the HTTP response returns.

## When to use a handler vs a webhook

| Use a **handler** when… | Use a **webhook** when… |
|---|---|
| You need transactional control over a Prisma mutation that should accompany the decision | Another service / Slack / a third-party SaaS needs to know |
| The action must complete before the HTTP response returns to the user | The action is fire-and-forget and may be slow |
| You need access to the `prisma` client | The receiver may live in a different process / language |

Both fire for the same decision — they are complementary.

## Registering

```js
// backend/src/lib/business_handlers.js (your code)
import { prisma } from './prisma.js';
import { registerApprovalHandler } from './approval_handlers.js';

registerApprovalHandler('products', async ({ decision, request }) => {
  if (decision !== 'approved') return;
  const sku = request.payload?.sku;
  const newPrice = request.payload?.newPrice;
  if (!sku || newPrice == null) return;
  await prisma.$executeRawUnsafe(
    'UPDATE products SET price = $1 WHERE sku = $2',
    newPrice,
    sku,
  );
}, 'products-price-update');
```

Then import that module once at boot (e.g. from `server.js`) so the registration runs.

## Lifecycle

| Hook | Fires when |
|---|---|
| Handler with `entity = "products"` | `POST /api/approvals/:id/approve` (or `/reject`) flips the row to its new status, AFTER the audit log is written and BEFORE the response returns |

The decide endpoint awaits `runHandlers(decision, dto)`. If a handler throws, its name + error message are returned in the result and logged via `logSystem('warn', 'approval_handlers', …)`. **Other handlers continue running** — one bad handler doesn't break the chain.

## API

```js
import {
  registerApprovalHandler,    // (entity, fn, name?) → void
  unregisterApprovalHandler,  // (entity, fn) → void
  listHandlers,               // () → { entity: [name, ...], ... }
  runHandlers,                // (decision, dto) → { ran, errors }
} from '../lib/approval_handlers.js';
```

## Tests

`tests/approval_handlers.test.js` covers:

- handler runs for matching entity
- handler does not run for non-matching entity
- one bad handler doesn't break the chain (good handler still runs, bad one's error is captured)
- `listHandlers()` returns names per entity
- bad arguments throw

## Caveats

- **In-process only.** Handlers don't survive a process restart — re-registration runs on every boot, so put the calls in startup code, not in lazy paths.
- **No retry.** If a handler throws, the decision is still committed; the side-effect simply didn't happen. Use webhooks (which retry) when you need delivery guarantees, or write your own retry queue.
- **Don't await long.** The decide endpoint awaits handlers. Keep them short. For long-running side effects, enqueue a job and return.
