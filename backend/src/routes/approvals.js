import { Router } from 'express';
import { prisma } from '../lib/prisma.js';
import { authenticate } from '../middleware/auth.js';
import { requirePermission } from '../middleware/permission.js';
import { hasPermission } from '../lib/permissions.js';
import { asyncHandler, badRequest, forbidden, notFound } from '../lib/http.js';
import { parseId, parsePagination, requireFields } from '../middleware/validate.js';
import { writeAudit } from '../lib/audit.js';
import { createApprovalRequest, decideApproval, STATUS } from '../lib/approvals.js';
import { fireAndForget } from '../lib/webhooks.js';
import { runHandlers } from '../lib/approval_handlers.js';

const router = Router();
router.use(authenticate);

function toDto(r) {
  let payload = {};
  try { payload = r.payload ? JSON.parse(r.payload) : {}; } catch { payload = {}; }
  return {
    id: r.id,
    entity: r.entity,
    entityId: r.entityId,
    title: r.title,
    description: r.description,
    payload,
    status: r.status,
    requestedById: r.requestedById,
    requestedBy: r.requestedBy ? { id: r.requestedBy.id, fullName: r.requestedBy.fullName, username: r.requestedBy.username } : null,
    decidedById: r.decidedById,
    decidedBy: r.decidedBy ? { id: r.decidedBy.id, fullName: r.decidedBy.fullName, username: r.decidedBy.username } : null,
    decisionNote: r.decisionNote,
    createdAt: r.createdAt,
    decidedAt: r.decidedAt,
  };
}

router.get(
  '/',
  requirePermission('approvals.view'),
  asyncHandler(async (req, res) => {
    const { skip, take, page, pageSize } = parsePagination(req.query);
    const where = {};
    if (req.query.status) where.status = String(req.query.status);
    if (req.query.entity) where.entity = String(req.query.entity);
    if (req.query.requestedById) where.requestedById = Number(req.query.requestedById);
    const [items, total] = await prisma.$transaction([
      prisma.approvalRequest.findMany({
        where,
        skip,
        take,
        orderBy: { id: 'desc' },
        include: { requestedBy: true, decidedBy: true },
      }),
      prisma.approvalRequest.count({ where }),
    ]);
    res.json({ items: items.map(toDto), total, page, pageSize });
  }),
);

router.get(
  '/pending-count',
  asyncHandler(async (_req, res) => {
    const total = await prisma.approvalRequest.count({ where: { status: STATUS.PENDING } });
    res.json({ total });
  }),
);

router.get(
  '/:id',
  requirePermission('approvals.view'),
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const item = await prisma.approvalRequest.findUnique({
      where: { id },
      include: { requestedBy: true, decidedBy: true },
    });
    if (!item) throw notFound('Approval request not found');
    res.json(toDto(item));
  }),
);

router.post(
  '/',
  asyncHandler(async (req, res) => {
    requireFields(req.body, ['entity', 'title']);
    const { entity, entityId = null, title, description = null, payload = {} } = req.body;
    const created = await createApprovalRequest({
      entity,
      entityId,
      title,
      description,
      payload,
      requestedById: req.user.id,
    });
    await writeAudit({ req, action: 'request', entity: 'ApprovalRequest', entityId: created.id, metadata: { entity, title } });
    const dto = toDto(await prisma.approvalRequest.findUnique({ where: { id: created.id }, include: { requestedBy: true, decidedBy: true } }));
    fireAndForget('approval.requested', dto);
    res.status(201).json(dto);
  }),
);

async function ensureCanDecide(req, entity) {
  if (req.user.isSuperAdmin) return;
  const code = `${entity}.approve`;
  const ok = hasPermission(req.permissions ?? new Set(), code);
  if (!ok) throw forbidden(`Need permission: ${code}`);
}

router.post(
  '/:id/approve',
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const existing = await prisma.approvalRequest.findUnique({ where: { id } });
    if (!existing) throw notFound('Approval request not found');
    await ensureCanDecide(req, existing.entity);
    const updated = await decideApproval({
      id,
      decidedById: req.user.id,
      decision: STATUS.APPROVED,
      decisionNote: req.body?.note ?? null,
    });
    await writeAudit({ req, action: 'approve', entity: 'ApprovalRequest', entityId: id });
    const dto = toDto(updated);
    await runHandlers('approved', dto);
    fireAndForget('approval.approved', dto);
    res.json(dto);
  }),
);

router.post(
  '/:id/reject',
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const existing = await prisma.approvalRequest.findUnique({ where: { id } });
    if (!existing) throw notFound('Approval request not found');
    await ensureCanDecide(req, existing.entity);
    const updated = await decideApproval({
      id,
      decidedById: req.user.id,
      decision: STATUS.REJECTED,
      decisionNote: req.body?.note ?? null,
    });
    await writeAudit({ req, action: 'reject', entity: 'ApprovalRequest', entityId: id });
    const dto = toDto(updated);
    await runHandlers('rejected', dto);
    fireAndForget('approval.rejected', dto);
    res.json(dto);
  }),
);

router.post(
  '/:id/cancel',
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const existing = await prisma.approvalRequest.findUnique({ where: { id } });
    if (!existing) throw notFound('Approval request not found');
    if (existing.requestedById !== req.user.id && !req.user.isSuperAdmin) {
      throw forbidden('Only the requester (or Super Admin) can cancel.');
    }
    if (existing.status !== STATUS.PENDING) throw badRequest(`Already ${existing.status}`);
    const updated = await decideApproval({
      id,
      decidedById: req.user.id,
      decision: STATUS.CANCELLED,
      decisionNote: req.body?.note ?? null,
    });
    await writeAudit({ req, action: 'cancel', entity: 'ApprovalRequest', entityId: id });
    fireAndForget('approval.cancelled', toDto(updated));
    res.json(toDto(updated));
  }),
);

export default router;
