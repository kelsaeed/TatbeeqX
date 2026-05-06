import { prisma } from './prisma.js';
import { compileFormula, evalFormula } from './formula.js';

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

// Phase 4.21 — formula columns. Operators add computed columns to a
// report's `config.formulaColumns` array; each one runs after the
// builder produces its rows. Reuses the safe formula evaluator from
// custom-entity columns (lib/formula.js): tokenize → parse → eval,
// no eval/Function/vm, null-propagating, cached AST.
//
// Schema:
//   { key, label, formula, numeric? }   // numeric defaults to true
//
// Validation:
// - key must not collide with a builder column.
// - formula must parse — parse errors throw with the bad formula
//   text so the operator can find it.
// - missing/non-numeric inputs evaluate to null (matches SQL).
export function applyFormulaColumns(result, formulaColumns) {
  if (!Array.isArray(formulaColumns) || formulaColumns.length === 0) {
    return result;
  }
  const existingKeys = new Set((result.columns || []).map((c) => c.key));
  const compiled = [];
  for (const f of formulaColumns) {
    if (!f || typeof f !== 'object') {
      throw new Error('formulaColumn entry must be an object');
    }
    const key = typeof f.key === 'string' ? f.key.trim() : '';
    const label = typeof f.label === 'string' ? f.label.trim() : '';
    const formula = typeof f.formula === 'string' ? f.formula.trim() : '';
    if (!key) throw new Error('formulaColumn.key is required');
    if (!label) throw new Error(`formulaColumn "${key}".label is required`);
    if (!formula) throw new Error(`formulaColumn "${key}".formula is required`);
    if (existingKeys.has(key)) {
      throw new Error(`formulaColumn "${key}" collides with an existing column`);
    }
    let ast;
    try {
      ast = compileFormula(formula);
    } catch (err) {
      throw new Error(`formulaColumn "${key}" parse error: ${err.message} (formula: ${formula})`);
    }
    existingKeys.add(key);
    compiled.push({
      key,
      label,
      numeric: f.numeric !== false,
      ast,
    });
  }
  const newColumns = [
    ...(result.columns || []),
    ...compiled.map((c) => ({ key: c.key, label: c.label, numeric: c.numeric })),
  ];
  const newRows = (result.rows || []).map((row) => {
    const out = { ...row };
    // Each formula sees the row PLUS any earlier formula results, so
    // operators can chain (e.g. `subtotal = qty*price`, then
    // `total = subtotal*1.1`). No cycle detection — formulas are
    // applied in declared order, references to later columns
    // resolve to undefined → null per formula.js semantics.
    for (const c of compiled) {
      out[c.key] = evalFormula(c.ast, out);
    }
    return out;
  });
  return { ...result, columns: newColumns, rows: newRows };
}

export async function runReport(builder, config) {
  const fn = builders[builder];
  if (!fn) throw new Error(`Unknown report builder: ${builder}`);
  const cfg = config || {};
  const raw = await fn(cfg);
  return applyFormulaColumns(raw, cfg.formulaColumns);
}

export async function runReportById(reportId) {
  const report = await prisma.report.findUnique({ where: { id: Number(reportId) } });
  if (!report) throw new Error(`Report not found: ${reportId}`);
  let cfg = {};
  try { cfg = JSON.parse(report.config || '{}'); } catch { cfg = {}; }
  return runReport(report.builder, cfg);
}
