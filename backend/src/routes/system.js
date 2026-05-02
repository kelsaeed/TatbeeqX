import { Router } from 'express';
import os from 'node:os';
import process from 'node:process';
import { prisma } from '../lib/prisma.js';
import { authenticate } from '../middleware/auth.js';
import { requirePermission, requireSuperAdmin } from '../middleware/permission.js';
import { asyncHandler, badRequest, notFound } from '../lib/http.js';
import { parseId, requireFields } from '../middleware/validate.js';
import { writeAudit } from '../lib/audit.js';
import { logSystem } from '../lib/system_log.js';
import { readEnvKeys, setEnvKeys } from '../lib/env_writer.js';

const router = Router();

const VALID_PROVIDERS = new Set(['sqlite', 'postgresql', 'mysql', 'sqlserver', 'mongodb']);

function maskUrl(url) {
  if (!url) return null;
  try {
    return url.replace(/(:\/\/[^:]+:)([^@]+)(@)/, '$1***$3');
  } catch {
    return null;
  }
}

router.use(authenticate);

router.get(
  '/info',
  requirePermission('system.view'),
  asyncHandler(async (_req, res) => {
    const mem = process.memoryUsage();
    const env = readEnvKeys(['DATABASE_URL', 'PORT', 'HOST']);
    const counts = await prisma.$transaction([
      prisma.user.count(),
      prisma.role.count(),
      prisma.permission.count(),
      prisma.auditLog.count(),
      prisma.systemLog.count(),
      prisma.loginEvent.count(),
      prisma.page.count(),
      prisma.customEntity.count(),
    ]);
    res.json({
      time: new Date().toISOString(),
      uptimeSec: Math.round(process.uptime()),
      node: process.version,
      platform: process.platform,
      arch: process.arch,
      hostname: os.hostname(),
      memory: { rss: mem.rss, heapUsed: mem.heapUsed, heapTotal: mem.heapTotal },
      databaseProvider: 'sqlite',
      databaseUrl: maskUrl(env.DATABASE_URL),
      counts: {
        users: counts[0],
        roles: counts[1],
        permissions: counts[2],
        auditLogs: counts[3],
        systemLogs: counts[4],
        loginEvents: counts[5],
        pages: counts[6],
        customEntities: counts[7],
      },
    });
  }),
);

router.get(
  '/database/connections',
  requireSuperAdmin(),
  asyncHandler(async (_req, res) => {
    const items = await prisma.databaseConnection.findMany({ orderBy: { id: 'asc' } });
    res.json({
      items: items.map((c) => ({ ...c, url: maskUrl(c.url) })),
    });
  }),
);

router.post(
  '/database/connections',
  requireSuperAdmin(),
  asyncHandler(async (req, res) => {
    requireFields(req.body, ['code', 'name', 'provider', 'url']);
    const { code, name, description = null, provider, url, isActive = true } = req.body;
    if (!VALID_PROVIDERS.has(provider)) throw badRequest('Invalid provider');
    const created = await prisma.databaseConnection.create({
      data: { code, name, description, provider, url, isActive },
    });
    await writeAudit({ req, action: 'create', entity: 'DatabaseConnection', entityId: created.id });
    await logSystem('info', 'system', `Database connection created: ${code}`, { provider });
    res.status(201).json({ ...created, url: maskUrl(created.url) });
  }),
);

router.put(
  '/database/connections/:id',
  requireSuperAdmin(),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const update = {};
    for (const f of ['name', 'description', 'provider', 'url', 'isActive']) {
      if (req.body[f] !== undefined) update[f] = req.body[f];
    }
    if (update.provider && !VALID_PROVIDERS.has(update.provider)) throw badRequest('Invalid provider');
    const updated = await prisma.databaseConnection.update({ where: { id }, data: update });
    await writeAudit({ req, action: 'update', entity: 'DatabaseConnection', entityId: id });
    res.json({ ...updated, url: maskUrl(updated.url) });
  }),
);

router.delete(
  '/database/connections/:id',
  requireSuperAdmin(),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const conn = await prisma.databaseConnection.findUnique({ where: { id } });
    if (!conn) throw notFound('Connection not found');
    if (conn.isPrimary) throw badRequest('Cannot delete the primary connection');
    await prisma.databaseConnection.delete({ where: { id } });
    await writeAudit({ req, action: 'delete', entity: 'DatabaseConnection', entityId: id });
    res.json({ ok: true });
  }),
);

router.post(
  '/database/connections/:id/promote',
  requireSuperAdmin(),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const conn = await prisma.databaseConnection.findUnique({ where: { id } });
    if (!conn) throw notFound('Connection not found');

    const env = setEnvKeys({ DATABASE_URL: conn.url });
    await prisma.$transaction([
      prisma.databaseConnection.updateMany({ data: { isPrimary: false } }),
      prisma.databaseConnection.update({ where: { id }, data: { isPrimary: true } }),
    ]);
    await writeAudit({ req, action: 'promote', entity: 'DatabaseConnection', entityId: id });
    await logSystem('warn', 'system', 'Primary database URL changed; restart required', {
      provider: conn.provider,
      backup: env.backup,
    });
    res.json({
      ok: true,
      restartRequired: true,
      message:
        'DATABASE_URL updated in .env. Update prisma/schema.prisma `provider` if it differs and restart the server, then run `npx prisma migrate deploy && npm run db:seed`.',
      backupPath: env.backup,
    });
  }),
);

router.post(
  '/database/test',
  requireSuperAdmin(),
  asyncHandler(async (req, res) => {
    requireFields(req.body, ['provider', 'url']);
    const { provider, url } = req.body;
    if (!VALID_PROVIDERS.has(provider)) throw badRequest('Invalid provider');
    res.json({
      ok: true,
      message: 'Connection string accepted. Promote it to validate at startup.',
      provider,
      url: maskUrl(url),
    });
  }),
);

router.post(
  '/database/sql/init',
  requireSuperAdmin(),
  asyncHandler(async (req, res) => {
    const sql = String(req.body?.sql || '').trim();
    if (!sql) throw badRequest('SQL required');
    if (sql.length > 100000) throw badRequest('SQL too large');
    const statements = sql.split(/;\s*\n/).map((s) => s.trim()).filter(Boolean);
    const results = [];
    for (const stmt of statements) {
      try {
        await prisma.$executeRawUnsafe(stmt);
        results.push({ stmt, ok: true });
      } catch (err) {
        results.push({ stmt, ok: false, error: String(err.message || err) });
      }
    }
    await writeAudit({ req, action: 'init_sql', entity: 'Database', metadata: { count: statements.length } });
    await logSystem('info', 'system', 'Database init SQL executed', { count: statements.length });
    res.json({ ok: true, results });
  }),
);

export default router;
