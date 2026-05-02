import { prisma } from './prisma.js';
import { logSystem } from './system_log.js';
import { compileFormula, evalFormula } from './formula.js';
import { hasPermission } from './permissions.js';
import { fireWorkflowsForRecord } from './workflow_engine.js';

const TYPE_TO_SQLITE = {
  text: 'TEXT',
  longtext: 'TEXT',
  integer: 'INTEGER',
  number: 'REAL',
  bool: 'INTEGER',
  date: 'TEXT',
  datetime: 'TEXT',
  relation: 'INTEGER',
  // `relations` (plural) is many-to-many — backed by an auto-managed join
  // table, NOT a column on the source table. See joinTableName() and
  // ensureJoinTables() below. Anywhere we map config columns → SQL
  // columns we filter relations out via isRelationsCol().
};

export const RELATIONS_TYPE = 'relations';
export function isRelationsCol(c) {
  return c?.type === RELATIONS_TYPE;
}

// Phase 4.16 follow-up — field-level permissions on custom-entity
// columns. Optional `viewPermission` / `editPermission` permission
// codes on a column gate that column for non-super-admin callers:
//
//   { name: 'salary', type: 'number', viewPermission: 'finance.read' }
//
// Read path strips columns where caller lacks viewPermission.
// Write path silently drops body fields where caller lacks
// editPermission. If a column has viewPermission but no
// editPermission, edit defaults to view (you can't edit what you
// can't read — keeps semantics clean).
//
// `ctx` is optional. Internal callers (registerCustomEntity,
// applyTemplateData, tests, scripts) pass nothing → no filtering.
// Routes pass `{ permissions: req.permissions, isSuperAdmin:
// req.user.isSuperAdmin }`.
export function canViewCol(col, ctx) {
  if (!col?.viewPermission) return true;
  if (!ctx) return true;
  if (ctx.isSuperAdmin) return true;
  return hasPermission(ctx.permissions, col.viewPermission);
}

export function canEditCol(col, ctx) {
  const code = col?.editPermission ?? col?.viewPermission;
  if (!code) return true;
  if (!ctx) return true;
  if (ctx.isSuperAdmin) return true;
  return hasPermission(ctx.permissions, code);
}

function stripRestrictedFromRow(row, cols, ctx) {
  if (!row || !ctx || ctx.isSuperAdmin) return row;
  const out = { ...row };
  for (const c of cols) {
    if (!canViewCol(c, ctx)) delete out[c.name];
  }
  return out;
}

function filterEditableBody(body, cols, ctx) {
  if (!body || !ctx || ctx.isSuperAdmin) return body;
  const out = { ...body };
  for (const c of cols) {
    if (!canEditCol(c, ctx)) delete out[c.name];
  }
  return out;
}

// Phase 4.16 follow-up — `formula` columns are virtual (no SQL column,
// no storage), evaluated at read time against the row's other columns.
// See lib/formula.js for the safe evaluator.
export const FORMULA_TYPE = 'formula';
export function isFormulaCol(c) {
  return c?.type === FORMULA_TYPE;
}

// Apply formula columns to a single row, mutating it in place. Bad
// formulas (parse error / unknown field / divide-by-zero) yield null
// rather than crashing — operators see the missing value and can fix
// the expression.
function applyFormulasToRow(row, formulaCols) {
  for (const c of formulaCols) {
    try {
      const ast = compileFormula(c.formula);
      row[c.name] = evalFormula(ast, row);
    } catch (_) {
      row[c.name] = null;
    }
  }
}

// Naming convention: <source>__<col>__rel. Double underscores keep the
// structure visible in DB browsers and avoid colliding with normal
// snake_case column/table names. Component validation is handled at
// entity-create time (validateTableName + validateIdent), so by the
// time we get here both pieces are safe.
export function joinTableName(sourceTable, columnName) {
  return `${sourceTable}__${columnName}__rel`;
}

