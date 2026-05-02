import { Router } from 'express';
import { prisma } from '../lib/prisma.js';
import { authenticate } from '../middleware/auth.js';
import { requireSuperAdmin } from '../middleware/permission.js';
import { asyncHandler, badRequest, notFound } from '../lib/http.js';
import { describeTable, listTables, previewRows } from '../lib/db_introspect.js';
import { runQuery } from '../lib/sql_runner.js';
import { writeAudit } from '../lib/audit.js';
import { parseId, requireFields } from '../middleware/validate.js';

const router = Router();
router.use(authenticate);
router.use(requireSuperAdmin());

router.get(
  '/tables',
  asyncHandler(async (_req, res) => {
    res.json({ items: await listTables() });
  }),
);

router.get(
  '/tables/:name',
  asyncHandler(async (req, res) => {
    const info = await describeTable(req.params.name);
    res.json(info);
  }),
);

router.get(
  '/tables/:name/preview',
  asyncHandler(async (req, res) => {
    const limit = Number(req.query.limit) || 50;
    res.json({ items: await previewRows(req.params.name, limit) });
  }),
);

router.post(
  '/query',
  asyncHandler(async (req, res) => {
    requireFields(req.body, ['sql']);
    const { sql, allowWrite = false, connectionId = null } = req.body;
    let result;
    try {
      result = await runQuery(sql, { allowWrite, maxRows: 1000, connectionId });
    } catch (e) {
      if (e && e.status) throw badRequest(e.message);
      throw badRequest(e.message || String(e));
    }
    await writeAudit({
      req,
      action: 'sql_query',
      entity: 'Database',
      metadata: { allowWrite, length: sql.length, kind: result.kind, connectionId: connectionId ?? null },
    });
    res.json(result);
  }),
);

router.get(
  '/queries',
  asyncHandler(async (_req, res) => {
    const items = await prisma.savedQuery.findMany({ orderBy: { id: 'desc' } });
    res.json({ items });
  }),
);

router.post(
  '/queries',
  asyncHandler(async (req, res) => {
    requireFields(req.body, ['name', 'sql']);
    const { name, sql, description = null, isReadOnly = true } = req.body;
    const created = await prisma.savedQuery.create({ data: { name, sql, description, isReadOnly } });
    await writeAudit({ req, action: 'create', entity: 'SavedQuery', entityId: created.id });
    res.status(201).json(created);
  }),
);

router.put(
  '/queries/:id',
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const existing = await prisma.savedQuery.findUnique({ where: { id } });
    if (!existing) throw notFound('Saved query not found');
    const { name, sql, description, isReadOnly } = req.body;
    const updated = await prisma.savedQuery.update({
      where: { id },
      data: {
        name: name ?? existing.name,
        sql: sql ?? existing.sql,
        description: description ?? existing.description,
        isReadOnly: isReadOnly ?? existing.isReadOnly,
      },
    });
    await writeAudit({ req, action: 'update', entity: 'SavedQuery', entityId: id });
    res.json(updated);
  }),
);

router.delete(
  '/queries/:id',
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    await prisma.savedQuery.delete({ where: { id } });
    await writeAudit({ req, action: 'delete', entity: 'SavedQuery', entityId: id });
    res.json({ ok: true });
  }),
);

export default router;
