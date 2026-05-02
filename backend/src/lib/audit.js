import { prisma } from './prisma.js';

export async function writeAudit({ req, action, entity, entityId, metadata }) {
  try {
    await prisma.auditLog.create({
      data: {
        userId: req?.user?.id ?? null,
        companyId: req?.user?.companyId ?? null,
        action,
        entity,
        entityId: entityId != null ? String(entityId) : null,
        metadata: metadata ? JSON.stringify(metadata) : null,
        ipAddress: req?.ip ?? null,
        userAgent: req?.get?.('user-agent') ?? null,
      },
    });
  } catch (err) {
    console.error('audit log failed', err);
  }
}