export function buildJoinTableSQL(sourceTable, columnName) {
  validateTableName(sourceTable);
  validateTableName(columnName);
  const tn = joinTableName(sourceTable, columnName);
  return `CREATE TABLE IF NOT EXISTS ${quoteIdent(tn)} (` +
    `"source_id" INTEGER NOT NULL,` +
    `"target_id" INTEGER NOT NULL,` +
    `"created_at" TEXT DEFAULT CURRENT_TIMESTAMP,` +
    `PRIMARY KEY ("source_id", "target_id")` +
    `)`;
}

export async function ensureJoinTables(entity) {
  let config;
  try { config = JSON.parse(entity.config); } catch { return; }
  const cols = Array.isArray(config?.columns) ? config.columns : [];
  for (const c of cols) {
    if (!isRelationsCol(c)) continue;
    await prisma.$executeRawUnsafe(buildJoinTableSQL(entity.tableName, c.name));
    // Reverse-lookup index — cheap, lets us do "which sources reference target N".
    await prisma.$executeRawUnsafe(
      `CREATE INDEX IF NOT EXISTS ${quoteIdent(`${joinTableName(entity.tableName, c.name)}_target_idx`)} ` +
        `ON ${quoteIdent(joinTableName(entity.tableName, c.name))} ("target_id")`,
    );
  }
}

export async function dropJoinTable(sourceTable, columnName) {
  await prisma.$executeRawUnsafe(`DROP TABLE IF EXISTS ${quoteIdent(joinTableName(sourceTable, columnName))}`);
}

async function getRelationIdsBatch(sourceTable, columnName, sourceIds) {
  if (!sourceIds || sourceIds.length === 0) return new Map();
  const tn = quoteIdent(joinTableName(sourceTable, columnName));
  const placeholders = sourceIds.map(() => '?').join(',');
  const rows = await prisma.$queryRawUnsafe(
    `SELECT source_id, target_id FROM ${tn} WHERE source_id IN (${placeholders}) ORDER BY source_id, target_id`,
    ...sourceIds.map((id) => Number(id)),
  );
  const out = new Map();
  for (const r of rows) {
    const sid = Number(r.source_id);
    const tid = Number(r.target_id);
    if (!out.has(sid)) out.set(sid, []);
    out.get(sid).push(tid);
  }
  return out;
}

async function setRelationIds(sourceTable, columnName, sourceId, targetIds) {
  const tn = quoteIdent(joinTableName(sourceTable, columnName));
  const sid = Number(sourceId);
  const wantSet = new Set((Array.isArray(targetIds) ? targetIds : [])
    .map((v) => Number(v))
    .filter((v) => Number.isFinite(v) && v > 0));

  const existing = await prisma.$queryRawUnsafe(
    `SELECT target_id FROM ${tn} WHERE source_id = ?`,
    sid,
  );
  const haveSet = new Set(existing.map((r) => Number(r.target_id)));

  const toInsert = [...wantSet].filter((v) => !haveSet.has(v));
  const toRemove = [...haveSet].filter((v) => !wantSet.has(v));

  for (const tid of toInsert) {
    await prisma.$executeRawUnsafe(
      `INSERT OR IGNORE INTO ${tn} (source_id, target_id) VALUES (?, ?)`,
      sid, tid,
    );
  }
  if (toRemove.length > 0) {
    const placeholders = toRemove.map(() => '?').join(',');
    await prisma.$executeRawUnsafe(
      `DELETE FROM ${tn} WHERE source_id = ? AND target_id IN (${placeholders})`,
      sid, ...toRemove,
    );
  }
}

async function deleteAllRelationsFor(entity, sourceId) {
  let config;
  try { config = JSON.parse(entity.config); } catch { return; }
  const cols = Array.isArray(config?.columns) ? config.columns : [];
  for (const c of cols) {
    if (!isRelationsCol(c)) continue;
    await prisma.$executeRawUnsafe(
      `DELETE FROM ${quoteIdent(joinTableName(entity.tableName, c.name))} WHERE source_id = ?`,
      Number(sourceId),
    );
  }
}

