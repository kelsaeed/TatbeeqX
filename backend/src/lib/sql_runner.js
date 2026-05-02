import { prisma } from './prisma.js';
import { getHandleFor } from './db_pool.js';

const FORBIDDEN_TABLES = ['users', 'roles', 'permissions', 'role_permissions', 'user_roles', 'user_permission_overrides'];
const READONLY_PREFIX = /^\s*(select|with|pragma|explain|show)\b/i;
const DESTRUCTIVE_TABLES = /\b(?:from|into|update|delete\s+from|alter\s+table|drop\s+table)\s+["`]?(users|roles|permissions|role_permissions|user_roles|user_permission_overrides)\b/i;

export function isReadOnly(sql) {
  return READONLY_PREFIX.test(sql);
}

export function assertSafe(sql, { allowWrite, secondary = false }) {
  if (!sql || sql.trim().length === 0) throw new Error('Empty SQL');
  if (sql.length > 10000) throw new Error('SQL too long (max 10,000 characters)');

  // Auth-table protection only applies to the primary DB — secondaries
  // do not own this app's auth schema.
  if (!secondary && DESTRUCTIVE_TABLES.test(sql)) {
    throw new Error(`Modifying core auth tables (${FORBIDDEN_TABLES.join(', ')}) via SQL is blocked. Use the UI for those.`);
  }

  if (!allowWrite && !isReadOnly(sql)) {
    throw new Error('Read-only mode is on — only SELECT, WITH, PRAGMA, EXPLAIN and SHOW are allowed.');
  }
}

export async function runQuery(sql, { allowWrite = false, maxRows = 1000, connectionId = null } = {}) {
  const secondary = !!connectionId;
  assertSafe(sql, { allowWrite, secondary });
  const trimmed = sql.trim();

  if (!secondary) {
    // Primary path stays on Prisma directly to avoid extra wrapper allocations.
    if (isReadOnly(trimmed)) {
      const rows = await prisma.$queryRawUnsafe(trimmed);
      const limited = Array.isArray(rows) ? rows.slice(0, maxRows) : [];
      return {
        kind: 'rows',
        truncated: Array.isArray(rows) && rows.length > maxRows,
        rowCount: Array.isArray(rows) ? rows.length : 0,
        columns: extractColumns(limited),
        rows: limited.map(coerce),
        secondary: false,
      };
    }
    const affected = await prisma.$executeRawUnsafe(trimmed);
    return { kind: 'affected', affectedRows: Number(affected), secondary: false };
  }

  // Secondary path goes through the unified handle (Prisma | pg | mysql2).
  const handle = await getHandleFor(connectionId);
  if (isReadOnly(trimmed)) {
    const rows = await handle.runRead(trimmed);
    const limited = Array.isArray(rows) ? rows.slice(0, maxRows) : [];
    return {
      kind: 'rows',
      truncated: Array.isArray(rows) && rows.length > maxRows,
      rowCount: Array.isArray(rows) ? rows.length : 0,
      columns: extractColumns(limited),
      rows: limited.map(coerce),
      secondary: true,
      driver: handle.kind,
    };
  }
  const affected = await handle.runWrite(trimmed);
  return { kind: 'affected', affectedRows: Number(affected), secondary: true, driver: handle.kind };
}

function extractColumns(rows) {
  if (!rows || rows.length === 0) return [];
  return Object.keys(rows[0]);
}

function coerce(r) {
  const o = {};
  for (const k of Object.keys(r)) {
    o[k] = typeof r[k] === 'bigint' ? Number(r[k]) : r[k];
  }
  return o;
}
