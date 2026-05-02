import { describe, it, expect } from 'vitest';
import { computeNext } from '../src/lib/cron.js';

describe('computeNext', () => {
  const ref = new Date('2026-04-30T10:00:00.000Z');

  it('every_minute → +60s', () => {
    const next = computeNext({ frequency: 'every_minute' }, ref);
    expect(next.getTime() - ref.getTime()).toBe(60_000);
  });

  it('every_5_minutes → +5min', () => {
    const next = computeNext({ frequency: 'every_5_minutes' }, ref);
    expect(next.getTime() - ref.getTime()).toBe(5 * 60_000);
  });

  it('hourly → next top of the hour', () => {
    const next = computeNext({ frequency: 'hourly' }, ref);
    expect(next.getMinutes()).toBe(0);
    expect(next.getSeconds()).toBe(0);
    expect(next > ref).toBe(true);
  });

  it('daily at fixed time → today if future, tomorrow if past', () => {
    const at9 = new Date('2026-04-30T09:00:00.000');
    const future = computeNext({ frequency: 'daily', timeOfDay: '23:59' }, at9);
    expect(future.getHours()).toBe(23);
    expect(future.getMinutes()).toBe(59);
    // same calendar day
    expect(future.getDate()).toBe(at9.getDate());

    const past = computeNext({ frequency: 'daily', timeOfDay: '08:00' }, at9);
    // exactly one calendar day later (handles month rollover automatically)
    const expected = new Date(at9.getTime());
    expected.setDate(expected.getDate() + 1);
    expect(past.getDate()).toBe(expected.getDate());
    expect(past.getMonth()).toBe(expected.getMonth());
    expect(past.getHours()).toBe(8);
  });

  it('weekly steps to the requested day-of-week', () => {
    // Wed 2026-04-29 noon. Ask for Friday (5) → +2 days
    const wed = new Date(2026, 3, 29, 12, 0, 0);
    const next = computeNext({ frequency: 'weekly', timeOfDay: '08:00', dayOfWeek: 5 }, wed);
    expect(next.getDay()).toBe(5);
    expect(next > wed).toBe(true);
  });

  it('monthly clamps day-of-month and rolls over', () => {
    const mid = new Date(2026, 3, 15, 12, 0, 0); // Apr 15
    const next = computeNext({ frequency: 'monthly', timeOfDay: '01:00', dayOfMonth: 1 }, mid);
    expect(next.getMonth()).toBe(4); // May
    expect(next.getDate()).toBe(1);
  });

  it('cron parses 5 fields and respects */N step', () => {
    const start = new Date(2026, 3, 30, 10, 7, 0);
    const next = computeNext({ frequency: 'cron', cron: '*/15 * * * *' }, start);
    expect([15, 30, 45, 0]).toContain(next.getMinutes());
    expect(next > start).toBe(true);
  });

  it('cron handles weekday range', () => {
    // Sunday should skip to Monday for "0 9 * * 1-5"
    const sunday = new Date(2026, 4, 3, 10, 0, 0); // 2026-05-03 = Sunday
    const next = computeNext({ frequency: 'cron', cron: '0 9 * * 1-5' }, sunday);
    expect(next.getDay()).toBe(1); // Monday
    expect(next.getHours()).toBe(9);
    expect(next.getMinutes()).toBe(0);
  });

  it('unknown frequency falls back to +1h', () => {
    const next = computeNext({ frequency: 'mystery' }, ref);
    expect(next.getTime() - ref.getTime()).toBe(60 * 60_000);
  });
});
