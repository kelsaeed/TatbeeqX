import { prisma } from './prisma.js';

export const STATUS = {
  PENDING: 'pending',
  APPROVED: 'approved',
  REJECTED: 'rejected',
  CANCELLED: 'cancelled',
};

export async function createApprovalRequest({
  entity,
  entityId = null,
  title,
  description = null,
  payload = {},
  requestedById,
}) {
  if (!entity) throw new Error('entity required');
  if (!title) throw new Error('title required');
  if (!requestedById) throw new Error('requestedById required');
  return prisma.approvalRequest.create({
    data: {
      entity,
      entityId: entityId != null ? String(entityId) : null,
      title,
      description,
      payload: JSON.stringify(payload || {}),
      status: STATUS.PENDING,
      requestedById,
    },
  });
}

export async function decideApproval({ id, decidedById, decision, decisionNote = null }) {
  if (!id) throw new Error('id required');
  if (!decidedById) throw new Error('decidedById required');
  if (![STATUS.APPROVED, STATUS.REJECTED, STATUS.CANCELLED].includes(decision)) {
    throw new Error(`Invalid decision: ${decision}`);
  }
  const existing = await prisma.approvalRequest.findUnique({ where: { id } });
  if (!existing) throw new Error('Approval request not found');
  if (existing.status !== STATUS.PENDING) throw new Error(`Already ${existing.status}`);
  return prisma.approvalRequest.update({
    where: { id },
    data: {
      status: decision,
      decidedById,
      decisionNote,
      decidedAt: new Date(),
    },
  });
}
