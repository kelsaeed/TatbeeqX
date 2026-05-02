# 47 — Custom-entity relations

How relation columns work in the custom-entity engine. Phase 4.15 #4 shipped the M2M (`relations`, plural) flavor; the singular `relation` (1-FK) has been around since Phase 3 but documenting the whole model in one place because the two flavors share semantics that aren't obvious from the code alone.

## TL;DR

- Two relation flavors: `relation` (single FK, INTEGER on the source table) and `relations` (many-to-many, separate join table).
- Both store `targetEntity` (a custom-entity code) on the column config.
- Both are **soft refs** by default — losing a target doesn't delete sources. `relations` empties the join row, `relation` sets the column to NULL.
- `targetEntity` is validated at column-create / column-edit time; typos are rejected with a 400.

## `relation` (singular FK)

A single foreign key to one row in another entity. Stored as an `INTEGER` column on the source table.

### Column config

```json
{
  "name": "assignee",
  "label": "Assigned To",
  "type": "relation",
  "targetEntity": "users",
  "required": false
}
```

### Storage

```sql
-- on the source table
"assignee" INTEGER  -- nullable; holds the target row's id
```

### Read / write

- **Write:** `body.assignee = 42` — same shape as any integer column.
- **Read:** `row.assignee = 42` — same shape.

### When the target is deleted

`engine.nullifyDanglingSingleRelations(targetCode, targetId)` walks every custom entity, finds `relation` columns whose `targetEntity` matches, and runs `UPDATE … SET col = NULL WHERE col = targetId`. Source rows survive — only the column goes null.

This is the **right default** for soft refs (e.g. `orders.assignedTo → users`: deleting a user shouldn't delete their orders). Operators wanting hard cascade can layer a SQL trigger.

## `relations` (many-to-many)

Multiple foreign keys to rows in another entity. Stored in a separate join table — **not** as a column on the source table.

### Column config

```json
{
  "name": "tags",
  "label": "Tags",
  "type": "relations",
  "targetEntity": "tag_pool"
}
```

### Storage

A join table is auto-created on entity registration:

```sql
CREATE TABLE IF NOT EXISTS "products__tags__rel" (
  "source_id" INTEGER NOT NULL,
  "target_id" INTEGER NOT NULL,
  "created_at" TEXT DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY ("source_id", "target_id")
);
CREATE INDEX IF NOT EXISTS "products__tags__rel_target_idx"
  ON "products__tags__rel" ("target_id");
```

The naming convention is `<source_table>__<column_name>__rel`. The reverse-lookup index (`_target_idx`) keeps the "which sources reference target N" query cheap.

### Read / write

- **Write:** `body.tags = [3, 7, 11]` — array of target IDs. The engine diffs against the existing join rows and INSERTs / DELETEs as needed.
- **Read:** `row.tags = [3, 7, 11]` — array of target IDs, batch-fetched per page (one query per relations column per `listRows()` call — no N+1).

### When a target ID doesn't exist

`engine.filterExistingTargetIds(targetCode, ids)` is called before every relations write. IDs that don't exist in the target table are dropped silently and a warn-level system_log entry is emitted (UI may have raced a delete on the target side; rejecting the whole write would be brittle).

### When the source is deleted

`engine.deleteAllRelationsFor(entity, sourceId)` purges all join rows where `source_id` matches. Runs in `deleteRow()` before the source-table DELETE.

### When the target is deleted

`engine.reverseCascadeRelations(targetCode, targetId)` walks every custom entity, finds `relations` columns whose `targetEntity` matches, and runs `DELETE FROM <join> WHERE target_id = ?`. Source rows survive — only the join rows go.

## Lifecycle of a relations column

| Operator action | What happens |
|---|---|
| Add `relations` column at entity create | Source-table SQL skips this column; join table created in `registerCustomEntity()` |
| Add `relations` column on existing entity | `applyColumnDiff()` routes `add` through `buildJoinTableSQL()` (not ALTER TABLE) |
| Drop `relations` column | `applyColumnDiff()` routes `drop` through `dropJoinTable()`; existing source rows untouched, but their join data is gone |
| Drop entire entity with `?dropTable=true` | All join tables for any `relations` columns dropped before the source table |
| `ensureTable()` on partial restore | Always runs `ensureJoinTables()` (idempotent) so a partial DB restore doesn't leave the source table reconstructed but the join table missing |

## `targetEntity` validation

Phase 4.15 #4 follow-up. At entity create / edit time, `validateRelationTargets(columns, selfCode)`:

- Fires for both `relation` and `relations` columns.
- Skips when `targetEntity` is empty (operator may fill it later).
- Allows self-reference (`column.targetEntity === entity.code` being created — used for org-tree patterns).
- Otherwise checks `prisma.customEntity.findUnique({ where: { code: targetEntity } })`. If absent, returns `400 Column "<col>" references unknown entity "<target>". Create that entity first or fix the targetEntity.`

## Frontend

[`custom_entity_form.dart`](../frontend/lib/features/custom_entities/presentation/custom_entity_form.dart) — adding a `relation` or `relations` column shows a `targetEntity` text input. (No autocomplete yet; v2 candidate.)

[`custom_record_dialog.dart`](../frontend/lib/features/custom/presentation/custom_record_dialog.dart) — for `relations` columns, renders `_RelationsField`: lazy-fetches `/c/<target>?pageSize=200` on first build, shows selected as chips with name resolution (`name` → `label` → `title` → `#id` fallback), popup-menu add for unselected rows, retry on load failure.

## Performance notes

- `listRows()` does one query per relations column per page (batch-fetch by `source_id IN (...)`). For a page of 25 rows × 3 relations columns, that's 4 queries total (1 main + 3 batched).
- `getRow()` does one query per relations column for the single source row.
- `deleteRow()` is O(N entities) — walks `customEntities` to find reverse-cascade targets. Fine for typical < 50-entity deployments. If it ever shows in a profile, a "relations index" (target_code → list of (sourceEntity, columnName) pointing at it) would turn it into a single targeted lookup.

## v1 limitations (open follow-ups)

- **No name-resolution autocomplete** in the form's `targetEntity` field. Operators must remember entity codes. v2 candidate: dropdown populated from `/api/custom-entities`.
- **No reverse-relation listing** in the target entity's UI. If you have `orders` with a relation to `customers`, the customer's record page doesn't show "orders by this customer." Would need a "show inverse relations" feature.
- **No labels in list responses.** `listRows()` returns `tags: [3, 7, 11]`, not `tags: [{id:3, name:"hot"}, ...]`. The frontend `_RelationsField` resolves names by fetching the target list separately. Acceptable for current page sizes; would want server-side join for large catalogs.
