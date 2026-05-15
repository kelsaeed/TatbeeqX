import { PrismaClient } from '@prisma/client';

const globalForPrisma = globalThis;

export const prisma =
  globalForPrisma.prisma ??
  new PrismaClient({
    log: process.env.NODE_ENV === 'development' ? ['warn', 'error'] : ['error'],
  });

if (process.env.NODE_ENV !== 'production') {
  globalForPrisma.prisma = prisma;
}

let pragmasApplied = false;

// One-time SQLite tuning, applied at server startup before traffic.
//
// Default SQLite is journal_mode=DELETE + synchronous=FULL: every write
// takes a database-wide lock, fsyncs on commit, and creates+deletes a
// per-transaction `-journal` file. This app writes constantly off the
// request path — the 60s cron loop, an AuditLog row per mutation,
// system-log rows — so readers (every list/menu/dashboard call) end up
// serialized behind those writers, and each transaction's journal
// file churn is intercepted and scanned by any real-time AV watching
// the DB directory. That is the dominant "everything is heavy" cost on
// a SQLite + AV host.
//
// WAL lets readers and the single writer run concurrently and uses one
// persistent `-wal` file instead of per-txn journal create/delete.
// synchronous=NORMAL is the standard, durable-enough pairing with WAL
// (only a power-loss/OS-crash can lose the last txn; an app crash
// cannot). busy_timeout makes a contended statement wait-and-retry
// instead of throwing SQLITE_BUSY. temp_store=MEMORY keeps transient
// sorts/indexes off disk. All are no-ops on non-SQLite providers, so
// we gate on the datasource URL.
export async function applySqlitePragmas() {
  if (pragmasApplied) return;
  const url = (process.env.DATABASE_URL || '').toLowerCase();
  const isSqlite = url === '' || url.startsWith('file:') || url.startsWith('sqlite:');
  if (!isSqlite) {
    pragmasApplied = true;
    return;
  }
  // journal_mode returns a row ("wal"); the rest are statements.
  await prisma.$queryRawUnsafe('PRAGMA journal_mode = WAL;');
  await prisma.$executeRawUnsafe('PRAGMA synchronous = NORMAL;');
  await prisma.$executeRawUnsafe('PRAGMA busy_timeout = 5000;');
  await prisma.$executeRawUnsafe('PRAGMA temp_store = MEMORY;');
  pragmasApplied = true;
}
