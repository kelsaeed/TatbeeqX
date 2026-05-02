import { describe, it, expect } from 'vitest';
import { isReadOnly, assertSafe } from '../src/lib/sql_runner.js';

describe('isReadOnly', () => {
  it.each([
    ['SELECT * FROM x', true],
    ['  select 1', true],
    ['WITH a AS (SELECT 1) SELECT * FROM a', true],
    ['PRAGMA table_info(x)', true],
    ['EXPLAIN SELECT 1', true],
    ['SHOW TABLES', true],
    ['INSERT INTO x VALUES (1)', false],
    ['UPDATE x SET y=1', false],
    ['DELETE FROM x', false],
    ['ALTER TABLE x ADD COLUMN z INT', false],
    ['DROP TABLE x', false],
  ])('%s → %s', (sql, expected) => {
    expect(isReadOnly(sql)).toBe(expected);
  });
});

describe('assertSafe — primary connection', () => {
  it('rejects empty SQL', () => {
    expect(() => assertSafe('', { allowWrite: true })).toThrow(/Empty SQL/);
  });

  it('rejects oversized SQL', () => {
    const huge = 'SELECT 1; ' + 'x'.repeat(11_000);
    expect(() => assertSafe(huge, { allowWrite: true })).toThrow(/too long/);
  });

  it('blocks UPDATE on auth tables even with allowWrite', () => {
    expect(() => assertSafe('UPDATE users SET passwordHash="x"', { allowWrite: true }))
      .toThrow(/auth tables/);
  });

  it('blocks DELETE FROM auth tables', () => {
    expect(() => assertSafe('DELETE FROM permissions', { allowWrite: true }))
      .toThrow(/auth tables/);
  });

  it('blocks DROP TABLE on auth tables', () => {
    expect(() => assertSafe('DROP TABLE roles', { allowWrite: true }))
      .toThrow(/auth tables/);
  });

  it('blocks writes when allowWrite=false', () => {
    expect(() => assertSafe('INSERT INTO products VALUES (1)', { allowWrite: false }))
      .toThrow(/Read-only mode/);
  });

  it('allows SELECTs in read-only mode', () => {
    expect(() => assertSafe('SELECT 1', { allowWrite: false })).not.toThrow();
  });

  it('allows writes on non-auth tables when allowWrite=true', () => {
    expect(() => assertSafe('INSERT INTO products VALUES (1)', { allowWrite: true })).not.toThrow();
  });
});

describe('assertSafe — secondary connection', () => {
  it('does NOT block auth-table names on secondaries (those are not our auth tables)', () => {
    expect(() => assertSafe('UPDATE users SET name = $1', { allowWrite: true, secondary: true }))
      .not.toThrow();
  });

  it('still enforces read-only mode on secondaries', () => {
    expect(() => assertSafe('UPDATE users SET name = $1', { allowWrite: false, secondary: true }))
      .toThrow(/Read-only mode/);
  });
});