// Phase 4.15 follow-up — reverse cascade. When a target row is deleted,
// any source rows in OTHER entities that reference it via a `relations`
// column would otherwise keep dangling target_ids. Walk every custom
// entity, find relations columns whose `targetEntity` matches the
// deleted entity's code, and purge matching join rows.
//
// O(N) entities × per-call query — fine for typical < 50-entity
// deployments. If this ever shows up in a profile, a "relations index"
// (entity → list of (sourceEntity, columnName) pointing at it) would
// turn this into a single targeted lookup.
export async function reverseCascadeRelations(deletedEntityCode, deletedId) {
  if (!deletedEntityCode) return { cleared: 0 };
  const entities = await prisma.customEntity.findMany();
  let cleared = 0;
  for (const ent of entities) {
    let cfg;
    try { cfg = JSON.parse(ent.config); } catch { continue; }
    const cols = Array.isArray(cfg?.columns) ? cfg.columns : [];
    for (const c of cols) {
      if (!isRelationsCol(c)) continue;
      if (c.targetEntity !== deletedEntityCode) continue;
      const jt = quoteIdent(joinTableName(ent.tableName, c.name));
      const result = await prisma.$executeRawUnsafe(
        `DELETE FROM ${jt} WHERE target_id = ?`,
        Number(deletedId),
      );
      cleared += Number(result || 0);
    }
  }
  return { cleared };
}

// Phase 4.15 #4 follow-up — symmetry with reverseCascadeRelations, but
// for the singular `relation` column type (single FK stored as INTEGER
// on the source table). When the target row is deleted, source rows
// across all entities with a matching `relation` column point at a
// non-existent ID — set those columns to NULL.
//
// Why NULL and not delete the source rows? A `relation` is a soft
// reference, not a parent-child constraint. Many real-world cases
// (e.g. orders.assignedTo → users) want the source to survive losing
// its target. Operators who want hard delete-on-cascade can layer
// their own SQL trigger; the engine's default is the conservative
// "loose link" semantics already implied by storing them as nullable
// integers.
export async function nullifyDanglingSingleRelations(deletedEntityCode, deletedId) {
  if (!deletedEntityCode) return { nulled: 0 };
  const entities = await prisma.customEntity.findMany();
  let nulled = 0;
  for (const ent of entities) {
    let cfg;
    try { cfg = JSON.parse(ent.config); } catch { continue; }
    const cols = Array.isArray(cfg?.columns) ? cfg.columns : [];
    for (const c of cols) {
      if (c?.type !== 'relation') continue;
      if (c.targetEntity !== deletedEntityCode) continue;
      const result = await prisma.$executeRawUnsafe(
        `UPDATE ${quoteIdent(ent.tableName)} SET ${quoteIdent(c.name)} = NULL WHERE ${quoteIdent(c.name)} = ?`,
        Number(deletedId),
      );
      nulled += Number(result || 0);
    }
  }
  return { nulled };
}

// Phase 4.15 follow-up — target_id existence validation. When writing
// relations, any IDs that don't actually exist in the target entity's
// table are silently dropped (with a warn-level log so the operator
// notices). Keeps the join table clean of orphans without rejecting
// the whole write — UI may have raced a delete on the target side.
//
// Returns the filtered subset. If targetEntity isn't set or doesn't
// resolve to a known entity, returns the input unchanged (defensive —
// don't swallow data because of a config gap).
export async function filterExistingTargetIds(targetEntityCode, targetIds) {
  const ids = Array.isArray(targetIds) ? targetIds.map((v) => Number(v)).filter((v) => Number.isFinite(v) && v > 0) : [];
  if (ids.length === 0) return ids;
  if (!targetEntityCode) return ids;
  const target = await prisma.customEntity.findUnique({ where: { code: targetEntityCode } });
  if (!target) return ids;

  // ensureTable on the target so a partial restore doesn't make every
  // write fail with "no such table".
  try { await ensureTable(target); } catch { return ids; }

  const placeholders = ids.map(() => '?').join(',');
  const rows = await prisma.$queryRawUnsafe(
    `SELECT id FROM ${quoteIdent(target.tableName)} WHERE id IN (${placeholders})`,
    ...ids,
  );
  const valid = new Set(rows.map((r) => Number(r.id)));
  const filtered = ids.filter((id) => valid.has(id));
  if (filtered.length < ids.length) {
    const dropped = ids.filter((id) => !valid.has(id));
    await logSystem(
      'warn',
      'custom_entity',
      `Dropped ${dropped.length} non-existent target id(s) from a relations write: [${dropped.join(', ')}] (target entity: ${targetEntityCode}).`,
      { targetEntity: targetEntityCode, droppedIds: dropped },
    ).catch(() => { /* best-effort */ });
  }
  return filtered;
}

