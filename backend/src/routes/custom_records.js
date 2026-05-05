import { Router } from 'express';
import { prisma } from '../lib/prisma.js';
import { authenticate } from '../middleware/auth.js';
import { hasPermission } from '../lib/permissions.js';
import { asyncHandler, badRequest, forbidden, notFound } from '../lib/http.js';
import { parseId, parsePagination } from '../middleware/validate.js';
import { writeAudit } from '../lib/audit.js';
import {
  deleteRow, getRow, insertRow, listRows, updateRow,
  isRelationsCol, isFormulaCol,
} from '../lib/custom_entity_engine.js';

// Phase 4.16 follow-up — context for field-level permission filtering
// inside the engine. Routes pass this on every read/write so the
// engine can strip restricted columns from responses + ignore
// restricted fields in writes.
function permCtx(req) {
  return { permissions: req.permissions, isSuperAdmin: req.user.isSuperAdmin };
}

const router = Router({ mergeParams: true });
router.use(authenticate);

async function loadEntity(code) {
  const entity = await prisma.customEntity.findUnique({ where: { code } });
  if (!entity || !entity.isActive) throw notFound(`Custom entity "${code}" not found`);
  return entity;
}

function require(req, prefix, action) {
  if (!req.user.isSuperAdmin && !hasPermission(req.permissions, `${prefix}.${action}`)) {
    throw forbidden(`Permission denied: ${prefix}.${action}`);
  }
}

router.get(
  '/',
  asyncHandler(async (req, res) => {
    const entity = await loadEntity(req.params.code);
    require(req, entity.permissionPrefix, 'view');
    const { page, pageSize } = parsePagination(req.query);
    const search = (req.query.search || '').toString();
    const result = await listRows(entity, { page, pageSize, search }, permCtx(req));
    res.json({ ...result, page, pageSize });
  }),
);

