import { Router } from 'express';
import crypto from 'node:crypto';
import { prisma } from '../lib/prisma.js';
import { authenticate } from '../middleware/auth.js';
import { requirePermission } from '../middleware/permission.js';
import { asyncHandler, badRequest, notFound } from '../lib/http.js';
import { parseId, requireFields, parsePagination } from '../middleware/validate.js';
import { writeAudit } from '../lib/audit.js';
import { dispatchEvent } from '../lib/webhooks.js';

const router = Router();
router.use(authenticate);

const SUPPORTED_EVENTS = [
  '*',
  'approval.requested',
  'approval.approved',
  'approval.rejected',
  'approval.cancelled',
  'webhook.test',
  'backup.created',
];

function toDto(s) {
  let events = [];
  try { events = s.events ? JSON.parse(s.events) : []; } catch { events = []; }
  return {
    id: s.id,
    code: s.code,
    name: s.name,
    url: s.url,
    secret: s.secret ? '***' : null,
    events,
    enabled: s.enabled,
    createdAt: s.createdAt,
    updatedAt: s.updatedAt,
  };
}

router.get(
  '/events',
  asyncHandler(async (_req, res) => {
    res.json({ items: SUPPORTED_EVENTS });
  }),
);

router.get(
  '/',
  requirePermission('webhooks.view'),
  asyncHandler(async (_req, res) => {
    const items = await prisma.webhookSubscription.findMany({ orderBy: { id: 'asc' } });
    res.json({ items: items.map(toDto) });
  }),
);

router.get(
  '/:id',
  requirePermission('webhooks.view'),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const s = await prisma.webhookSubscription.findUnique({ where: { id } });
    if (!s) throw notFound('Subscription not found');
    res.json(toDto(s));
  }),
);

router.post(
  '/',
  requirePermission('webhooks.create'),
  asyncHandler(async (req, res) => {
    requireFields(req.body, ['code', 'name', 'url']);
    const { code, name, url, events = ['*'], enabled = true } = req.body;
    const secret = req.body.secret ?? crypto.randomBytes(24).toString('hex');
    if (!Array.isArray(events) || events.length === 0) throw badRequest('events must be a non-empty array');
    const bad = events.find((e) => !SUPPORTED_EVENTS.includes(e));
    if (bad) throw badRequest(`Unknown event: ${bad}`);
    if (!/^https?:\/\//i.test(url)) throw badRequest('url must be http:// or https://');
    const created = await prisma.webhookSubscription.create({
      data: { code, name, url, secret, events: JSON.stringify(events), enabled },
    });
    await writeAudit({ req, action: 'create', entity: 'WebhookSubscription', entityId: created.id });
    // Reveal the secret once on create so the operator can store it.
    res.status(201).json({ ...toDto(created), secret });
  }),
);

router.put(
  '/:id',
  requirePermission('webhooks.edit'),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const update = {};
    for (const f of ['name', 'url', 'enabled']) {
      if (req.body[f] !== undefined) update[f] = req.body[f];
    }
    if (req.body.events !== undefined) {
      if (!Array.isArray(req.body.events) || req.body.events.length === 0) throw badRequest('events must be a non-empty array');
      const bad = req.body.events.find((e) => !SUPPORTED_EVENTS.includes(e));
      if (bad) throw badRequest(`Unknown event: ${bad}`);
      update.events = JSON.stringify(req.body.events);
    }
    if (req.body.url && !/^https?:\/\//i.test(req.body.url)) throw badRequest('url must be http:// or https://');
    if (req.body.secret) update.secret = req.body.secret;
    const updated = await prisma.webhookSubscription.update({ where: { id }, data: update });
    await writeAudit({ req, action: 'update', entity: 'WebhookSubscription', entityId: id });
    res.json(toDto(updated));
  }),
);

router.delete(
  '/:id',
  requirePermission('webhooks.delete'),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    await prisma.webhookSubscription.delete({ where: { id } });
    await writeAudit({ req, action: 'delete', entity: 'WebhookSubscription', entityId: id });
    res.json({ ok: true });
  }),
);

router.post(
  '/:id/test',
  requirePermission('webhooks.edit'),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const sub = await prisma.webhookSubscription.findUnique({ where: { id } });
    if (!sub) throw notFound('Subscription not found');
    await dispatchEvent('webhook.test', { subscriptionId: id, message: 'Test from TatbeeqX' });
    await writeAudit({ req, action: 'test', entity: 'WebhookSubscription', entityId: id });
    res.json({ ok: true });
  }),
);

router.get(
  '/:id/deliveries',
  requirePermission('webhooks.view'),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const { skip, take, page, pageSize } = parsePagination(req.query);
    const [items, total] = await prisma.$transaction([
      prisma.webhookDelivery.findMany({
        where: { subscriptionId: id },
        skip,
        take,
        orderBy: { id: 'desc' },
      }),
      prisma.webhookDelivery.count({ where: { subscriptionId: id } }),
    ]);
    res.json({ items, total, page, pageSize });
  }),
);

export default router;
