import { prisma } from './prisma.js';

const builders = {
  'users.by_role': async () => {
    const roles = await prisma.role.findMany({
      include: { _count: { select: { userRoles: true } } },
      orderBy: { name: 'asc' },
    });
    return {
      columns: [
        { key: 'name', label: 'Role' },
        { key: 'code', label: 'Code' },
        { key: 'users', label: 'Users', numeric: true },
      ],
      rows: roles.map((r) => ({ name: r.name, code: r.code, users: r._count.userRoles })),
    };
  },

  'users.active_status': async () => {
    const [active, inactive] = await Promise.all([
      prisma.user.count({ where: { isActive: true } }),
      prisma.user.count({ where: { isActive: false } }),
    ]);
    return {
      columns: [
        { key: 'status', label: 'Status' },
        { key: 'count', label: 'Count', numeric: true },
      ],
      rows: [
        { status: 'Active', count: active },
        { status: 'Inactive', count: inactive },
      ],
    };
  },

  'companies.summary': async () => {
    const companies = await prisma.company.findMany({
      include: { _count: { select: { branches: true, users: true } } },
      orderBy: { name: 'asc' },
    });
    return {
      columns: [
        { key: 'code', label: 'Code' },
        { key: 'name', label: 'Name' },
        { key: 'branches', label: 'Branches', numeric: true },
        { key: 'users', label: 'Users', numeric: true },
        { key: 'isActive', label: 'Active' },
      ],
      rows: companies.map((c) => ({
        code: c.code,
        name: c.name,
        branches: c._count.branches,
        users: c._count.users,
        isActive: c.isActive ? 'Yes' : 'No',
      })),
    };
  },

  'audit.actions_summary': async (config = {}) => {
    const days = Math.min(180, Math.max(1, Number(config.days) || 30));
    const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000);
    const grouped = await prisma.auditLog.groupBy({
      by: ['action'],
      where: { createdAt: { gte: since } },
      _count: { action: true },
      orderBy: { _count: { action: 'desc' } },
    });
    return {
      columns: [
        { key: 'action', label: 'Action' },
        { key: 'count', label: 'Count', numeric: true },
      ],
      rows: grouped.map((g) => ({ action: g.action, count: g._count.action })),
    };
  },

  'audit.entities_summary': async (config = {}) => {
    const days = Math.min(180, Math.max(1, Number(config.days) || 30));
    const since = new Date(Date.now() - days * 24 * 60 * 60 * 1000);
    const grouped = await prisma.auditLog.groupBy({
      by: ['entity'],
      where: { createdAt: { gte: since } },
      _count: { entity: true },
      orderBy: { _count: { entity: 'desc' } },
    });
    return {
      columns: [
        { key: 'entity', label: 'Entity' },
        { key: 'count', label: 'Count', numeric: true },
      ],
      rows: grouped.map((g) => ({ entity: g.entity, count: g._count.entity })),
    };
  },
};

export function listBuilders() {
  return Object.keys(builders);
}

export async function runReport(builder, config) {
  const fn = builders[builder];
  if (!fn) throw new Error(`Unknown report builder: ${builder}`);
  return fn(config || {});
}

export async function runReportById(reportId) {
  const report = await prisma.report.findUnique({ where: { id: Number(reportId) } });
  if (!report) throw new Error(`Report not found: ${reportId}`);
  let cfg = {};
  try { cfg = JSON.parse(report.config || '{}'); } catch { cfg = {}; }
  return runReport(report.builder, cfg);
}