const VALID_IDENT = /^[A-Za-z_][A-Za-z0-9_]{0,62}$/;
const USER_TABLE_NAME = /^[a-z][a-z0-9_]{0,62}$/;

export function validateIdent(name) {
  if (typeof name !== 'string' || !VALID_IDENT.test(name)) {
    throw new Error(`Invalid identifier "${name}" — letters, digits, underscore; max 63 chars; must start with a letter or underscore.`);
  }
  return name;
}

export function validateTableName(name) {
  if (typeof name !== 'string' || !USER_TABLE_NAME.test(name)) {
    throw new Error(`Invalid table/column name "${name}" — use a-z, 0-9, _, starting with a letter, max 63 chars.`);
  }
  return name;
}

export function quoteIdent(name) {
  validateIdent(name);
  return `"${name}"`;
}

export function buildCreateTableSQL(tableName, columns) {
  validateTableName(tableName);
  const cols = ['"id" INTEGER PRIMARY KEY AUTOINCREMENT'];
  for (const c of columns) {
    validateTableName(c.name);
    if (c.name === 'id') continue;
    if (isRelationsCol(c)) continue; // many-to-many, lives in its own join table
    if (isFormulaCol(c)) continue;   // virtual; evaluated at read time
    const sqlType = TYPE_TO_SQLITE[c.type] || 'TEXT';
    let line = `${quoteIdent(c.name)} ${sqlType}`;
    if (c.required) line += ' NOT NULL';
    if (c.unique) line += ' UNIQUE';
    if (c.defaultValue !== undefined && c.defaultValue !== null && c.defaultValue !== '') {
      const v = c.defaultValue;
      const lit = typeof v === 'number' ? String(v) : `'${String(v).replace(/'/g, "''")}'`;
      line += ` DEFAULT ${lit}`;
    }
    cols.push(line);
  }
  cols.push('"created_at" TEXT DEFAULT CURRENT_TIMESTAMP');
  cols.push('"updated_at" TEXT DEFAULT CURRENT_TIMESTAMP');
  return `CREATE TABLE IF NOT EXISTS ${quoteIdent(tableName)} (${cols.join(', ')})`;
}

export async function dropTable(tableName) {
  await prisma.$executeRawUnsafe(`DROP TABLE IF EXISTS ${quoteIdent(tableName)}`);
}

export async function tableExists(tableName) {
  const rows = await prisma.$queryRawUnsafe(
    `SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?`,
    tableName,
  );
  return Array.isArray(rows) && rows.length > 0;
}

export async function listColumns(tableName) {
  validateTableName(tableName);
  const rows = await prisma.$queryRawUnsafe(`PRAGMA table_info(${quoteIdent(tableName)})`);
  return rows.map((r) => ({
    name: r.name,
    type: r.type,
    notnull: !!r.notnull,
    default: r.dflt_value,
    pk: !!r.pk,
  }));
}

// Phase 4.5 — column diff + auto-ALTER for custom entities.
//
// Returns a structured diff that the route layer can apply via
// applyColumnDiff. Type changes are flagged as `changed` rather than
// silently dropping/recreating the column — SQLite's ALTER TABLE
// cannot change column types in-place, so a manual rebuild is needed
// (handled by the operator via the SQL runner today).
export function diffColumns(oldCols, newCols) {
  const oldByName = new Map((oldCols || []).map((c) => [c.name, c]));
  const newByName = new Map((newCols || []).map((c) => [c.name, c]));
  const added = [];
  const removed = [];
  const changed = [];
  for (const [name, c] of newByName) {
    if (!oldByName.has(name)) added.push(c);
    else {
      const old = oldByName.get(name);
      if (old.type !== c.type) changed.push({ name, from: old.type, to: c.type });
    }
  }
  for (const name of oldByName.keys()) {
    if (!newByName.has(name)) removed.push(oldByName.get(name));
  }
  return { added, removed, changed };
}

