import { describe, it, expect } from 'vitest';
import { inferProvider, getPrimaryProvider } from '../src/lib/db_pool.js';

describe('inferProvider', () => {
  it.each([
    ['file:./dev.db', 'sqlite'],
    ['file:/tmp/x.sqlite', 'sqlite'],
    ['/var/data.sqlite3', 'sqlite'],
    ['mydb.db', 'sqlite'],
    ['postgres://u:p@h:5432/db', 'postgresql'],
    ['postgresql://u:p@h:5432/db', 'postgresql'],
    ['mysql://u:p@h:3306/db', 'mysql'],
    ['mariadb://u:p@h/db', 'mysql'],
    ['sqlserver://h/db', 'sqlserver'],
    ['mongodb://u:p@h/db', 'mongodb'],
    ['mongodb+srv://h/db', 'mongodb'],
    ['totally-bogus', null],
    ['', null],
    [null, null],
    [undefined, null],
  ])('%s → %s', (url, expected) => {
    expect(inferProvider(url)).toBe(expected);
  });
});

describe('getPrimaryProvider', () => {
  it('returns "sqlite"', () => {
    expect(getPrimaryProvider()).toBe('sqlite');
  });
});
