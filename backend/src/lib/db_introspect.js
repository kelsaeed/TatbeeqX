import { prisma } from './prisma.js';
import { quoteIdent, validateIdent } from './custom_entity_engine.js';

export async function listTables() {
  const rows = await prisma.$queryRawUnsafe(
    `SELECT name, sql FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE '_prisma_%' ORDER BY name`,
  );
  // Phase 4.16 follow-up — was N sequential COUNT(*) queries (one per
  // table). Now parallel via Promise.all. On a 30-table install this
  // turns ~30 round trips into 1.
  const counts = await Promise.all(
    rows.map((r) => prisma.$queryRawUnsafe(`SELECT COUNT(*) as c FROM ${quoteIdent(r.name)}`)),
  );
  return rows.map((r, i) => ({
    name: r.name,
    rowCount: Number(counts[i]?.[0]?.c ?? 0),
    definition: r.sql,
  }));
}

export async function describeTable(tableName) {
  validateIdent(tableName);
  // Phase 4.16 follow-up — was 3 sequential PRAGMA queries; now parallel.
  const [cols, fks, idx] = await Promise.all([
    prisma.$queryRawUnsafe(`PRAGMA table_info(${quoteIdent(tableName)})`),
    prisma.$queryRawUnsafe(`PRAGMA foreign_key_list(${quoteIdent(tableName)})`),
    prisma.$queryRawUnsafe(`PRAGMA index_list(${quoteIdent(tableName)})`),
  ]);
  return {
    name: tableName,
    columns: cols.map((c) => ({
      cid: Number(c.cid),
      name: c.name,
      type: c.type,
      notnull: !!Number(c.notnull),
      default: c.dflt_value,
      pk: !!Number(c.pk),
    })),
    foreignKeys: fks.map(coerce),
    indexes: idx.map(coerce),
  };
}

export async function previewRows(tableName, limit = 50) {
  validateIdent(tableName);
  const rows = await prisma.$queryRawUnsafe(
    `SELECT * FROM ${quoteIdent(tableName)} LIMIT ?`,
    Math.max(1, Math.min(500, Number(limit) || 50)),
  );
  return rows.map(coerce);
}

function coerce(r) {
  const o = {};
  for (const k of Object.keys(r)) {
    o[k] = typeof r[k] === 'bigint' ? Number(r[k]) : r[k];
  }
  return o;
}
