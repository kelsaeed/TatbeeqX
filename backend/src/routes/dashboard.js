import { Router } from 'express';
import { prisma } from '../lib/prisma.js';
import { authenticate } from '../middleware/auth.js';
import { asyncHandler } from '../lib/http.js';

const router = Router();
router.use(authenticate);

function dayKey(d) {
  return new Date(d).toISOString().slice(0, 10);
}

router.get(
  '/summary',
  asyncHandler(async (req, res) => {
    // Phase 4.16 follow-up — fold recentLogins/recentAudit into the
    // same Promise.all as the counts. They were sequential before, which
    // doubled the round-trip cost on the most-loaded route in the app
    // (dashboard fires this on every login).
    const [users, companies, branches, roles, audit, recentLogins, recentAudit] = await Promise.all([
      prisma.user.count(),
      prisma.company.count(),
      prisma.branch.count(),
      prisma.role.count(),
      prisma.auditLog.count(),
      prisma.user.findMany({
        where: { lastLoginAt: { not: null } },
        orderBy: { lastLoginAt: 'desc' },
        take: 5,
        select: { id: true, username: true, fullName: true, lastLoginAt: true },
      }),
      prisma.auditLog.findMany({
        orderBy: { id: 'desc' },
        take: 10,
        include: { user: { select: { username: true, fullName: true } } },
      }),
    ]);
    res.json({
      counts: { users, companies, branches, roles, audit },
      recentLogins,
      recentAudit,
      currentUser: req.user,
    });
  }),
);

router.get(
  '/audit-by-day',
  asyncHandler(async (req, res) => {
    const days = Math.min(60, Math.max(1, Number(req.query.days) || 14));
    const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000);
    // Phase 4.16 follow-up — push aggregation to SQL. Old code did
    // findMany() (loads every row in window) + JS group-by. On a busy
    // install the audit log can be 100k+ rows — that's MBs over the
    // wire and JS-side memory pressure. SQLite's strftime gives us the
    // grouping for free; the same shape works on Postgres via to_char.
    //
    // Detection: peek at the connection URL. Empty/sqlite/file: are
    // SQLite; anything else assumes Postgres-compatible (date_trunc).
    const url = (process.env.DATABASE_URL || '').toLowerCase();
    const isSqlite = url === '' || url.startsWith('file:') || url.startsWith('sqlite:');
    const sinceIso = since.toISOString();
    const rows = isSqlite
      ? await prisma.$queryRawUnsafe(
          `SELECT strftime('%Y-%m-%d', "createdAt") AS date, COUNT(*) AS count
             FROM "AuditLog" WHERE "createdAt" >= ? GROUP BY date`,
          sinceIso,
        )
      : await prisma.$queryRawUnsafe(
          `SELECT to_char("createdAt"::date, 'YYYY-MM-DD') AS date, COUNT(*)::int AS count
             FROM "AuditLog" WHERE "createdAt" >= $1 GROUP BY date`,
          sinceIso,
        );

    // Backfill empty days so the chart always shows a contiguous
    // window even on quiet installs.
    const counts = new Map();
    for (const r of rows) counts.set(String(r.date), Number(r.count));
    const series = [];
    for (let i = days - 1; i >= 0; i--) {
      const d = new Date(Date.now() - i * 24 * 60 * 60 * 1000);
      const k = dayKey(d);
      series.push({ date: k, count: counts.get(k) ?? 0 });
    }
    res.json({ series });
  }),
);

router.get(
  '/audit-by-module',
  asyncHandler(async (req, res) => {
    const days = Math.min(120, Math.max(1, Number(req.query.days) || 30));
    const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000);
    const events = await prisma.auditLog.groupBy({
      by: ['entity'],
      where: { createdAt: { gte: since } },
      _count: { entity: true },
      orderBy: { _count: { entity: 'desc' } },
    });
    res.json({
      series: events.map((e) => ({ entity: e.entity, count: e._count.entity })),
    });
  }),
);

export default router;
