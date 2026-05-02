# 48 — Workflow engine (Phase 4.17)

> **Naming note.** [25-workflows.md](25-workflows.md) covers the *approvals queue* (`ApprovalRequest`), which predates the engine and uses the word "workflow" in the human sense. This document covers the **automation engine** — definitions, triggers, action chains, runs. The two are complementary: an action in this engine can *create* an approval request, and an `approval.approved` event can be *consumed by* an engine trigger.

## Goal

Let an admin define automation that runs in response to system events without writing code. A v1 that ships with three trigger types and six action types is enough to cover ~80% of what customers ask for ("when X happens, do Y") and is built on infrastructure that already exists.

## Design constraints

1. **Reuse, don't reinvent.** The system already has:
   - `lib/webhooks.js#dispatchEvent` — a fan-out funnel (5 events wired today).
   - `lib/cron.js` — multi-instance-safe scheduled job runner with stale-lock recovery.
   - `lib/custom_entity_engine.js#insertRow|updateRow|deleteRow` — the only mutation path for custom records.
   - `lib/formula.js` — a safe-eval expression engine (used by formula columns).
   - `lib/audit.js#writeAudit` — uniform audit log.
   - `lib/templates.js#applyTemplateData` — template-import hook for new resource types.

   The engine plugs into all six. Nothing about it lives outside the existing patterns.

2. **No async queue.** v1 fires actions synchronously after the trigger, like `dispatchEvent` already does for webhook deliveries. Adding a job runner is its own infrastructure project; without it, action chains are bounded by request-time budget but stay observable through `WorkflowRun` rows. If a customer needs 30-minute pipelines they should stage with HTTP webhooks for now.

3. **Admin-defined automation runs with system privilege.** Workflows execute outside the request user's permission scope, like cron. The user that *fired* the trigger already passed their permission check (e.g. `<entity>.create` to insert a record); the workflow is the admin's standing instruction about what *also* happens after that.

4. **Subsystem build & template portable.** The `workflows` route gets a `// MOD: workflows` marker so the build-subsystem pruner can drop it for templates that don't include the module. `applyTemplateData` learns to import workflow definitions, the same way it does webhook subscriptions.

## Triggers (v1)

| Type | When it fires | Config keys |
|---|---|---|
| `record` | Every `insertRow` / `updateRow` / `deleteRow` against any custom entity | `entity` (code), `on` (subset of `["created","updated","deleted"]`), optional `filter` (condition DSL — see below) |
| `event` | Every `dispatchEvent` call, including built-in events (`approval.*`, `backup.created`) and any future ones | `event` (string, must be in `SUPPORTED_EVENTS` or `*`) |
| `schedule` | Cron tick claims a due workflow, like `ReportSchedule` | `frequency` + same shape as `ReportSchedule` (`every_minute`, `every_5_minutes`, `hourly`, `daily`, `weekly`, `monthly`, `cron`) |
| `webhook` (v2) | External `POST /api/workflows/incoming/:code` arrives with a matching `X-Workflow-Secret` header | `secret` (string, auto-generated server-side on create when omitted; constant-time compared) |

Page-button triggers (v2) reuse the manual-run path (`POST /api/workflows/by-code/:code/run`) instead of adding a fourth trigger type — the page-builder `button` block carries `workflowCode` + optional `workflowPayload` in its config.

### Trigger payload shape

What the trigger handler hands the action runner as `context.trigger`:

```jsonc
// record
{ "kind": "record", "entity": "leads", "op": "created",
  "row": { "id": 17, "name": "...", ... },
  "before": null }                            // populated for update/delete

// event
{ "kind": "event", "event": "approval.approved",
  "payload": { ... } }                        // whatever dispatchEvent was called with

// schedule
{ "kind": "schedule", "firedAt": "2026-05-02T11:00:00.000Z" }
```

## Actions (v1)

| Type | What it does | Params |
|---|---|---|
| `set_field` | Update fields on a custom record | `entity`, `id` (number or template), `fields` (object) |
| `create_record` | Insert a row in a custom entity | `entity`, `fields` (object) |
| `http_request` | Outbound HTTP, with retries off (one shot — webhooks are the right tool for retries) | `method`, `url`, `headers?`, `body?` (object → JSON, or string passthrough) |
| `dispatch_event` | Fire `dispatchEvent` so other workflows / webhooks can chain | `event` (string), `payload` (object) |
| `create_approval` | Create an `ApprovalRequest` | `entity`, `entityId?`, `title`, `description?`, `payload?` |
| `log` | Write a `SystemLog` row, for debugging chains | `level` (`info`/`warn`/`error`), `message`, `context?` (object) |
| `notify_user` (Phase 4.18) | Create an in-app notification for a single user. Resolves target by `userId` \| `username` \| `email` (first match wins); fails the step if no user resolves | `userId?`, `username?`, `email?`, `kind?` (default `'workflow'`), `title`, `body?`, `link?` (in-app route) |
| `send_email` (Phase 4.19) | Send an outbound email via SMTP. Step succeeds with `stubbed:true` when SMTP isn't configured (so chain composition stays non-fatal in dev installs); set `BAIL_ON_NO_SMTP=1` in env to make it fail loudly instead | `to` (string or array), `subject`, `text?`, `html?` (at least one body), `from?` (defaults to env `SMTP_FROM`) |

