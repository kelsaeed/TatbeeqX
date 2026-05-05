import { Router } from 'express';
import { prisma } from '../lib/prisma.js';
import { authenticate } from '../middleware/auth.js';
import { requirePermission, requireSuperAdmin } from '../middleware/permission.js';
import { asyncHandler, badRequest, conflict, notFound } from '../lib/http.js';
import { parseId, requireFields } from '../middleware/validate.js';
import { writeAudit } from '../lib/audit.js';
import { hasPermission } from '../lib/permissions.js';
import { sanitizeHtmlBlock } from '../lib/html_sanitize.js';
import { parsePage } from '../lib/page_parse.js';
import { loadSidebarPages } from '../lib/sidebar_pages.js';

const router = Router();

const ROUTE_RE = /^\/[a-zA-Z0-9_\-/]{0,120}$/;
const CODE_RE = /^[a-z][a-z0-9_]{0,62}$/;

function parseBlock(b) {
  let config = {};
  try { config = b.config ? JSON.parse(b.config) : {}; } catch { config = {}; }
  return { ...b, config };
}

function sanitizeBlockConfig(type, config) {
  if (!config || typeof config !== 'object') return config;
  if (type === 'html' && typeof config.html === 'string') {
    return { ...config, html: sanitizeHtmlBlock(config.html) };
  }
  return config;
}

router.use(authenticate);

router.get(
  '/',
  requirePermission('pages.view'),
  asyncHandler(async (req, res) => {
    const items = await prisma.page.findMany({
      orderBy: [{ sortOrder: 'asc' }, { id: 'asc' }],
    });
    res.json({ items: items.map(parsePage) });
  }),
);

router.get(
  '/analytics',
  requirePermission('pages.view'),
  asyncHandler(async (_req, res) => {
    const [pageCount, blockCount, byType, emptyPages] = await Promise.all([
      prisma.page.count(),
      prisma.pageBlock.count(),
      prisma.pageBlock.groupBy({ by: ['type'], _count: { _all: true }, orderBy: { _count: { type: 'desc' } } }),
      prisma.page.findMany({ where: { blocks: { none: {} } }, select: { id: true, code: true, title: true, route: true } }),
    ]);
    res.json({
      pageCount,
      blockCount,
      blocksPerPage: pageCount > 0 ? blockCount / pageCount : 0,
      byType: byType.map((b) => ({ type: b.type, count: b._count._all })),
      emptyPages,
    });
  }),
);

router.get(
  '/sidebar',
  asyncHandler(async (req, res) => {
    const items = await loadSidebarPages(req.user, req.permissions ?? new Set());
    res.json({ items });
  }),
);

router.get(
  '/by-route',
  asyncHandler(async (req, res) => {
    const route = req.query.route ? String(req.query.route) : null;
    const code = req.query.code ? String(req.query.code) : null;
    if (!route && !code) throw badRequest('route or code required');
    const page = await prisma.page.findFirst({
      where: {
        isActive: true,
        ...(route ? { route } : {}),
        ...(code ? { code } : {}),
      },
      include: { blocks: { orderBy: [{ sortOrder: 'asc' }, { id: 'asc' }] } },
    });
    if (!page) throw notFound('Page not found');
    if (page.permissionCode && !req.user.isSuperAdmin) {
      const ok = hasPermission(req.permissions ?? new Set(), page.permissionCode);
      if (!ok) throw notFound('Page not found');
    }
    res.json({
      page: parsePage(page),
      blocks: page.blocks.map(parseBlock),
    });
  }),
);

router.get(
  '/:id',
  requirePermission('pages.view'),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const page = await prisma.page.findUnique({
      where: { id },
      include: { blocks: { orderBy: [{ sortOrder: 'asc' }, { id: 'asc' }] } },
    });
    if (!page) throw notFound('Page not found');
    res.json({ page: parsePage(page), blocks: page.blocks.map(parseBlock) });
  }),
);