// Builds the SQL fragment used in ALTER TABLE ... ADD COLUMN. We do NOT
// emit `NOT NULL` for existing tables because SQLite would reject the
// ALTER unless we also supply a default. If the user wants required, the
// app-level validator on insert/update enforces it.
function buildAddColumnFragment(c) {
  validateTableName(c.name);
  const sqlType = TYPE_TO_SQLITE[c.type] || 'TEXT';
  let line = `${quoteIdent(c.name)} ${sqlType}`;
  if (c.unique) line += ' UNIQUE';
  if (c.defaultValue !== undefined && c.defaultValue !== null && c.defaultValue !== '') {
    const v = c.defaultValue;
    const lit = typeof v === 'number' ? String(v) : `'${String(v).replace(/'/g, "''")}'`;
    line += ` DEFAULT ${lit}`;
  }
  return line;
}

// Applies an additive/destructive column diff. Returns a summary of what
// ran. Type changes are returned in `skipped` so the caller can warn.
//
// `relations` columns don't live in the source table — they have their
// own join table — so we route them through ensure/drop join-table
// helpers instead of ALTER TABLE.
export async function applyColumnDiff(tableName, diff) {
  validateTableName(tableName);
  const ran = [];
  const skipped = [];

  for (const c of diff.added) {
    if (isFormulaCol(c)) {
      ran.push({ op: 'addFormula', column: c.name });
      continue; // virtual — no SQL change
    }
    if (isRelationsCol(c)) {
      await prisma.$executeRawUnsafe(buildJoinTableSQL(tableName, c.name));
      await prisma.$executeRawUnsafe(
        `CREATE INDEX IF NOT EXISTS ${quoteIdent(`${joinTableName(tableName, c.name)}_target_idx`)} ` +
          `ON ${quoteIdent(joinTableName(tableName, c.name))} ("target_id")`,
      );
      ran.push({ op: 'addJoinTable', column: c.name });
      continue;
    }
    const sql = `ALTER TABLE ${quoteIdent(tableName)} ADD COLUMN ${buildAddColumnFragment(c)}`;
    await prisma.$executeRawUnsafe(sql);
    ran.push({ op: 'add', column: c.name });
  }
  for (const c of diff.removed) {
    if (isFormulaCol(c)) {
      ran.push({ op: 'dropFormula', column: c.name });
      continue; // virtual — no SQL change
    }
    if (isRelationsCol(c)) {
      await dropJoinTable(tableName, c.name);
      ran.push({ op: 'dropJoinTable', column: c.name });
      continue;
    }
    // SQLite 3.35+ supports DROP COLUMN; Node 20 ships ≥ 3.40.
    const sql = `ALTER TABLE ${quoteIdent(tableName)} DROP COLUMN ${quoteIdent(c.name)}`;
    try {
      await prisma.$executeRawUnsafe(sql);
      ran.push({ op: 'drop', column: c.name });
    } catch (err) {
      skipped.push({ op: 'drop', column: c.name, reason: String(err?.message || err) });
    }
  }
  for (const c of diff.changed) {
    // Switching scalar ↔ relations is a fundamentally different storage
    // model — same SQLite ALTER limitation applies, so we just flag it.
    skipped.push({
      op: 'changeType',
      column: c.name,
      from: c.from,
      to: c.to,
      reason: 'SQLite cannot change column type via ALTER TABLE. Use the SQL runner to rebuild the table (CREATE TABLE _new, copy rows, DROP, RENAME), then update the entity config.',
    });
  }
  return { ran, skipped };
}

