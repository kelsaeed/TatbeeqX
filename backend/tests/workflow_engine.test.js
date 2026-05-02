// Phase 4.17 — workflow engine unit tests.
//
// Pure-function tests for the bits that don't need a DB: templating,
// path resolution, condition DSL.

import { describe, it, expect } from 'vitest';
import {
  resolvePath, renderTemplate, renderValue, evalCondition,
} from '../src/lib/workflow_engine.js';

describe('resolvePath', () => {
  const ctx = { trigger: { row: { id: 17, name: 'Lead', amount: 250 } } };

  it('walks dotted paths', () => {
    expect(resolvePath(ctx, 'trigger.row.id')).toBe(17);
    expect(resolvePath(ctx, 'trigger.row.name')).toBe('Lead');
  });

  it('returns undefined for missing segments', () => {
    expect(resolvePath(ctx, 'trigger.nope')).toBeUndefined();
    expect(resolvePath(ctx, 'trigger.row.id.x')).toBeUndefined();
  });

  it('handles empty / non-string paths', () => {
    expect(resolvePath(ctx, '')).toBeUndefined();
    expect(resolvePath(ctx, null)).toBeUndefined();
  });
});

describe('renderTemplate', () => {
  const ctx = { trigger: { row: { id: 17, name: 'Lead', meta: { tier: 'gold' } } } };

  it('whole-string template preserves type', () => {
    expect(renderTemplate('{{trigger.row.id}}', ctx)).toBe(17);
    expect(renderTemplate('{{trigger.row.meta}}', ctx)).toEqual({ tier: 'gold' });
  });

  it('mid-string substitution stringifies', () => {
    expect(renderTemplate('lead-{{trigger.row.id}}', ctx)).toBe('lead-17');
    expect(renderTemplate('hi {{trigger.row.name}}!', ctx)).toBe('hi Lead!');
  });

  it('missing path renders empty', () => {
    expect(renderTemplate('x={{trigger.row.nope}}', ctx)).toBe('x=');
  });

  it('renderValue walks objects + arrays', () => {
    const out = renderValue(
      { url: 'https://x/api/{{trigger.row.id}}', headers: ['{{trigger.row.name}}'] },
      ctx,
    );
    expect(out.url).toBe('https://x/api/17');
    expect(out.headers).toEqual(['Lead']);
  });

  it('non-string scalars pass through', () => {
    expect(renderTemplate(42, ctx)).toBe(42);
    expect(renderValue(true, ctx)).toBe(true);
  });
});

describe('evalCondition', () => {
  const ctx = { trigger: { row: { status: 'pending', amount: 250, tags: ['urgent', 'vip'] } } };

  it('null/empty condition is true', () => {
    expect(evalCondition(null, ctx)).toBe(true);
    expect(evalCondition({}, ctx)).toBe(true);
  });

  it('equals + notEquals', () => {
    expect(evalCondition({ field: 'trigger.row.status', equals: 'pending' }, ctx)).toBe(true);
    expect(evalCondition({ field: 'trigger.row.status', equals: 'done' }, ctx)).toBe(false);
    expect(evalCondition({ field: 'trigger.row.status', notEquals: 'done' }, ctx)).toBe(true);
  });

  it('numeric comparisons', () => {
    expect(evalCondition({ field: 'trigger.row.amount', gt: 100 }, ctx)).toBe(true);
    expect(evalCondition({ field: 'trigger.row.amount', gte: 250 }, ctx)).toBe(true);
    expect(evalCondition({ field: 'trigger.row.amount', lt: 100 }, ctx)).toBe(false);
    expect(evalCondition({ field: 'trigger.row.amount', lte: 250 }, ctx)).toBe(true);
  });

  it('in / contains', () => {
    expect(evalCondition({ field: 'trigger.row.status', in: ['pending', 'review'] }, ctx)).toBe(true);
    expect(evalCondition({ field: 'trigger.row.status', in: ['done'] }, ctx)).toBe(false);
    expect(evalCondition({ field: 'trigger.row.tags', contains: 'vip' }, ctx)).toBe(true);
  });

  it('isNull / isNotNull', () => {
    expect(evalCondition({ field: 'trigger.row.missing', isNull: true }, ctx)).toBe(true);
    expect(evalCondition({ field: 'trigger.row.status', isNotNull: true }, ctx)).toBe(true);
  });

  it('matches uses regex', () => {
    expect(evalCondition({ field: 'trigger.row.status', matches: '^pen' }, ctx)).toBe(true);
    expect(evalCondition({ field: 'trigger.row.status', matches: '^done' }, ctx)).toBe(false);
    // Bad regex treated as no match, not a throw.
    expect(evalCondition({ field: 'trigger.row.status', matches: '(' }, ctx)).toBe(false);
  });

  it('all / any / not compose', () => {
    expect(evalCondition({
      all: [
        { field: 'trigger.row.status', equals: 'pending' },
        { field: 'trigger.row.amount', gt: 100 },
      ],
    }, ctx)).toBe(true);

    expect(evalCondition({
      any: [
        { field: 'trigger.row.status', equals: 'done' },
        { field: 'trigger.row.amount', gt: 100 },
      ],
    }, ctx)).toBe(true);

    expect(evalCondition({
      not: { field: 'trigger.row.status', equals: 'done' },
    }, ctx)).toBe(true);
  });

  it('malformed condition fails closed', () => {
    expect(evalCondition({ field: 42 }, ctx)).toBe(false);  // field not a string
    expect(evalCondition({ field: 'trigger.row.status' }, ctx)).toBe(false); // no operator
  });
});