// Phase 4.16 follow-up — CSV export per custom entity. Streams rows in
// 500-row pages so a 100k-row table doesn't blow up memory. Headers
// come from the entity's column config; relations columns serialize
// as semicolon-separated lists of target ids.
//
// Permission: <prefix>.export — already in the standard set (Phase 3).
function csvCell(v) {
  if (v === null || v === undefined) return '';
  const s = Array.isArray(v) ? v.join(';') : String(v);
  // RFC 4180: quote if it contains quote/comma/CR/LF; double internal quotes.
  if (/["\n\r,]/.test(s)) return `"${s.replace(/"/g, '""')}"`;
  return s;
}
function csvRow(values) {
  return values.map(csvCell).join(',') + '\r\n';
}

// Phase 4.16 follow-up — minimal RFC 4180 CSV parser. Returns an
// array of rows, each row an array of cell strings. Handles:
//   - Quoted cells ("...,...")
//   - Escaped quotes inside quoted cells (""")
//   - CRLF + LF + CR line endings
//   - Trailing partial row without a newline
// Rejects nothing — bad data flows through to per-row validation
// in the import handler so the operator sees per-row errors, not a
// single "your CSV is bad" 400.
export function parseCsv(text) {
  const rows = [];
  let row = [];
  let cell = '';
  let inQuotes = false;
  let i = 0;
  const n = text.length;
  while (i < n) {
    const ch = text[i];
    if (inQuotes) {
      if (ch === '"') {
        if (text[i + 1] === '"') { cell += '"'; i += 2; continue; }
        inQuotes = false; i++; continue;
      }
      cell += ch; i++;
    } else {
      if (ch === '"' && cell === '') { inQuotes = true; i++; continue; }
      if (ch === ',') { row.push(cell); cell = ''; i++; continue; }
      if (ch === '\r') { i++; continue; }
      if (ch === '\n') { row.push(cell); rows.push(row); row = []; cell = ''; i++; continue; }
      cell += ch; i++;
    }
  }
  if (cell !== '' || row.length > 0) {
    row.push(cell);
    rows.push(row);
  }
  return rows;
}

router.post(
  '/import',
  asyncHandler(async (req, res) => {
    const entity = await loadEntity(req.params.code);
    require(req, entity.permissionPrefix, 'create');
    const { csv, dryRun } = req.body || {};
    if (typeof csv !== 'string' || csv.trim().length === 0) {
      throw badRequest('csv field is required (string)');
    }

    const rows = parseCsv(csv);
    if (rows.length === 0) throw badRequest('CSV is empty');
    const headers = rows[0].map((h) => String(h ?? '').trim());
    const dataRows = rows.slice(1);

    const config = JSON.parse(entity.config);
    const colByName = new Map((config.columns || []).map((c) => [c.name, c]));

    const summary = { total: dataRows.length, created: 0, skipped: 0, errors: 0 };
    const errors = [];
    const MAX_ERRORS = 100;
    // Bucket every error by message so even a 10k-row import with one
    // recurring root cause surfaces every distinct failure type, not
    // just the first 100 occurrences. Each bucket stores up to 3
    // example line numbers — enough to spot-check without bloating
    // the response.
    const buckets = new Map();
    const BUCKET_EXAMPLES = 3;

    for (let r = 0; r < dataRows.length; r++) {
      const cells = dataRows[r];
      const lineNo = r + 2; // line 1 is the header
      try {
        const body = {};
        let hadAny = false;
        // Empty rows (e.g. trailing blank line) — skip silently.
        if (cells.every((v) => v === '' || v === undefined)) {
          summary.skipped++;
          continue;
        }
        for (let c = 0; c < headers.length; c++) {
          const colName = headers[c];
          const col = colByName.get(colName);
          if (!col) continue;            // unknown header — ignore
          if (col.name === 'id') continue; // never importable
          if (isFormulaCol(col)) continue; // virtual; can't write

          const v = cells[c];
          if (v === undefined) continue;
          if (isRelationsCol(col)) {
            if (v === '') continue;
            const ids = String(v).split(';')
              .map((s) => Number(s.trim()))
              .filter((nu) => Number.isFinite(nu) && nu > 0);
            body[colName] = ids;
            hadAny = true;
          } else {
            if (v === '') continue;
            body[colName] = v;
            hadAny = true;
          }
        }
        if (!hadAny) {
          summary.skipped++;
          continue;
        }
        if (dryRun !== true) {
          await insertRow(entity, body);
        }
        summary.created++;
      } catch (err) {
        summary.errors++;
        const msg = String(err?.message || err);
        if (errors.length < MAX_ERRORS) {
          errors.push({ line: lineNo, message: msg });
        } else if (errors.length === MAX_ERRORS) {
          errors.push({ line: -1, message: `Truncated — more than ${MAX_ERRORS} errors. See errorBuckets for the full distribution.` });
        }
        const bucket = buckets.get(msg) ?? { count: 0, exampleLines: [] };
        bucket.count++;
        if (bucket.exampleLines.length < BUCKET_EXAMPLES) bucket.exampleLines.push(lineNo);
        buckets.set(msg, bucket);
      }
    }

    const errorBuckets = Array.from(buckets.entries())
      .sort((a, b) => b[1].count - a[1].count)
      .map(([message, b]) => ({ message, count: b.count, exampleLines: b.exampleLines }));

    if (dryRun !== true) {
      await writeAudit({
        req, action: 'import', entity: entity.code,
        metadata: { ...summary, format: 'csv', distinctErrors: errorBuckets.length },
      });
    }
    res.json({ ok: summary.errors === 0, dryRun: dryRun === true, summary, errors, errorBuckets });
  }),
);

router.get(
  '/export.csv',
  asyncHandler(async (req, res) => {
    const entity = await loadEntity(req.params.code);
    require(req, entity.permissionPrefix, 'export');
    const config = JSON.parse(entity.config);
    const cols = (config.columns || []).filter((c) => c.name !== 'id');

    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader('Content-Disposition', `attachment; filename="${entity.code}.csv"`);

    const headerNames = ['id', ...cols.map((c) => c.name), 'created_at', 'updated_at'];
    res.write(csvRow(headerNames));

    const PAGE_SIZE = 500;
    let page = 1;
    let total = 0;
    // eslint-disable-next-line no-constant-condition
    while (true) {
      const { items } = await listRows(entity, { page, pageSize: PAGE_SIZE, search: '' });
      if (items.length === 0) break;
      for (const row of items) {
        res.write(csvRow(headerNames.map((h) => row[h])));
      }
      total += items.length;
      if (items.length < PAGE_SIZE) break;
      page += 1;
    }
    res.end();
    await writeAudit({ req, action: 'export', entity: entity.code, metadata: { rows: total, format: 'csv' } });
  }),
);

router.get(
  '/:id',
  asyncHandler(async (req, res) => {
    const entity = await loadEntity(req.params.code);
    require(req, entity.permissionPrefix, 'view');
    const row = await getRow(entity, parseId(req.params.id), permCtx(req));
    if (!row) throw notFound('Row not found');
    res.json(row);
  }),
);

router.post(
  '/',
  asyncHandler(async (req, res) => {
    const entity = await loadEntity(req.params.code);
    require(req, entity.permissionPrefix, 'create');
    const created = await insertRow(entity, req.body || {}, permCtx(req));
    await writeAudit({ req, action: 'create', entity: entity.code, entityId: created?.id });
    res.status(201).json(created);
  }),
);

router.put(
  '/:id',
  asyncHandler(async (req, res) => {
    const entity = await loadEntity(req.params.code);
    require(req, entity.permissionPrefix, 'edit');
    const id = parseId(req.params.id);
    const updated = await updateRow(entity, id, req.body || {}, permCtx(req));
    if (!updated) throw notFound('Row not found');
    await writeAudit({ req, action: 'update', entity: entity.code, entityId: id });
    res.json(updated);
  }),
);

// Phase 4.16 follow-up — bulk delete. Body: { ids: [int, ...] }.
// Order matters: this MUST come before DELETE /:id so Express doesn't
// route '/bulk' as id="bulk".
router.delete(
  '/bulk',
  asyncHandler(async (req, res) => {
    const entity = await loadEntity(req.params.code);
    require(req, entity.permissionPrefix, 'delete');
    const { ids } = req.body || {};
    if (!Array.isArray(ids)) throw badRequest('ids must be an array');
    const cleanIds = Array.from(new Set(
      ids.map(Number).filter((n) => Number.isFinite(n) && n > 0),
    ));
    if (cleanIds.length === 0) {
      return res.json({ deleted: 0, requested: 0, errors: [] });
    }
    // Cap to a sane batch size — bulk-deleting 100k+ rows in one
    // request would tie up the connection and run reverseCascade per
    // row. Operators with bigger needs can paginate the request.
    const MAX = 1000;
    const batch = cleanIds.slice(0, MAX);
    let deleted = 0;
    const errors = [];
    for (const id of batch) {
      try {
        await deleteRow(entity, id);
        deleted++;
      } catch (err) {
        errors.push({ id, message: String(err?.message || err) });
      }
    }
    await writeAudit({
      req, action: 'bulk_delete', entity: entity.code,
      metadata: { deleted, requested: cleanIds.length, errors: errors.length },
    });
    res.json({
      deleted,
      requested: cleanIds.length,
      truncated: cleanIds.length > MAX ? cleanIds.length - MAX : 0,
      errors,
    });
  }),
);

router.delete(
  '/:id',
  asyncHandler(async (req, res) => {
    const entity = await loadEntity(req.params.code);
    require(req, entity.permissionPrefix, 'delete');
    const id = parseId(req.params.id);
    await deleteRow(entity, id);
    await writeAudit({ req, action: 'delete', entity: entity.code, entityId: id });
    res.json({ ok: true });
  }),
);

export default router;