// Phase 4.11 — auto-heal missing SQL tables.
//
// A custom entity's registration row in `custom_entities` is the source
// of truth for "does this entity exist in the system?". The underlying
// SQL table is the implementation. If the table goes missing — usually
// because the DB was reset or restored from a backup that didn't
// include the user-tables — we recreate it from the registered column
// config on next access.
//
// `CREATE TABLE IF NOT EXISTS` makes this idempotent: if the table is
// already there, the query is a no-op. If it isn't, we build it from
// the entity's stored column config (same path as initial creation).
//
// We log a warn-level system event the first time we have to heal a
// table, so the operator sees something happened.
export async function ensureTable(entity) {
  // Always make sure join tables exist for any relations columns —
  // they're cheap to create-if-missing and the source table can be
  // present without the join tables (e.g. partial restores).
  await ensureJoinTables(entity).catch(() => { /* best-effort */ });

  if (await tableExists(entity.tableName)) return false;
  let config;
  try {
    config = JSON.parse(entity.config);
  } catch (err) {
    throw new Error(`Cannot recreate table for "${entity.code}" — invalid stored config: ${err.message}`);
  }
  const columns = Array.isArray(config?.columns) ? config.columns : [];
  if (columns.length === 0) {
    throw new Error(`Cannot recreate table for "${entity.code}" — registered config has no columns.`);
  }
  await prisma.$executeRawUnsafe(buildCreateTableSQL(entity.tableName, columns));
  await logSystem(
    'warn',
    'custom_entity',
    `Auto-recreated missing SQL table "${entity.tableName}" for entity "${entity.code}". ` +
      'Likely cause: DB was reset/restored without the user tables. ' +
      'If unexpected, re-apply the business preset or restore a more recent backup.',
    { code: entity.code, tableName: entity.tableName, columnCount: columns.length },
  ).catch(() => { /* best-effort logging */ });
  return true;
}

function pickValue(value, type) {
  if (value === null || value === undefined || value === '') return null;
  switch (type) {
    case 'integer':
      return Number.isInteger(Number(value)) ? Number(value) : parseInt(`${value}`, 10) || null;
    case 'number':
      return Number(value);
    case 'bool':
      return value === true || value === 'true' || value === 1 || value === '1' ? 1 : 0;
    case 'date':
    case 'datetime':
      return String(value);
    default:
      return String(value);
  }
}

export async function listRows(entity, { page, pageSize, search }, ctx) {
  await ensureTable(entity);
  const config = JSON.parse(entity.config);
  const cols = config.columns;
  const tn = quoteIdent(entity.tableName);

  const params = [];
  let where = '';
  if (search && search.trim()) {
    const searchable = cols.filter((c) => c.searchable && (c.type === 'text' || c.type === 'longtext'));
    if (searchable.length > 0) {
      const ors = searchable.map((c) => {
        params.push(`%${search}%`);
        return `${quoteIdent(c.name)} LIKE ?`;
      });
      where = `WHERE ${ors.join(' OR ')}`;
    }
  }

  const skip = (page - 1) * pageSize;

  const rows = await prisma.$queryRawUnsafe(
    `SELECT * FROM ${tn} ${where} ORDER BY id DESC LIMIT ? OFFSET ?`,
    ...params,
    pageSize,
    skip,
  );

  const totalRows = await prisma.$queryRawUnsafe(
    `SELECT COUNT(*) as c FROM ${tn} ${where}`,
    ...params,
  );
  const total = Number(totalRows?.[0]?.c ?? 0);

  const items = rows.map(coerceRow);
  // Batch-fetch relations for the whole page so we don't N+1 the join
  // tables. One round-trip per relations column.
  const relationCols = cols.filter(isRelationsCol);
  if (relationCols.length > 0 && items.length > 0) {
    const sourceIds = items.map((r) => Number(r.id));
    for (const c of relationCols) {
      const map = await getRelationIdsBatch(entity.tableName, c.name, sourceIds);
      for (const item of items) {
        item[c.name] = map.get(Number(item.id)) ?? [];
      }
    }
  }
  // Phase 4.16 follow-up — apply formula columns AFTER relations are
  // populated, so a formula could reference a relations-derived
  // value if v2 ever adds aggregate functions over them.
  const formulaCols = cols.filter(isFormulaCol);
  if (formulaCols.length > 0) {
    for (const item of items) applyFormulasToRow(item, formulaCols);
  }
  // Phase 4.16 follow-up — strip restricted columns based on caller
  // permissions. Done last so formula values that reference a
  // restricted input field have a chance to be computed before the
  // input is removed; the formula's *output* is then also stripped if
  // the formula column itself is restricted.
  const filtered = ctx
    ? items.map((item) => stripRestrictedFromRow(item, cols, ctx))
    : items;
  return { items: filtered, total };
}

