import { describe, it, expect } from 'vitest';
import { hasPermission, approvableEntities } from '../src/lib/permissions.js';

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

describe('approvableEntities — Phase 4.22 approval queue filter', () => {
  it('extracts entity prefixes from <entity>.approve codes', () => {
    const perms = new Set(['companies.approve', 'users.approve', 'companies.view']);
    expect(approvableEntities(perms)).toEqual(new Set(['companies', 'users']));
  });

  it('returns an empty set when no .approve codes are present', () => {
    const perms = new Set(['users.view', 'companies.edit']);
    expect(approvableEntities(perms)).toEqual(new Set());
  });

  it('returns null for super-admin (no entity filter)', () => {
    const perms = new Set(['*']);
    expect(approvableEntities(perms)).toBe(null);
  });

  it('handles dotted entity names (custom entities are valid)', () => {
    // Custom entities follow `c.<code>` naming; the .approve code is
    // `c.<code>.approve`. The regex should peel off the trailing
    // `.approve` and keep the rest as the entity.
    const perms = new Set(['c.products.approve']);
    expect(approvableEntities(perms)).toEqual(new Set(['c.products']));
  });

  it('ignores codes that merely start with .approve substring', () => {
    // `something.approve_all` would NOT match — the regex anchors to
    // end-of-string. Catches the obvious false-positive case.
    const perms = new Set(['users.approve_all']);
    expect(approvableEntities(perms)).toEqual(new Set());
  });

  it('returns an empty set when given a falsy / weird input', () => {
    expect(approvableEntities(null)).toEqual(new Set());
    expect(approvableEntities(undefined)).toEqual(new Set());
    expect(approvableEntities({})).toEqual(new Set());
  });
});
