import { PrismaClient } from '@prisma/client';
import { prisma } from './prisma.js';
import { logSystem } from './system_log.js';

// Phase 4.2 / 4.3 — secondary DB pool.
//
// Connection routing:
//   - No connectionId      → Prisma primary client (this app's DB).
//   - Same provider as primary (sqlite ↔ sqlite) → cached PrismaClient with
//     `datasources.db.url` overridden.
//   - postgresql secondary → cached `pg.Pool` (native driver).
//   - mysql secondary      → cached `mysql2/promise.Pool` (native driver).
//   - sqlserver / mongodb  → not supported yet; clear error.
//
// Every secondary client exposes a uniform `runRead(sql)` / `runWrite(sql)`
// surface that returns the same shape regardless of the underlying driver,
// so the SQL runner doesn't branch on provider.

const cache = new Map(); // connectionId -> { handle, url }
const PRIMARY_PROVIDER = 'sqlite';

export function inferProvider(url) {
  const s = String(url || '').trim().toLowerCase();
  if (s.startsWith('file:') || s.endsWith('.db') || s.endsWith('.sqlite') || s.endsWith('.sqlite3')) return 'sqlite';
  if (s.startsWith('postgres://') || s.startsWith('postgresql://')) return 'postgresql';
  if (s.startsWith('mysql://') || s.startsWith('mariadb://')) return 'mysql';
  if (s.startsWith('sqlserver://') || s.startsWith('mssql://')) return 'sqlserver';
  if (s.startsWith('mongodb://') || s.startsWith('mongodb+srv://')) return 'mongodb';
  return null;
}

export function getPrimaryProvider() {
  return PRIMARY_PROVIDER;
}

async function loadConnection(connectionId) {
  const conn = await prisma.databaseConnection.findUnique({ where: { id: Number(connectionId) } });
  if (!conn) {
    const err = new Error(`Database connection not found: ${connectionId}`);
    err.status = 404;
    throw err;
  }
  if (!conn.isActive) {
    const err = new Error(`Database connection is inactive: ${conn.code}`);
    err.status = 400;
    throw err;
  }
  return conn;
}

function makePrismaHandle(client) {
  return {
    kind: 'prisma',
    async runRead(sql) {
      const rows = await client.$queryRawUnsafe(sql);
      return Array.isArray(rows) ? rows : [];
    },
    async runWrite(sql) {
      const affected = await client.$executeRawUnsafe(sql);
      return Number(affected);
    },
    async close() {
      try { await client.$disconnect(); } catch (_) { /* ignore */ }
    },
    raw: client,
  };
}

async function makePgHandle(url) {
  const { default: pg } = await import('pg');
  const pool = new pg.Pool({ connectionString: url, max: 4, idleTimeoutMillis: 30_000 });
  return {
    kind: 'pg',
    async runRead(sql) {
      const res = await pool.query(sql);
      return Array.isArray(res.rows) ? res.rows : [];
    },
    async runWrite(sql) {
      const res = await pool.query(sql);
      return res.rowCount ?? 0;
    },
    async close() {
      try { await pool.end(); } catch (_) { /* ignore */ }
    },
    raw: pool,
  };
}

async function makeMysqlHandle(url) {
  const mysql = await import('mysql2/promise');
  const pool = mysql.createPool({ uri: url, waitForConnections: true, connectionLimit: 4 });
  return {
    kind: 'mysql',
    async runRead(sql) {
      const [rows] = await pool.query(sql);
      return Array.isArray(rows) ? rows : [];
    },
    async runWrite(sql) {
      const [res] = await pool.query(sql);
      return res?.affectedRows ?? 0;
    },
    async close() {
      try { await pool.end(); } catch (_) { /* ignore */ }
    },
    raw: pool,
  };
}

async function probe(handle) {
  await handle.runRead('SELECT 1');
}

export async function getHandleFor(connectionId) {
  if (!connectionId) {
    return makePrismaHandle(prisma);
  }

  const cached = cache.get(connectionId);
  const conn = await loadConnection(connectionId);

  if (cached && cached.url === conn.url) return cached.handle;

  if (cached && cached.url !== conn.url) {
    try { await cached.handle.close(); } catch (_) { /* ignore */ }
    cache.delete(connectionId);
  }

  const provider = (conn.provider || inferProvider(conn.url) || '').toLowerCase();
  let handle;

  if (provider === PRIMARY_PROVIDER) {
    const client = new PrismaClient({ datasources: { db: { url: conn.url } }, log: ['error'] });
    handle = makePrismaHandle(client);
  } else if (provider === 'postgresql') {
    handle = await makePgHandle(conn.url);
  } else if (provider === 'mysql') {
    handle = await makeMysqlHandle(conn.url);
  } else {
    const err = new Error(
      `Provider "${provider}" is not yet supported by the secondary pool. ` +
      `Supported: ${PRIMARY_PROVIDER}, postgresql, mysql.`,
    );
    err.status = 400;
    throw err;
  }

  try {
    await probe(handle);
  } catch (probeErr) {
    try { await handle.close(); } catch (_) { /* ignore */ }
    await logSystem('error', 'db_pool', `Probe failed for connection ${conn.code}`, {
      provider,
      error: String(probeErr.message || probeErr),
    });
    const err = new Error(`Could not connect to "${conn.code}": ${probeErr.message || probeErr}`);
    err.status = 502;
    throw err;
  }

  cache.set(connectionId, { handle, url: conn.url });
  await logSystem('info', 'db_pool', `Opened secondary handle for ${conn.code}`, { provider, kind: handle.kind });
  return handle;
}

// Back-compat: previous Phase 4.2 callers used getClientFor and assumed
// PrismaClient. Map it to a handle for the same-provider path; otherwise
// throw the same cross-provider message they used to get.
export async function getClientFor(connectionId) {
  if (!connectionId) return prisma;
  const conn = await loadConnection(connectionId);
  const provider = (conn.provider || inferProvider(conn.url) || '').toLowerCase();
  if (provider !== PRIMARY_PROVIDER) {
    const err = new Error(
      `getClientFor() is for same-provider secondaries only. Use getHandleFor() for cross-provider. ` +
      `Primary "${PRIMARY_PROVIDER}", connection "${provider}".`,
    );
    err.status = 400;
    throw err;
  }
  const handle = await getHandleFor(connectionId);
  return handle.raw;
}

export async function closeAll() {
  for (const [id, entry] of cache.entries()) {
    try { await entry.handle.close(); } catch (_) { /* ignore */ }
    cache.delete(id);
  }
}