router.post(
  '/',
  requirePermission('pages.create'),
  asyncHandler(async (req, res) => {
    requireFields(req.body, ['code', 'title', 'route']);
    const { code, title, route, icon, description, permissionCode, layout, background, isActive, showInSidebar, sortOrder, isPublic, data } = req.body;
    if (!CODE_RE.test(code)) throw badRequest('Invalid code (lowercase, snake_case)');
    if (!ROUTE_RE.test(route)) throw badRequest('Invalid route (must start with /)');
    const dup = await prisma.page.findFirst({ where: { OR: [{ code }, { route }] } });
    if (dup) throw conflict('A page with that code or route already exists');
    const created = await prisma.page.create({
      data: {
        code, title, route,
        titles: JSON.stringify(req.body.titles ?? {}),
        icon: icon ?? null,
        description: description ?? null,
        permissionCode: permissionCode ?? null,
        layout: layout ?? 'stack',
        background: background ?? null,
        isActive: isActive ?? true,
        showInSidebar: showInSidebar ?? true,
        sortOrder: sortOrder ?? 100,
        isPublic: isPublic ?? false,
        data: JSON.stringify(data ?? {}),
      },
    });
    await writeAudit({ req, action: 'create', entity: 'Page', entityId: created.id });
    res.status(201).json(parsePage(created));
  }),
);

router.put(
  '/:id',
  requirePermission('pages.edit'),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const update = {};
    const fields = ['title', 'icon', 'description', 'permissionCode', 'layout', 'background', 'isActive', 'showInSidebar', 'sortOrder', 'isPublic'];
    for (const f of fields) if (req.body[f] !== undefined) update[f] = req.body[f];
    if (req.body.route !== undefined) {
      if (!ROUTE_RE.test(req.body.route)) throw badRequest('Invalid route');
      update.route = req.body.route;
    }
    if (req.body.data !== undefined) update.data = JSON.stringify(req.body.data ?? {});
    if (req.body.titles !== undefined) update.titles = JSON.stringify(req.body.titles ?? {});
    const updated = await prisma.page.update({ where: { id }, data: update });
    await writeAudit({ req, action: 'update', entity: 'Page', entityId: id });
    res.json(parsePage(updated));
  }),
);

router.delete(
  '/:id',
  requirePermission('pages.delete'),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    await prisma.page.delete({ where: { id } });
    await writeAudit({ req, action: 'delete', entity: 'Page', entityId: id });
    res.json({ ok: true });
  }),
);

router.post(
  '/:id/blocks',
  requirePermission('pages.edit'),
  asyncHandler(async (req, res) => {
    const pageId = parseId(req.params.id);
    requireFields(req.body, ['type']);
    const { type, parentId = null, sortOrder = 0, config = {}, isActive = true } = req.body;
    const cleanConfig = sanitizeBlockConfig(type, config);
    const created = await prisma.pageBlock.create({
      data: { pageId, parentId, type, sortOrder, isActive, config: JSON.stringify(cleanConfig) },
    });
    await writeAudit({ req, action: 'create', entity: 'PageBlock', entityId: created.id });
    res.status(201).json(parseBlock(created));
  }),
);

router.put(
  '/:id/blocks/:blockId',
  requirePermission('pages.edit'),
  asyncHandler(async (req, res) => {
    const blockId = parseId(req.params.blockId);
    const update = {};
    if (req.body.type !== undefined) update.type = req.body.type;
    if (req.body.parentId !== undefined) update.parentId = req.body.parentId;
    if (req.body.sortOrder !== undefined) update.sortOrder = req.body.sortOrder;
    if (req.body.isActive !== undefined) update.isActive = req.body.isActive;
    if (req.body.config !== undefined) {
      const existing = await prisma.pageBlock.findUnique({ where: { id: blockId } });
      const blockType = req.body.type ?? existing?.type;
      const cleanConfig = sanitizeBlockConfig(blockType, req.body.config ?? {});
      update.config = JSON.stringify(cleanConfig);
    }
    const updated = await prisma.pageBlock.update({ where: { id: blockId }, data: update });
    await writeAudit({ req, action: 'update', entity: 'PageBlock', entityId: blockId });
    res.json(parseBlock(updated));
  }),
);

router.delete(
  '/:id/blocks/:blockId',
  requirePermission('pages.edit'),
  asyncHandler(async (req, res) => {
    const blockId = parseId(req.params.blockId);
    await prisma.pageBlock.delete({ where: { id: blockId } });
    await writeAudit({ req, action: 'delete', entity: 'PageBlock', entityId: blockId });
    res.json({ ok: true });
  }),
);

router.post(
  '/:id/reorder',
  requirePermission('pages.edit'),
  asyncHandler(async (req, res) => {
    const pageId = parseId(req.params.id);
    const order = Array.isArray(req.body.order) ? req.body.order : [];
    await prisma.$transaction(
      order.map((item, idx) =>
        prisma.pageBlock.update({
          where: { id: Number(item.id) },
          data: { sortOrder: idx, parentId: item.parentId ?? null },
        }),
      ),
    );
    await writeAudit({ req, action: 'reorder', entity: 'Page', entityId: pageId });
    res.json({ ok: true });
  }),
);

export default router;