Deferred: run_sql (admin gun, want to think hard about this one), send_slack (use `http_request` for now), broadcast notifications (notify-by-role) — exposed in `lib/notifications.js#notifyRole` for direct callers but not yet through the workflow action. Scheduled-report email digest is also deferred — `ReportSchedule` would need a `recipients` JSON field + cron-loop email send + UI to manage subscribers; the work isn't trivial enough to bolt on the SMTP commit.

### Conditional logic

Every action takes optional `condition` — a formula string evaluated by `lib/formula.js` against the action context. Falsy → step is **skipped**, not failed. This covers "if X then Y" without a separate branching primitive. Full if/else trees are deferred to v2 — at that point the natural shape is a DAG, not a list, and the storage model changes.

### Templating

Action params support `{{path.to.value}}` substitution against context, e.g. `"id": "{{trigger.row.id}}"` or `"url": "https://api.example.com/leads/{{trigger.row.email}}"`. Substitution is string-level only (the path resolves to a value, then is stringified). For object/array passthrough use the literal value — params are JSON, not template strings.

Full Jinja-style templating (loops, conditionals inside templates) is deferred. If an action param needs a non-trivial transformation, write a `set_field` first to compute it into a row column, then read that column.

### Action chain semantics

Actions run in order. Each step writes a `WorkflowRunStep` row. Default behavior on action failure: **continue** to next step, mark the step `failed`, mark the run `failed` at end. Per-action `stopOnError: true` flips to hard-stop on that step. Rationale: if you have a "log a failure to Slack" final step, you don't want a transient earlier failure to skip it.

## Storage model

```prisma
model Workflow {
  id            Int      @id @default(autoincrement())
  code          String   @unique
  name          String
  description   String?
  triggerType   String   // 'record' | 'event' | 'schedule'
  triggerConfig String   @default("{}")
  actions       String   @default("[]")   // JSON array of {type,name?,condition?,stopOnError?,params}
  enabled       Boolean  @default(true)
  // schedule-specific (null when triggerType != 'schedule')
  nextRunAt     DateTime?
  lastRunAt     DateTime?
  lockedBy      String?
  lockedAt      DateTime?
  createdAt     DateTime @default(now())
  updatedAt     DateTime @updatedAt
  runs          WorkflowRun[]

  @@index([triggerType])
  @@index([enabled])
  @@index([nextRunAt])
  @@index([lockedAt])
}

model WorkflowRun {
  id             Int      @id @default(autoincrement())
  workflowId     Int
  triggerEvent   String           // 'record.created' | 'approval.approved' | 'schedule' | etc.
  triggerPayload String?          // JSON, capped at 16k
  status         String           // 'running' | 'success' | 'failed'
  startedAt      DateTime @default(now())
  finishedAt     DateTime?
  error          String?          // first failure message
  workflow       Workflow @relation(fields: [workflowId], references: [id], onDelete: Cascade)
  steps          WorkflowRunStep[]

  @@index([workflowId])
  @@index([status])
  @@index([startedAt])
}

model WorkflowRunStep {
  id          Int      @id @default(autoincrement())
  runId       Int
  index       Int
  actionType  String
  actionName  String?
  status      String   // 'success' | 'failed' | 'skipped'
  result      String?           // JSON, capped at 4k
  error       String?
  startedAt   DateTime @default(now())
  finishedAt  DateTime?
  run         WorkflowRun @relation(fields: [runId], references: [id], onDelete: Cascade)

  @@index([runId])
}
```

The schedule-state columns sit on `Workflow` (not in a side table) intentionally — atomic claim is a single `updateMany` against `lockedBy IS NULL OR lockedAt < cutoff`, identical to `ReportSchedule`. Workflows whose `triggerType != 'schedule'` simply never qualify.

Run + Step is two tables (mirrors `ScheduledReportRun` / `WebhookDelivery` patterns) so per-action observability is cheap to query without unpacking JSON.

## Wiring

### `record.*` triggers

`lib/custom_entity_engine.js` already centralizes all custom-record mutations. Add a single hook at the bottom of each:

```js
// insertRow → end of function
fireWorkflowsForRecord(entity, 'created', created, null);

// updateRow → after fetching the post-update row
fireWorkflowsForRecord(entity, 'updated', updated, before);

// deleteRow → before purge
fireWorkflowsForRecord(entity, 'deleted', null, doomed);
```

`fireWorkflowsForRecord` is fire-and-forget (matches `dispatchEvent`). It also calls `dispatchEvent('record.created', ...)` etc., so webhooks subscribers see the same events.

