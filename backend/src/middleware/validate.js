import { badRequest } from '../lib/http.js';

export function pick(obj, keys) {
  const out = {};
  for (const k of keys) {
    if (obj[k] !== undefined) out[k] = obj[k];
  }
  return out;
}

export function requireFields(body, fields) {
  const missing = fields.filter((f) => body[f] === undefined || body[f] === null || body[f] === '');
  if (missing.length) throw badRequest(`Missing required fields: ${missing.join(', ')}`);
}

export function parseId(value) {
  const id = Number(value);
  if (!Number.isInteger(id) || id <= 0) throw badRequest('Invalid id');
  return id;
}

export function parsePagination(query) {
  const page = Math.max(1, Number(query.page) || 1);
  const pageSize = Math.min(200, Math.max(1, Number(query.pageSize) || 25));
  return { page, pageSize, skip: (page - 1) * pageSize, take: pageSize };
}
