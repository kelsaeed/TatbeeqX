import { Router } from 'express';
import { prisma } from '../lib/prisma.js';
import { authenticate } from '../middleware/auth.js';
import { requireSuperAdmin } from '../middleware/permission.js';
import { asyncHandler, badRequest, notFound } from '../lib/http.js';
import { parseId, requireFields } from '../middleware/validate.js';
import { writeAudit } from '../lib/audit.js';
import { applyTemplateData, captureCurrent, SUPPORTED_KINDS } from '../lib/templates.js';

const router = Router();
router.use(authenticate);
router.use(requireSuperAdmin());

function toDto(t) {
  let parsed = {};
  try {
    parsed = t.data ? JSON.parse(t.data) : {};
  } catch {
    parsed = {};
  }
  return {
    id: t.id,
    code: t.code,
    name: t.name,
    description: t.description,
    kind: t.kind,
    data: parsed,
    createdAt: t.createdAt,
    updatedAt: t.updatedAt,
  };
}

router.get(
  '/kinds',
  asyncHandler(async (_req, res) => {
    res.json({ items: SUPPORTED_KINDS });
  }),
);

// Phase 4.15 follow-up — pull a `subsystem` summary out of each
// template's payload so the list page can show captured branding /
// modules at a glance without a second round-trip per row. Bounded
// payload (just counts + branding keys), so overhead is negligible
// even with hundreds of templates.
function subsystemSummary(parsed) {
  const out = { hasBranding: false, moduleCount: 0 };
  if (!parsed || typeof parsed !== 'object') return out;
  if (parsed.branding && typeof parsed.branding === 'object') {
    const keys = Object.keys(parsed.branding).filter((k) => {
      const v = parsed.branding[k];
      return typeof v === 'string' && v.trim().length > 0;
    });
    if (keys.length > 0) {
      out.hasBranding = true;
      out.brandingKeys = keys;
      if (typeof parsed.branding.appName === 'string' && parsed.branding.appName.trim().length > 0) {
        out.appName = parsed.branding.appName.trim();
      }
    }
  }
  if (Array.isArray(parsed.modules)) {
    const cleaned = parsed.modules.filter((m) => typeof m === 'string');
    out.moduleCount = cleaned.length;
    if (cleaned.length > 0) out.modules = cleaned;
  }
  return out;
}

router.get(
  '/',
  asyncHandler(async (_req, res) => {
    const items = await prisma.systemTemplate.findMany({ orderBy: { id: 'desc' } });
    res.json({
      items: items.map((t) => {
        let parsed = {};
        try { parsed = t.data ? JSON.parse(t.data) : {}; } catch { parsed = {}; }
        return {
          id: t.id,
          code: t.code,
          name: t.name,
          description: t.description,
          kind: t.kind,
          createdAt: t.createdAt,
          updatedAt: t.updatedAt,
          subsystem: subsystemSummary(parsed),
        };
      }),
    });
  }),
);

router.get(
  '/:id',
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const t = await prisma.systemTemplate.findUnique({ where: { id } });
    if (!t) throw notFound('Template not found');
    res.json(toDto(t));
  }),
);

router.post(
  '/capture',
  asyncHandler(async (req, res) => {
    requireFields(req.body, ['code', 'name']);
    const { code, name, description = null, kind = 'full' } = req.body;
    if (!SUPPORTED_KINDS.includes(kind)) throw badRequest(`Unsupported kind: ${kind}. Supported: ${SUPPORTED_KINDS.join(', ')}`);
    const data = await captureCurrent({ kind });
    const created = await prisma.systemTemplate.create({
      data: { code, name, description, kind, data: JSON.stringify(data) },
    });
    await writeAudit({ req, action: 'capture', entity: 'SystemTemplate', entityId: created.id, metadata: { kind } });
    res.status(201).json(toDto(created));
  }),
);

router.post(
  '/import',
  asyncHandler(async (req, res) => {
    requireFields(req.body, ['code', 'name', 'data']);
    const { code, name, description = null, data } = req.body;
    if (typeof data !== 'object') throw badRequest('data must be an object');
    const kind = (data.kind && SUPPORTED_KINDS.includes(data.kind)) ? data.kind : 'full';
    const created = await prisma.systemTemplate.create({
      data: { code, name, description, kind, data: JSON.stringify(data) },
    });
    await writeAudit({ req, action: 'import', entity: 'SystemTemplate', entityId: created.id });
    res.status(201).json(toDto(created));
  }),
);

router.post(
  '/:id/apply',
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const t = await prisma.systemTemplate.findUnique({ where: { id } });
    if (!t) throw notFound('Template not found');
    let data;
    try {
      data = JSON.parse(t.data);
    } catch {
      throw badRequest('Template payload is corrupted.');
    }
    const summary = await applyTemplateData(data);
    await writeAudit({ req, action: 'apply', entity: 'SystemTemplate', entityId: id, metadata: summary });
    res.json({ ok: true, ...summary });
  }),
);

router.put(
  '/:id/subsystem',
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    const t = await prisma.systemTemplate.findUnique({ where: { id } });
    if (!t) throw notFound('Template not found');
    if (t.kind !== 'full' && t.kind !== 'business') {
      throw badRequest('Subsystem branding/modules can only be edited on `full` or `business` templates');
    }
    let data;
    try {
      data = JSON.parse(t.data);
    } catch {
      throw badRequest('Template payload is corrupted.');
    }

    const { branding, modules } = req.body ?? {};
    if (modules !== undefined) {
      if (!Array.isArray(modules)) throw badRequest('modules must be an array of strings');
      const cleaned = Array.from(new Set(
        modules
          .filter((m) => typeof m === 'string' && m.trim().length > 0)
          .map((m) => m.trim()),
      ));
      if (cleaned.length > 0) data.modules = cleaned;
      else delete data.modules;
    }
    if (branding !== undefined) {
      if (branding === null) {
        delete data.branding;
      } else if (typeof branding !== 'object' || Array.isArray(branding)) {
        throw badRequest('branding must be an object or null');
      } else {
        const cleaned = {};
        for (const [k, v] of Object.entries(branding)) {
          if (typeof v === 'string' && v.trim().length > 0) cleaned[k] = v.trim();
        }
        if (Object.keys(cleaned).length > 0) data.branding = cleaned;
        else delete data.branding;
      }
    }

    const updated = await prisma.systemTemplate.update({
      where: { id },
      data: { data: JSON.stringify(data) },
    });
    await writeAudit({
      req,
      action: 'update_subsystem',
      entity: 'SystemTemplate',
      entityId: id,
      metadata: {
        hasBranding: !!data.branding,
        moduleCount: Array.isArray(data.modules) ? data.modules.length : 0,
      },
    });
    res.json(toDto(updated));
  }),
);

router.delete(
  '/:id',
  asyncHandler(async (req, res) => {
    const id = parseId(req.params.id);
    await prisma.systemTemplate.delete({ where: { id } });
    await writeAudit({ req, action: 'delete', entity: 'SystemTemplate', entityId: id });
    res.json({ ok: true });
  }),
);

export default router;
