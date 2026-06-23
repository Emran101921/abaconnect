export const EI_MAX_AGE_MONTHS = 36;

export type EiScreeningEligibilityInput = {
  dateOfBirth: Date;
  screening?: {
    isDraft: boolean;
    riskLevel: string | null;
    evaluationRequestedAt: Date | null;
    template?: { therapyType: string; name: string } | null;
  } | null;
};

export function childAgeInMonths(dateOfBirth: Date, asOf = new Date()): number {
  let months =
    (asOf.getFullYear() - dateOfBirth.getFullYear()) * 12 +
    (asOf.getMonth() - dateOfBirth.getMonth());
  if (asOf.getDate() < dateOfBirth.getDate()) {
    months -= 1;
  }
  return Math.max(0, months);
}

export function isEiServiceEligible(input: EiScreeningEligibilityInput): {
  eligible: boolean;
  reason: string;
} {
  const ageMonths = childAgeInMonths(input.dateOfBirth);
  if (ageMonths > EI_MAX_AGE_MONTHS) {
    return {
      eligible: false,
      reason: 'Child is outside EI age range (birth–36 months)',
    };
  }

  const screening = input.screening;
  if (!screening || screening.isDraft) {
    return {
      eligible: false,
      reason: 'Complete Early Intervention parent screening first',
    };
  }

  const isEiTemplate =
    screening.template?.therapyType === 'EARLY_INTERVENTION' ||
    screening.template?.name.toLowerCase().includes('early intervention');

  if (!isEiTemplate) {
    return {
      eligible: false,
      reason: 'No completed Early Intervention screening on file',
    };
  }

  if (screening.evaluationRequestedAt) {
    return { eligible: true, reason: 'EI evaluation requested by parent' };
  }

  const risk = screening.riskLevel?.toUpperCase();
  if (risk === 'MODERATE' || risk === 'HIGH') {
    return { eligible: true, reason: `EI screening risk level: ${risk}` };
  }

  return {
    eligible: false,
    reason: 'EI screening shows low risk — evaluation not requested',
  };
}
