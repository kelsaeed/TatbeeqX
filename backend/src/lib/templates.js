import { prisma } from './prisma.js';
import { registerCustomEntity } from './business_presets.js';
import { setSubsystemInfo } from './subsystem.js';

export const SUPPORTED_KINDS = ['theme', 'business', 'pages', 'reports', 'queries', 'full'];

const FULL_KINDS = new Set(['theme', 'business', 'pages', 'reports', 'queries']);

function safeParse(s, fallback) {
  if (typeof s !== 'string' || s.length === 0) return fallback;
  try { return JSON.parse(s); } catch { return fallback; }
}

export async function captureCurrent({ kind = 'full' } = {}) {
  if (!SUPPORTED_KINDS.includes(kind)) throw new Error(`Unsupported template kind: ${kind}`);

  // Phase 4.12 — version bumped to 3 to signal subsystem metadata.
  // Older v2 captures still apply cleanly (the new fields are optional).
  const out = { kind, version: 3, createdAt: new Date().toISOString() };
  const want = (k) => kind === 'full' ? FULL_KINDS.has(k) : kind === k;

  if (want('theme')) {
    const active = await prisma.theme.findFirst({ where: { isActive: true } });
    const def = active || (await prisma.theme.findFirst({ where: { isDefault: true } }));
    if (def) {
      out.theme = { name: def.name, data: safeParse(def.data, {}) };
    }
  }

  if (want('business')) {
    const entities = await prisma.customEntity.findMany({ where: { isActive: true } });
    out.entities = entities.map((e) => {
      const cfg = safeParse(e.config, { columns: [] });
      return {
        code: e.code,
        tableName: e.tableName,
        label: e.label,
        singular: e.singular,
        icon: e.icon,
        category: e.category,
        columns: cfg.columns ?? [],
      };
    });
    const setting = await prisma.setting.findFirst({ where: { companyId: null, key: 'system.business_type' } });
    out.businessType = setting?.value ?? null;
  }

  if (want('pages')) {
    const pages = await prisma.page.findMany({
      include: { blocks: { orderBy: [{ sortOrder: 'asc' }, { id: 'asc' }] } },
      orderBy: [{ sortOrder: 'asc' }, { id: 'asc' }],
    });
    out.pages = pages.map((p) => ({
      code: p.code,
      title: p.title,
      route: p.route,
      icon: p.icon,
      description: p.description,
      permissionCode: p.permissionCode,
      layout: p.layout,
      background: p.background,
      isPublic: p.isPublic,
      isActive: p.isActive,
      showInSidebar: p.showInSidebar,
      sortOrder: p.sortOrder,
      data: safeParse(p.data, {}),
      blocks: p.blocks.map((b) => ({
        // local id used to wire parent references on apply
        localId: b.id,
        parentLocalId: b.parentId ?? null,
        type: b.type,
        sortOrder: b.sortOrder,
        isActive: b.isActive,
        config: safeParse(b.config, {}),
      })),
    }));
  }

  if (want('reports')) {
    const reports = await prisma.report.findMany({ orderBy: { id: 'asc' } });
    out.reports = reports.map((r) => ({
      code: r.code,
      name: r.name,
      description: r.description,
      category: r.category,
      builder: r.builder,
      config: safeParse(r.config, {}),
      isSystem: r.isSystem,
      isActive: r.isActive,
    }));
  }

  if (want('queries')) {
    const queries = await prisma.savedQuery.findMany({ orderBy: { id: 'asc' } });
    out.queries = queries.map((q) => ({
      name: q.name,
      description: q.description,
      sql: q.sql,
      isReadOnly: q.isReadOnly,
    }));
  }

  // Phase 4.17 — workflow definitions ride along in `full` and
  // `business` exports. Per-install runtime state (runs/steps/locks/
  // nextRunAt) is excluded — those rebuild on the receiving install.
  if (kind === 'full' || kind === 'business') {
    const wfs = await prisma.workflow.findMany({ orderBy: { id: 'asc' } });
    out.workflows = wfs.map((w) => ({
      code: w.code,
      name: w.name,
      description: w.description,
      triggerType: w.triggerType,
      triggerConfig: safeParse(w.triggerConfig, {}),
      actions: safeParse(w.actions, []),
      enabled: w.enabled,
    }));
  }

  // Phase 4.12 — capture subsystem metadata so a `full` template can be
  // shipped as a self-contained customer install (modules drive sidebar
  // filtering; branding overrides app name / logo / primary color).
  // Pulls from the same `system.subsystem_info` settings row that
  // `setSubsystemInfo` writes to.
  if (kind === 'full' || kind === 'business') {
    const setting = await prisma.setting.findFirst({
      where: { companyId: null, key: 'system.subsystem_info' },
    });
    if (setting?.value) {
      const info = safeParse(setting.value, null);
      if (info && typeof info === 'object') {
        if (Array.isArray(info.modules) && info.modules.length > 0) out.modules = info.modules;
        if (info.branding && typeof info.branding === 'object') out.branding = info.branding;
      }
    }
  }

  return out;
}

