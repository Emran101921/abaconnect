export function isSelfPayInsuranceType(
  insuranceType: string | null | undefined,
): boolean {
  return !insuranceType || insuranceType === 'Self-pay';
}

export function computeSessionFeeCents(
  scheduledStart: Date,
  scheduledEnd: Date,
  hourlyRate: number,
): number {
  const durationMs = Math.max(
    30 * 60 * 1000,
    scheduledEnd.getTime() - scheduledStart.getTime(),
  );
  const hours = durationMs / 3_600_000;
  return Math.max(100, Math.round(hourlyRate * hours * 100));
}
