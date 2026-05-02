import { describe, it, expect } from 'vitest';
import { hasPermission } from '../src/lib/permissions.js';

describe('hasPermission', () => {
  it('returns true when the exact code is in the set', () => {
    const perms = new Set(['users.view', 'roles.edit']);
    expect(hasPermission(perms, 'users.view')).toBe(true);
    expect(hasPermission(perms, 'roles.edit')).toBe(true);
  });

  it('returns false when the code is missing', () => {
    const perms = new Set(['users.view']);
    expect(hasPermission(perms, 'users.create')).toBe(false);
  });

  it('returns true for any code when "*" is in the set (super admin)', () => {
    const perms = new Set(['*']);
    expect(hasPermission(perms, 'anything.you.can.imagine')).toBe(true);
    expect(hasPermission(perms, 'users.delete')).toBe(true);
  });

  it('handles an empty set', () => {
    const perms = new Set();
    expect(hasPermission(perms, 'users.view')).toBe(false);
  });
});
