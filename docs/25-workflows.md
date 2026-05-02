# 25 — Workflows / approvals

The approvals subsystem turns the long-dormant `*.approve` permission into a real queue. Anyone can submit an approval request; only users with `<entity>.approve` (or Super Admin) can decide it.

- Page: `/approvals`
- Backend: [routes/approvals.js](../backend/src/routes/approvals.js), [lib/approvals.js](../backend/src/lib/approvals.js)
- Model: `ApprovalRequest` in [schema.prisma](../backend/prisma/schema.prisma)
- Permissions: `approvals.view`, `approvals.approve`. The decide endpoints additionally check `<entity>.approve`.

## Lifecycle

```
                 +------------+
                 |  pending   |  ← created by anyone authed
                 +------------+
                  |    |     |
       cancel by  |    | approve / reject
       requester  |    | (needs <entity>.approve)
                  v    v     v
            +-----------+  +-----------+  +-----------+
            | cancelled |  | approved  |  | rejected  |
            +-----------+  +-----------+  +-----------+
                          (terminal — cannot transition again)
```

Status values live in `lib/approvals.js`:

```js
export const STATUS = { PENDING, APPROVED, REJECTED, CANCELLED };
```

## Endpoints

| Method | Path | Permission | Notes |
|---|---|---|---|
| GET | `/api/approvals` | `approvals.view` | filters: `status`, `entity`, `requestedById`, plus `page`/`pageSize` |
| GET | `/api/approvals/pending-count` | auth | quick badge for the sidebar |
| GET | `/api/approvals/:id` | `approvals.view` | full record incl. requestedBy + decidedBy |
| POST | `/api/approvals` | auth | body: `{ entity, entityId?, title, description?, payload? }` |
| POST | `/api/approvals/:id/approve` | `<entity>.approve` (or Super Admin) | body: `{ note? }` |
| POST | `/api/approvals/:id/reject` | `<entity>.approve` (or Super Admin) | body: `{ note? }` |
| POST | `/api/approvals/:id/cancel` | requester or Super Admin | only valid while pending |

The decision endpoints look up the existing record's `entity` and check the requester has `<entity>.approve`. So a **products.approve** holder can only decide approval requests where `entity = "products"` — they can't cherry-pick across modules.

## Wire format

```json
{
  "id": 17,
  "entity": "products",
  "entityId": "412",
  "title": "Approve product price drop",
  "description": "Sale on SKU XYZ — price 99 → 79",
  "payload": { "before": { "price": 99 }, "after": { "price": 79 } },
  "status": "pending",
  "requestedById": 5,
  "requestedBy": { "id": 5, "fullName": "Alice", "username": "alice" },
  "decidedById": null,
  "decidedBy": null,
  "decisionNote": null,
  "createdAt": "2026-04-30T16:11:00.000Z",
  "decidedAt": null
}
```

`payload` is whatever JSON the requester wants to attach. The system never inspects it — it's just preserved through audit so a reviewer can see the diff.

## Audit

Every transition is audited:

| Transition | `audit_logs.action` |
|---|---|
| Created | `request` |
| Approved | `approve` |
| Rejected | `reject` |
| Cancelled | `cancel` |

The `entity` column on the audit row is `ApprovalRequest`; the `entityId` is the request id. The original entity (e.g. `products`) is in `metadata.entity`.

## Permissions seeded

The `approvals` module is registered in `seed.js` with two actions: `view` and `approve`. Default grants:

- **Super Admin** — both
- **Chairman** — `view` + `approve` (it's their job)
- **Company Admin** — both
- **Manager** — `view` + `approve` for operational modules (the per-entity check still applies)
- **Employee** — none

The per-entity gate is enforced at decide time — the global `approvals.approve` is a coarse pre-filter that lets the user *see the page*, not a free-pass to approve anything.

## Wiring to a custom workflow

To require approval before some action takes effect, the calling code creates a request and waits:

```js
// somewhere in your domain code
import { createApprovalRequest } from '../lib/approvals.js';

const req = await createApprovalRequest({
  entity: 'products',
  entityId: product.id,
  title: `Price drop on ${product.sku}`,
  description: `Reducing price from ${oldPrice} to ${newPrice}`,
  payload: { sku: product.sku, oldPrice, newPrice },
  requestedById: user.id,
});
// stash req.id on the pending record. When the approval webhook (TBD) fires,
// re-read the request — if approved, apply the change; if rejected, drop it.
```

## Webhooks (Phase 4.4)

Approval transitions automatically fire webhook events to all matching subscribers:

| Transition | Event |
|---|---|
| Created | `approval.requested` |
| Approved | `approval.approved` |
| Rejected | `approval.rejected` |
| Cancelled | `approval.cancelled` |

The payload is the same DTO the API returns. Subscribe at `/webhooks` with `events: ["approval.approved"]` (or `["*"]`) and your receiver will get an HMAC-signed `POST` whenever the event fires. See [27-webhooks.md](27-webhooks.md) for the contract, signature scheme, and retry semantics.

Polling still works if you'd rather pull (`GET /api/approvals/:id` until `status` flips), but webhooks are the recommended path for production integrations.