function coerceRow(r) {
  const out = {};
  for (const k of Object.keys(r)) {
    const v = r[k];
    out[k] = typeof v === 'bigint' ? Number(v) : v;
  }
  return out;
}

export async function getRow(entity, id, ctx) {
  await ensureTable(entity);
  const rows = await prisma.$queryRawUnsafe(
    `SELECT * FROM ${quoteIdent(entity.tableName)} WHERE id = ?`,
    Number(id),
  );
  if (!rows[0]) return null;
  const out = coerceRow(rows[0]);
  // Resolve relations columns to arrays of target IDs.
  let cols = [];
  try { cols = JSON.parse(entity.config).columns ?? []; } catch { cols = []; }
  for (const c of cols) {
    if (!isRelationsCol(c)) continue;
    const map = await getRelationIdsBatch(entity.tableName, c.name, [Number(id)]);
    out[c.name] = map.get(Number(id)) ?? [];
  }
  // Apply formula columns last so they can see all the populated fields.
  const formulaCols = cols.filter(isFormulaCol);
  if (formulaCols.length > 0) applyFormulasToRow(out, formulaCols);
  return ctx ? stripRestrictedFromRow(out, cols, ctx) : out;
}

export async function insertRow(entity, body, ctx) {
  await ensureTable(entity);
  const config = JSON.parse(entity.config);
  // Phase 4.16 follow-up — drop body fields the caller can't edit.
  body = filterEditableBody(body, config.columns, ctx);
  const editable = config.columns.filter((c) => c.name !== 'id' && !isRelationsCol(c) && !isFormulaCol(c));
  const relationCols = config.columns.filter(isRelationsCol);
  const colNames = [];
  const placeholders = [];
  const values = [];
  for (const c of editable) {
    if (body[c.name] === undefined) continue;
    colNames.push(quoteIdent(c.name));
    placeholders.push('?');
    values.push(pickValue(body[c.name], c.type));
  }
  if (colNames.length === 0) {
    await prisma.$executeRawUnsafe(`INSERT INTO ${quoteIdent(entity.tableName)} DEFAULT VALUES`);
  } else {
    await prisma.$executeRawUnsafe(
      `INSERT INTO ${quoteIdent(entity.tableName)} (${colNames.join(',')}) VALUES (${placeholders.join(',')})`,
      ...values,
    );
  }
  const last = await prisma.$queryRawUnsafe(`SELECT last_insert_rowid() as id`);
  const newId = Number(last[0].id);
  // Apply relations after the row exists so the source_id is valid.
  // Filter to existing target IDs so dangling refs don't sneak in.
  for (const c of relationCols) {
    if (!Array.isArray(body[c.name])) continue;
    const valid = await filterExistingTargetIds(c.targetEntity, body[c.name]);
    await setRelationIds(entity.tableName, c.name, newId, valid);
  }
  const created = await getRow(entity, newId, ctx);
  // Phase 4.17 — fire-and-forget into the workflow engine. Internal
  // ctx (test harness, template apply) skips workflows to avoid
  // unwanted side effects; route handlers always pass ctx so this is
  // a `ctx === undefined` test rather than a flag.
  if (ctx !== undefined) fireWorkflowsForRecord(entity.code, 'created', created, null);
  return created;
}

