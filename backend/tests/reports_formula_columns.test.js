// Phase 4.21 — formula columns on reports.
//
// Pure-function tests for `applyFormulaColumns` from lib/reports.js.
// No DB — the function takes a result `{columns, rows}` and a config
// array, returns the augmented result. The underlying evaluator
// (lib/formula.js) has its own test suite in formula.test.js.

import { describe, it, expect } from 'vitest';
import { applyFormulaColumns } from '../src/lib/reports.js';

const baseResult = () => ({
  columns: [
    { key: 'name', label: 'Name' },
    { key: 'users', label: 'Users', numeric: true },
    { key: 'branches', label: 'Branches', numeric: true },
  ],
  rows: [
    { name: 'Acme', users: 10, branches: 2 },
    { name: 'Beta', users: 6, branches: 3 },
  ],
});

describe('applyFormulaColumns — pass-through', () => {
  it('returns the result unchanged when formulaColumns is missing', () => {
    const r = baseResult();
    const out = applyFormulaColumns(r, undefined);
    expect(out).toEqual(r);
  });

  it('returns the result unchanged when formulaColumns is empty', () => {
    const r = baseResult();
    const out = applyFormulaColumns(r, []);
    expect(out).toEqual(r);
  });
});

describe('applyFormulaColumns — single formula', () => {
  it('appends a computed column to every row', () => {
    const out = applyFormulaColumns(baseResult(), [
      { key: 'ratio', label: 'Users/Branch', formula: 'users / branches' },
    ]);
    expect(out.columns).toHaveLength(4);
    expect(out.columns[3]).toEqual({ key: 'ratio', label: 'Users/Branch', numeric: true });
    expect(out.rows[0].ratio).toBe(5);
    expect(out.rows[1].ratio).toBe(2);
  });

  it('respects numeric: false', () => {
    const out = applyFormulaColumns(baseResult(), [
      { key: 'sum', label: 'Sum', formula: 'users + branches', numeric: false },
    ]);
    expect(out.columns[3].numeric).toBe(false);
  });

  it('numeric defaults to true when omitted', () => {
    const out = applyFormulaColumns(baseResult(), [
      { key: 'sum', label: 'Sum', formula: 'users + branches' },
    ]);
    expect(out.columns[3].numeric).toBe(true);
  });
});

describe('applyFormulaColumns — chaining', () => {
  it('a later formula can reference an earlier formula by key', () => {
    const out = applyFormulaColumns(baseResult(), [
      { key: 'subtotal', label: 'Subtotal', formula: 'users + branches' },
      { key: 'total', label: 'Total', formula: 'subtotal * 2' },
    ]);
    expect(out.rows[0].subtotal).toBe(12);
    expect(out.rows[0].total).toBe(24);
    expect(out.rows[1].subtotal).toBe(9);
    expect(out.rows[1].total).toBe(18);
  });
});

describe('applyFormulaColumns — null propagation', () => {
  it('returns null when a referenced field is null/undefined', () => {
    const r = {
      columns: [{ key: 'a', label: 'A' }],
      rows: [{ a: null }, { a: undefined }, { a: 5 }],
    };
    const out = applyFormulaColumns(r, [
      { key: 'doubled', label: 'Doubled', formula: 'a * 2' },
    ]);
    expect(out.rows[0].doubled).toBe(null);
    expect(out.rows[1].doubled).toBe(null);
    expect(out.rows[2].doubled).toBe(10);
  });

  it('returns null on divide-by-zero', () => {
    const r = {
      columns: [{ key: 'n' }, { key: 'd' }],
      rows: [{ n: 10, d: 0 }, { n: 10, d: 2 }],
    };
    const out = applyFormulaColumns(r, [
      { key: 'q', label: 'Q', formula: 'n / d' },
    ]);
    expect(out.rows[0].q).toBe(null);
    expect(out.rows[1].q).toBe(5);
  });
});

describe('applyFormulaColumns — validation', () => {
  it('rejects key collision with an existing builder column', () => {
    expect(() => applyFormulaColumns(baseResult(), [
      { key: 'users', label: 'oops', formula: '1 + 1' },
    ])).toThrow(/collides/);
  });

  it('rejects key collision between two formula columns', () => {
    expect(() => applyFormulaColumns(baseResult(), [
      { key: 'x', label: 'X1', formula: '1' },
      { key: 'x', label: 'X2', formula: '2' },
    ])).toThrow(/collides/);
  });

  it('rejects missing key', () => {
    expect(() => applyFormulaColumns(baseResult(), [
      { label: 'no key', formula: '1' },
    ])).toThrow(/key is required/);
  });

  it('rejects missing label', () => {
    expect(() => applyFormulaColumns(baseResult(), [
      { key: 'k', formula: '1' },
    ])).toThrow(/label is required/);
  });

  it('rejects missing formula', () => {
    expect(() => applyFormulaColumns(baseResult(), [
      { key: 'k', label: 'K' },
    ])).toThrow(/formula is required/);
  });

  it('parse errors surface the bad formula in the message', () => {
    expect(() => applyFormulaColumns(baseResult(), [
      { key: 'k', label: 'K', formula: 'users +' },
    ])).toThrow(/formula: users \+/);
  });

  it('does not silently mutate the input row objects', () => {
    const r = baseResult();
    const originalFirstRow = { ...r.rows[0] };
    applyFormulaColumns(r, [
      { key: 'sum', label: 'Sum', formula: 'users + branches' },
    ]);
    expect(r.rows[0]).toEqual(originalFirstRow);
  });
});