### `event.*` triggers

In `lib/webhooks.js#dispatchEvent`, after the existing webhook fan-out, also call `fireWorkflowsForEvent(event, payload)`. Workflows and webhooks share the same event funnel.

### `schedule` triggers

In `lib/cron.js#claimAndRun`, add a second pass that runs the same atomic-claim pattern against `Workflow` where `triggerType = 'schedule' AND enabled AND (nextRunAt IS NULL OR nextRunAt <= now)`. Reuse `computeNext` directly (the field set already matches).

## Permissions

Add `workflows` module with actions `view`, `create`, `edit`, `delete`, `run`. Default grants:

| Role | Default |
|---|---|
| Super Admin | all |
| Chairman | `view` |
| Company Admin | all |
| Manager | `view`, `run` |
| Employee | none |

Workflow execution itself is **system-privileged** (bypasses row-level checks) — it's an admin's standing instruction. The `workflows.run` permission is for the manual "Run now" button only.

## API surface

| Method | Path | Permission | Notes |
|---|---|---|---|
| GET | `/api/workflows` | `workflows.view` | list + paginate |
| GET | `/api/workflows/:id` | `workflows.view` | full record |
| GET | `/api/workflows/triggers` | auth | enumerate trigger types + supported events for the editor |
| POST | `/api/workflows` | `workflows.create` | body: `{code, name, triggerType, triggerConfig, actions, enabled?}` |
| PUT | `/api/workflows/:id` | `workflows.edit` | partial update; recomputes `nextRunAt` if schedule fields changed |
| DELETE | `/api/workflows/:id` | `workflows.delete` | cascades runs + steps |
| POST | `/api/workflows/:id/run` | `workflows.run` | manual fire with synthetic `{kind:"manual"}` trigger payload |
| POST | `/api/workflows/by-code/:code/run` (v2) | `workflows.run` | same as `/:id/run` but resolves by `code` — used by page-button triggers |
| POST | `/api/workflows/incoming/:code` (v2) | **public** — `X-Workflow-Secret` matched against the workflow's `triggerConfig.secret` | external systems fire a `webhook`-trigger workflow; mounted before the authenticate middleware |
| GET | `/api/workflows/:id/runs` | `workflows.view` | paginated run history |
| GET | `/api/workflows/runs/:runId` | `workflows.view` | run + steps |

## Templates portability

`applyTemplateData(data)` learns to import `data.workflows` as a list of `Workflow` rows. Captured templates also include workflow definitions, so a "Customer X" subsystem build ships with their automation pre-installed.

## Frontend (v1)

Single `/workflows` page (mirrors `/webhooks`), sections:
- **List** — all workflows with enable toggle, trigger summary, last run status badge.
- **Edit modal** — `code` / `name` / `description` / trigger picker (with conditional sub-form) / actions JSON editor.
- **Runs panel** — per-workflow drill-in to recent runs, expanding to show each step.

The visual chain builder (drag-and-drop actions, condition tree UI) is **v2** — v1 is JSON-edited. Authoring UX is acceptable for power users; v2 unlocks it for everyone.

## Test strategy

- **Unit**
  - Template substitution (`{{trigger.row.id}}` etc., missing path → empty, type-preserving for whole-string templates).
  - Condition evaluation (truthy/falsy).
  - Each action handler in isolation with a stubbed Prisma.
- **Integration**
  - `record.created` with matching filter → workflow fires; with non-matching filter → skipped.
  - `record.updated` provides `trigger.before` and `trigger.row`.
  - `event` trigger fires from real `dispatchEvent`.
  - Schedule trigger claimed by cron tick (mock time), runs once, sets `nextRunAt`.
  - Action chain runs in order; step `n+1` can read step `n`'s result via `{{steps.<name>.id}}`.
  - Failed step continues by default; `stopOnError: true` halts the chain.
  - Multi-instance lock: two workers, only one claims a due schedule.
- **Routes**
  - CRUD; permission rejection for missing roles; manual-run endpoint requires `workflows.run`.

## Phasing

- **v1 (2026-05-02)** — schema + engine + 3 triggers + 6 actions + JSON-editor UI + tests + template portability.
- **v2 (2026-05-02, same day)** — visual chain builder (replaces JSON editor; raw JSON kept behind an "Advanced" toggle), `webhook` trigger type with per-workflow shared secret on `X-Workflow-Secret` (public route `POST /api/workflows/incoming/:code` mounted before authenticate), page-button trigger via `PageBlock` `button` config (`workflowCode` + optional `workflowPayload`, runs through `POST /api/workflows/by-code/:code/run`).
- **v3 (deferred)** — `send_email` action (needs SMTP infra), if/else action trees (storage shape changes from list to DAG), async job runner + parallel branches, retry policy per HTTP action, workflow-to-workflow chaining via shared queue, fully-visual nested-condition builder beyond depth 3.
