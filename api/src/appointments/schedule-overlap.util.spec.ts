import {
  ACTIVE_APPOINTMENT_STATUSES,
  intervalsOverlap,
} from './schedule-overlap.util';

describe('intervalsOverlap', () => {
  const t0 = new Date('2026-06-20T10:00:00.000Z');
  const t1 = new Date('2026-06-20T11:00:00.000Z');
  const t2 = new Date('2026-06-20T11:30:00.000Z');

  it('detects partial overlap', () => {
    expect(intervalsOverlap(t0, t2, t1, t2)).toBe(true);
  });

  it('detects contained interval', () => {
    expect(intervalsOverlap(t0, t2, t0, t1)).toBe(true);
  });

  it('returns false for adjacent non-overlapping slots', () => {
    expect(intervalsOverlap(t0, t1, t1, t2)).toBe(false);
  });

  it('returns false for disjoint slots', () => {
    expect(intervalsOverlap(t0, t1, t2, t2)).toBe(false);
  });
});

describe('ACTIVE_APPOINTMENT_STATUSES', () => {
  it('excludes cancelled and no-show', () => {
    expect(ACTIVE_APPOINTMENT_STATUSES).not.toContain('CANCELLED');
    expect(ACTIVE_APPOINTMENT_STATUSES).not.toContain('NO_SHOW');
  });
});