export async function updateRow(entity, id, body, ctx) {
  await ensureTable(entity);
  const config = JSON.parse(entity.config);
  // Phase 4.16 follow-up — drop body fields the caller can't edit.
  body = filterEditableBody(body, config.columns, ctx);
  // Phase 4.17 — capture before-image for record.updated workflows.
  // Cheap because getRow runs the same SELECT we'd run anyway.
  const before = ctx !== undefined ? await getRow(entity, Number(id), undefined) : null;
  const editable = config.columns.filter((c) => c.name !== 'id' && !isRelationsCol(c) && !isFormulaCol(c));
  const relationCols = config.columns.filter(isRelationsCol);
  const sets = [];
  const values = [];
  for (const c of editable) {
    if (body[c.name] === undefined) continue;
    sets.push(`${quoteIdent(c.name)} = ?`);
    values.push(pickValue(body[c.name], c.type));
  }
  // updated_at refresh always runs even when only relations changed —
  // operators expect "edited at" to update on relation edits too.
  sets.push(`"updated_at" = CURRENT_TIMESTAMP`);
  values.push(Number(id));
  await prisma.$executeRawUnsafe(
    `UPDATE ${quoteIdent(entity.tableName)} SET ${sets.join(', ')} WHERE id = ?`,
    ...values,
  );
  for (const c of relationCols) {
    if (!Array.isArray(body[c.name])) continue;
    const valid = await filterExistingTargetIds(c.targetEntity, body[c.name]);
    await setRelationIds(entity.tableName, c.name, id, valid);
  }
  const updated = await getRow(entity, id, ctx);
  if (ctx !== undefined) fireWorkflowsForRecord(entity.code, 'updated', updated, before);
  return updated;
}

export async function deleteRow(entity, id) {
  await ensureTable(entity);
  // Phase 4.17 — capture before-image so record.deleted workflows can
  // see what was removed. Best-effort: a missing row falls through to
  // the DELETE which is a no-op.
  const before = await getRow(entity, Number(id), undefined).catch(() => null);
  // Purge join rows where this row is the SOURCE.
  await deleteAllRelationsFor(entity, id);
  // Purge join rows where this row is the TARGET (other entities
  // pointing at us via a `relations` column whose targetEntity is us).
  await reverseCascadeRelations(entity.code, id);
  // NULL out singular `relation` (1-FK) columns in other entities that
  // point at us. Symmetric with reverseCascadeRelations, but the
  // storage is a column on the source table (not a join table).
  await nullifyDanglingSingleRelations(entity.code, id);
  await prisma.$executeRawUnsafe(
    `DELETE FROM ${quoteIdent(entity.tableName)} WHERE id = ?`,
    Number(id),
  );
  if (before) fireWorkflowsForRecord(entity.code, 'deleted', null, before);
}

export function permissionCodesFor(prefix) {
  return ['view', 'create', 'edit', 'delete', 'export', 'print'].map((a) => `${prefix}.${a}`);
}

export async function ensurePermissions(prefix, label) {
  const actionsLabel = {
    view: 'View',
    create: 'Create',
    edit: 'Edit',
    delete: 'Delete',
    export: 'Export',
    print: 'Print',
  };
  for (const action of Object.keys(actionsLabel)) {
    const code = `${prefix}.${action}`;
    await prisma.permission.upsert({
      where: { code },
      update: { name: `${label} — ${actionsLabel[action]}`, module: prefix, action },
      create: { code, name: `${label} — ${actionsLabel[action]}`, module: prefix, action },
    });
  }
}

export async function ensureMenuItem({ entityCode, label, icon, sortOrder, permissionCode }) {
  const code = `menu.custom.${entityCode}`;
  await prisma.menuItem.upsert({
    where: { code },
    update: { label, icon, route: `/c/${entityCode}`, permissionCode, sortOrder, isActive: true },
    create: { code, label, icon: icon ?? 'reports', route: `/c/${entityCode}`, permissionCode, sortOrder },
  });
}

export async function ensureModule({ code, name, icon, sortOrder }) {
  await prisma.module.upsert({
    where: { code },
    update: { name, icon, sortOrder, isActive: true },
    create: { code, name, icon: icon ?? 'reports', sortOrder, isActive: true, isCore: false },
  });
}

export async function grantToSuperAdminAndCompanyAdmin(prefix) {
  const perms = await prisma.permission.findMany({ where: { module: prefix } });
  if (perms.length === 0) return;

  const targets = await prisma.role.findMany({ where: { code: { in: ['super_admin', 'company_admin'] } } });
  for (const role of targets) {
    for (const p of perms) {
      try {
        await prisma.rolePermission.create({ data: { roleId: role.id, permissionId: p.id } });
      } catch {
        // ignore duplicates
      }
    }
  }
}
