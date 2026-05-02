import { Router } from 'express';
import { prisma } from '../lib/prisma.js';
import { authenticate } from '../middleware/auth.js';
import { requireSuperAdmin } from '../middleware/permission.js';
import { asyncHandler, badRequest, forbidden, notFound } from '../lib/http.js';
import { parseId, requireFields } from '../middleware/validate.js';
import { writeAudit } from '../lib/audit.js';
import { dropTable, dropJoinTable, isRelationsCol, validateTableName, diffColumns, applyColumnDiff } from '../lib/custom_entity_engine.js';
import { registerCustomEntity } from '../lib/business_presets.js';

const router = Router();

function toDto(e) {
  let cfg = { columns: [] };
  try {
    cfg = e.config ? JSON.parse(e.config) : { columns: [] };
  } catch {
    cfg = { columns: [] };
  }
  return {
    id: e.id,
    code: e.code,
    tableName: e.tableName,
    label: e.label,
    singular: e.singular,
    icon: e.icon,
    category: e.category,
    permissionPrefix: e.permissionPrefix,
    config: cfg,
    isSystem: e.isSystem,
    isActive: e.isActive,
    createdAt: e.createdAt,
    updatedAt: e.updatedAt,
  };
}

router.get(
  '/',
  authenticate,
  asyncHandler(async (_req, res) => {
    const items = await prisma.customEntity.findMany({ where: { isActive: true }, orderBy: { id: 'asc' } });
    res.json({ items: items.map(toDto) });
  }),
);

router.get(
  '/:code',
  authenticate,
  asyncHandler(async (req, res) => {
    const e = await prisma.customEntity.findUnique({ where: { code: req.params.code } });
    if (!e) throw notFound('Entity not found');
    res.json(toDto(e));
  }),
);

// Phase 4.15 #4 follow-up — pre-existing bug fix: POST/PUT/DELETE were
// routed through requireSuperAdmin() which expects req.user, but no
// authenticate middleware ran first, so the routes always 401'd.
// Latent because operators created custom entities via the Setup
// wizard / template-apply path, not direct POSTs. Adding authenticate
// in front of requireSuperAdmin matches the pattern used by every
// other route file (templates.js, pages.js, ...).
router.use(authenticate);
router.use(requireSuperAdmin());

// Phase 4.15 #4 follow-up — validate `targetEntity` on relation/relations
// columns at create/edit time. Catches typos that would otherwise silently
// produce broken refs (singular FKs storing IDs that point nowhere, M2M
// joins with no resolvable label). Self-reference (column.targetEntity ===
// entity.code being created) is allowed for cases like org trees.
//
// Only validates when `targetEntity` is set — leaving it blank is fine
// (the operator may intend to fill it in via a later edit).
async function validateRelationTargets(columns, selfCode) {
  for (const c of columns) {
    if (c?.type !== 'relation' && c?.type !== 'relations') continue;
    const target = typeof c.targetEntity === 'string' ? c.targetEntity.trim() : '';
    if (target.length === 0) continue;
    if (target === selfCode) continue; // self-ref OK
    const exists = await prisma.customEntity.findUnique({ where: { code: target } });
    if (!exists) {
      throw badRequest(`Column "${c.name}" references unknown entity "${target}". Create that entity first or fix the targetEntity.`);
    }
  }
}

router.post(
  '/',
  asyncHandler(async (req, res) => {
    requireFields(req.body, ['code', 'tableName', 'label', 'columns']);
    const { code, tableName, label, singular = label, icon = 'reports', category = 'custom', columns, createTable = true } = req.body;
    validateTableName(code);
    validateTableName(tableName);
    if (!Array.isArray(columns) || columns.length === 0) throw badRequest('columns must be a non-empty array');
    for (const c of columns) validateTableName(c.name);
    await validateRelationTargets(columns, code);

    const created = await registerCustomEntity({
      code,
      tableName,
      label,
      singular,
      icon,
      category,
      columns,
      sortOrder: 200,
      isSystem: false,
      createTable,
    });
    await writeAudit({ req, action: 'create', entity: 'CustomEntity', entityId: created.id });
    res.status(201).json(toDto(created));
  }),
);

router.put(
  '/:code',
  asyncHandler(async (req, res) => {
    const code = req.params.code;
    const existing = await prisma.customEntity.findUnique({ where: { code } });
    if (!existing) throw notFound('Entity not found');

    const { label, singular, icon, category, columns, applySchema = true } = req.body;
    const data = {};
    if (label !== undefined) data.label = label;
    if (singular !== undefined) data.singular = singular;
    if (icon !== undefined) data.icon = icon;
    if (category !== undefined) data.category = category;

    let schemaSummary = null;
    if (columns !== undefined) {
      for (const c of columns) validateTableName(c.name);
      await validateRelationTargets(columns, code);

      // Phase 4.5 — diff against current config and auto-apply ALTER TABLE.
      let oldCols = [];
      try { oldCols = (JSON.parse(existing.config || '{"columns":[]}').columns) || []; } catch { oldCols = []; }
      const diff = diffColumns(oldCols, columns);

      if (applySchema && (diff.added.length || diff.removed.length || diff.changed.length)) {
        schemaSummary = await applyColumnDiff(existing.tableName, diff);
      } else {
        schemaSummary = { ran: [], skipped: diff.changed.map((c) => ({ op: 'changeType', column: c.name, from: c.from, to: c.to, reason: 'applySchema=false' })) };
      }

      data.config = JSON.stringify({ columns });
    }
    const updated = await prisma.customEntity.update({ where: { code }, data });

    if (label !== undefined || icon !== undefined) {
      await prisma.menuItem.updateMany({
        where: { code: `menu.custom.${code}` },
        data: { label: data.label ?? existing.label, icon: data.icon ?? existing.icon },
      });
    }

    await writeAudit({ req, action: 'update', entity: 'CustomEntity', entityId: existing.id, metadata: { schema: schemaSummary } });
    res.json({ ...toDto(updated), schema: schemaSummary });
  }),
);

router.delete(
  '/:code',
  asyncHandler(async (req, res) => {
    const code = req.params.code;
    const existing = await prisma.customEntity.findUnique({ where: { code } });
    if (!existing) throw notFound('Entity not found');
    if (existing.isSystem) throw forbidden('System entities cannot be deleted from the API');

    const dropTableToo = req.query.dropTable === 'true';

    await prisma.menuItem.deleteMany({ where: { code: `menu.custom.${code}` } });
    await prisma.permission.deleteMany({ where: { module: existing.permissionPrefix } });
    await prisma.customEntity.delete({ where: { code } });
    if (dropTableToo) {
      // Drop join tables for any relations columns first — orphaned
      // join tables would otherwise stick around forever.
      let cfg = { columns: [] };
      try { cfg = JSON.parse(existing.config || '{"columns":[]}'); } catch { /* fall through */ }
      for (const c of (cfg.columns || [])) {
        if (isRelationsCol(c)) await dropJoinTable(existing.tableName, c.name);
      }
      await dropTable(existing.tableName);
    }

    await writeAudit({ req, action: 'delete', entity: 'CustomEntity', entityId: existing.id, metadata: { dropTable: dropTableToo } });
    res.json({ ok: true, droppedTable: dropTableToo });
  }),
);

export default router;