export async function applyTemplateData(data) {
  if (!data || typeof data !== 'object') throw new Error('Invalid template data');
  const summary = { theme: false, entities: 0, pages: 0, blocks: 0, reports: 0, queries: 0, workflows: 0, subsystem: false };

  if (data.theme && typeof data.theme === 'object') {
    const name = data.theme.name || 'Imported theme';
    const themeData = JSON.stringify(data.theme.data ?? {});
    const created = await prisma.theme.create({
      data: { name, data: themeData, isDefault: false, isActive: false },
    });
    await prisma.$transaction([
      prisma.theme.updateMany({ where: { companyId: null }, data: { isActive: false } }),
      prisma.theme.update({ where: { id: created.id }, data: { isActive: true } }),
    ]);
    summary.theme = true;
  }

  if (Array.isArray(data.entities)) {
    let i = 0;
    for (const e of data.entities) {
      await registerCustomEntity({
        code: e.code,
        tableName: e.tableName ?? e.code,
        label: e.label,
        singular: e.singular ?? e.label,
        icon: e.icon ?? 'reports',
        category: e.category ?? 'custom',
        columns: e.columns ?? [],
        sortOrder: 300 + i * 10,
        isSystem: false,
      });
      summary.entities++;
      i++;
    }
  }

  if (data.businessType) {
    const setting = await prisma.setting.findFirst({ where: { companyId: null, key: 'system.business_type' } });
    if (setting) {
      await prisma.setting.update({ where: { id: setting.id }, data: { value: data.businessType } });
    } else {
      await prisma.setting.create({
        data: { companyId: null, key: 'system.business_type', value: data.businessType, type: 'string', isPublic: true },
      });
    }
  }

  if (Array.isArray(data.pages)) {
    for (const p of data.pages) {
      // Upsert by unique code; route may collide too, so we resolve carefully.
      let dbPage = await prisma.page.findFirst({ where: { OR: [{ code: p.code }, { route: p.route }] } });
      const payload = {
        code: p.code,
        title: p.title ?? p.code,
        route: p.route ?? `/p-${p.code}`,
        icon: p.icon ?? null,
        description: p.description ?? null,
        permissionCode: p.permissionCode ?? null,
        layout: p.layout ?? 'stack',
        background: p.background ?? null,
        isPublic: p.isPublic ?? false,
        isActive: p.isActive ?? true,
        showInSidebar: p.showInSidebar ?? true,
        sortOrder: p.sortOrder ?? 100,
        data: JSON.stringify(p.data ?? {}),
      };
      if (dbPage) {
        await prisma.page.update({ where: { id: dbPage.id }, data: payload });
        await prisma.pageBlock.deleteMany({ where: { pageId: dbPage.id } });
      } else {
        dbPage = await prisma.page.create({ data: payload });
      }

      // Two-pass block create: first without parent links, then wire them up.
      const localToDb = new Map();
      const blocks = Array.isArray(p.blocks) ? p.blocks : [];
      for (const b of blocks) {
        const created = await prisma.pageBlock.create({
          data: {
            pageId: dbPage.id,
            parentId: null,
            type: b.type,
            sortOrder: b.sortOrder ?? 0,
            isActive: b.isActive ?? true,
            config: JSON.stringify(b.config ?? {}),
          },
        });
        if (b.localId != null) localToDb.set(b.localId, created.id);
        summary.blocks++;
      }
      for (const b of blocks) {
        if (b.parentLocalId == null) continue;
        const childId = localToDb.get(b.localId);
        const parentId = localToDb.get(b.parentLocalId);
        if (childId && parentId) {
          await prisma.pageBlock.update({ where: { id: childId }, data: { parentId } });
        }
      }
      summary.pages++;
    }
  }

  if (Array.isArray(data.reports)) {
    for (const r of data.reports) {
      const existing = await prisma.report.findUnique({ where: { code: r.code } });
      const payload = {
        code: r.code,
        name: r.name ?? r.code,
        description: r.description ?? null,
        category: r.category ?? 'general',
        builder: r.builder,
        config: JSON.stringify(r.config ?? {}),
        isSystem: r.isSystem ?? false,
        isActive: r.isActive ?? true,
      };
      if (existing) {
        await prisma.report.update({ where: { code: r.code }, data: payload });
      } else {
        await prisma.report.create({ data: payload });
      }
      summary.reports++;
    }
  }

  if (Array.isArray(data.queries)) {
    for (const q of data.queries) {
      // saved_queries has no unique key beyond id; match by name to avoid duplicates on re-apply
      const existing = await prisma.savedQuery.findFirst({ where: { name: q.name } });
      const payload = {
        name: q.name,
        description: q.description ?? null,
        sql: q.sql,
        isReadOnly: q.isReadOnly ?? true,
      };
      if (existing) {
        await prisma.savedQuery.update({ where: { id: existing.id }, data: payload });
      } else {
        await prisma.savedQuery.create({ data: payload });
      }
      summary.queries++;
    }
  }

  // Phase 4.17 — workflow definitions are template-portable. We don't
  // import the run history (it's per-install state). Schedule
  // workflows have nextRunAt computed lazily by the cron loop on
  // first tick after import.
  if (Array.isArray(data.workflows)) {
    for (const w of data.workflows) {
      const payload = {
        code: w.code,
        name: w.name ?? w.code,
        description: w.description ?? null,
        triggerType: w.triggerType,
        triggerConfig: typeof w.triggerConfig === 'string' ? w.triggerConfig : JSON.stringify(w.triggerConfig ?? {}),
        actions: typeof w.actions === 'string' ? w.actions : JSON.stringify(w.actions ?? []),
        enabled: w.enabled !== false,
      };
      const existing = await prisma.workflow.findUnique({ where: { code: w.code } });
      if (existing) {
        await prisma.workflow.update({ where: { id: existing.id }, data: payload });
      } else {
        await prisma.workflow.create({ data: payload });
      }
      summary.workflows++;
    }
  }

  // Phase 4.12 — persist subsystem metadata if the template carries it.
  // The frontend reads this on every boot via `/api/subsystem/info` to
  // drive sidebar filtering + branding overrides.
  if (Array.isArray(data.modules) || (data.branding && typeof data.branding === 'object')) {
    await setSubsystemInfo({
      modules: Array.isArray(data.modules) ? data.modules : [],
      branding: data.branding && typeof data.branding === 'object' ? data.branding : null,
    });
    summary.subsystem = true;
  }

  return summary;
}
