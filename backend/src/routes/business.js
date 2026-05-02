import { Router } from 'express';
import { prisma } from '../lib/prisma.js';
import { authenticate } from '../middleware/auth.js';
import { requireSuperAdmin } from '../middleware/permission.js';
import { asyncHandler, badRequest } from '../lib/http.js';
import { applyPreset, listPresets } from '../lib/business_presets.js';
import { writeAudit } from '../lib/audit.js';

const router = Router();

router.get(
  '/presets',
  asyncHandler(async (_req, res) => {
    res.json({ items: listPresets() });
  }),
);

router.get(
  '/state',
  authenticate,
  asyncHandler(async (_req, res) => {
    const setting = await prisma.setting.findFirst({ where: { companyId: null, key: 'system.business_type' } });
    const customCount = await prisma.customEntity.count({ where: { isActive: true } });
    res.json({
      configured: !!setting,
      businessType: setting?.value ?? null,
      customEntityCount: customCount,
    });
  }),
);

router.use(authenticate);
router.use(requireSuperAdmin());

router.post(
  '/apply',
  asyncHandler(async (req, res) => {
    const { code } = req.body || {};
    if (!code) throw badRequest('code is required');
    const result = await applyPreset(code);
    await writeAudit({ req, action: 'apply_preset', entity: 'BusinessProfile', metadata: result });
    res.json({ ok: true, ...result });
  }),
);

export default router;
