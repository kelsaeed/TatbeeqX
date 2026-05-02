import { describe, it, expect, beforeEach } from 'vitest';
import {
  registerApprovalHandler,
  unregisterApprovalHandler,
  runHandlers,
  listHandlers,
} from '../src/lib/approval_handlers.js';

beforeEach(() => {
  // Clear the registry between tests by removing every handler returned by listHandlers.
  // The lib doesn't expose a reset, so we rely on unregister.
  // Easiest: import internals once and recreate by removing what we add per-test.
});

describe('registerApprovalHandler / runHandlers', () => {
  it('runs a registered handler with the matching entity', async () => {
    const calls = [];
    async function handler({ decision, request }) {
      calls.push({ decision, id: request.id });
    }
    registerApprovalHandler('products-test-1', handler);
    try {
      const result = await runHandlers('approved', { id: 1, entity: 'products-test-1' });
      expect(result.ran).toBe(1);
      expect(result.errors).toEqual([]);
      expect(calls).toEqual([{ decision: 'approved', id: 1 }]);
    } finally {
      unregisterApprovalHandler('products-test-1', handler);
    }
  });

  it('does not run handlers for a different entity', async () => {
    let called = false;
    async function handler() { called = true; }
    registerApprovalHandler('products-test-2', handler);
    try {
      const result = await runHandlers('approved', { id: 1, entity: 'invoices-test' });
      expect(result.ran).toBe(0);
      expect(called).toBe(false);
    } finally {
      unregisterApprovalHandler('products-test-2', handler);
    }
  });

  it('captures handler errors without breaking the chain', async () => {
    let calledB = false;
    async function badHandler() { throw new Error('boom'); }
    async function goodHandler() { calledB = true; }
    registerApprovalHandler('e-test-3', badHandler, 'bad');
    registerApprovalHandler('e-test-3', goodHandler, 'good');
    try {
      const result = await runHandlers('approved', { id: 7, entity: 'e-test-3' });
      expect(result.ran).toBe(1);
      expect(result.errors).toHaveLength(1);
      expect(result.errors[0].name).toBe('bad');
      expect(result.errors[0].error).toContain('boom');
      expect(calledB).toBe(true);
    } finally {
      unregisterApprovalHandler('e-test-3', badHandler);
      unregisterApprovalHandler('e-test-3', goodHandler);
    }
  });

  it('listHandlers returns names per entity', () => {
    async function h() {}
    registerApprovalHandler('e-test-4', h, 'my-handler');
    try {
      const list = listHandlers();
      expect(list['e-test-4']).toContain('my-handler');
    } finally {
      unregisterApprovalHandler('e-test-4', h);
    }
  });

  it('rejects bad arguments', () => {
    expect(() => registerApprovalHandler('', () => {})).toThrow();
    expect(() => registerApprovalHandler('e', null)).toThrow();
  });
});
