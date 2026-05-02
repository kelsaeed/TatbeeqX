// Phase 4.16 follow-up — formula evaluator (lib/formula.js).
//
// Pure JS tests; no DB. Covers the parser + evaluator + null
// propagation + safety (no JS injection).

import { describe, it, expect } from 'vitest';
import { compileFormula, evalFormula, evaluate, referencedFields } from '../src/lib/formula.js';

describe('formula evaluator — basics', () => {
  it('numeric literal', () => {
    expect(evaluate('42', {})).toBe(42);
    expect(evaluate('3.14', {})).toBe(3.14);
  });

  it('field reference', () => {
    expect(evaluate('qty', { qty: 7 })).toBe(7);
  });

  it('addition / subtraction / multiplication / division', () => {
    expect(evaluate('1 + 2', {})).toBe(3);
    expect(evaluate('10 - 4', {})).toBe(6);
    expect(evaluate('3 * 5', {})).toBe(15);
    expect(evaluate('20 / 4', {})).toBe(5);
  });

  it('parentheses + precedence', () => {
    expect(evaluate('1 + 2 * 3', {})).toBe(7);
    expect(evaluate('(1 + 2) * 3', {})).toBe(9);
    expect(evaluate('2 * (3 + 4) - 1', {})).toBe(13);
  });

  it('mixed fields and literals', () => {
    expect(evaluate('qty * price', { qty: 3, price: 9.99 })).toBeCloseTo(29.97);
    expect(evaluate('(subtotal + tax) * 1.1', { subtotal: 100, tax: 10 })).toBeCloseTo(121);
  });

  it('unary minus / unary plus', () => {
    expect(evaluate('-5', {})).toBe(-5);
    expect(evaluate('+5', {})).toBe(5);
    expect(evaluate('-x + 1', { x: 3 })).toBe(-2);
    expect(evaluate('--5', {})).toBe(5);
  });
});

describe('formula evaluator — null propagation', () => {
  it('returns null when a referenced field is null', () => {
    expect(evaluate('qty * price', { qty: 3, price: null })).toBeNull();
    expect(evaluate('a + b', { a: null, b: 1 })).toBeNull();
  });

  it('returns null when a referenced field is undefined / empty string', () => {
    expect(evaluate('qty * price', { qty: 3 })).toBeNull(); // price undefined
    expect(evaluate('qty + 1', { qty: '' })).toBeNull();
  });

  it('coerces numeric strings (Prisma sometimes returns these)', () => {
    expect(evaluate('qty + 1', { qty: '5' })).toBe(6);
  });

  it('returns null for non-numeric string fields', () => {
    expect(evaluate('qty + 1', { qty: 'abc' })).toBeNull();
  });

  it('divide-by-zero returns null (not Infinity)', () => {
    expect(evaluate('5 / 0', {})).toBeNull();
    expect(evaluate('a / b', { a: 10, b: 0 })).toBeNull();
  });
});

describe('formula evaluator — safety', () => {
  it('rejects empty / whitespace-only formulas', () => {
    expect(() => compileFormula('')).toThrow(/non-empty/);
    expect(() => compileFormula('   ')).toThrow(/non-empty/);
  });

  it('rejects unknown operators', () => {
    expect(() => compileFormula('5 % 3')).toThrow(/Unexpected/);
    expect(() => compileFormula('5 ** 2')).toThrow();
  });

  it('rejects function calls (no JS escape via name())', () => {
    expect(() => compileFormula('alert(1)')).toThrow(/Unexpected/);
    expect(() => compileFormula('process.exit()')).toThrow(/Unexpected/);
  });

  it('rejects string literals', () => {
    expect(() => compileFormula('"hi"')).toThrow(/Unexpected/);
    expect(() => compileFormula("'evil'")).toThrow(/Unexpected/);
  });

  it('rejects unbalanced parens', () => {
    expect(() => compileFormula('(1 + 2')).toThrow();
    expect(() => compileFormula('1 + 2)')).toThrow();
  });

  it('rejects trailing tokens', () => {
    expect(() => compileFormula('1 + 2 3')).toThrow();
  });
});

describe('formula evaluator — utilities', () => {
  it('referencedFields lists every IDENT in the AST', () => {
    const ast = compileFormula('(qty * price) + tax - discount');
    expect(referencedFields(ast).sort()).toEqual(['discount', 'price', 'qty', 'tax']);
  });

  it('referencedFields dedups repeated references', () => {
    const ast = compileFormula('a + a + b');
    expect(referencedFields(ast).sort()).toEqual(['a', 'b']);
  });

  it('compileFormula caches AST per source string (same ref returned)', () => {
    const a = compileFormula('qty * price');
    const b = compileFormula('qty * price');
    expect(a).toBe(b); // same object reference — cache hit
  });

  it('evalFormula accepts a pre-compiled AST', () => {
    const ast = compileFormula('qty * price');
    expect(evalFormula(ast, { qty: 4, price: 2.5 })).toBe(10);
  });
});
