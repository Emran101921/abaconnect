/** True when [startA, endA) and [startB, endB) share any time. */
export function intervalsOverlap(
  startA: Date,
  endA: Date,
  startB: Date,
  endB: Date,
): boolean {
  return startA < endB && startB < endA;
}

export const ACTIVE_APPOINTMENT_STATUSES = [
  'REQUESTED',
  'CONFIRMED',
  'SCHEDULED',
  'CHECKED_IN',
  'IN_PROGRESS',
  'COMPLETED',
  'RESCHEDULED',
] as const;
