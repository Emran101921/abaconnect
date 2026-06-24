type ChildPrefillSource = {
  firstName: string;
  lastName: string;
  dateOfBirth: Date;
  gender?: string | null;
  primaryLanguage?: string | null;
  guardianName?: string | null;
  guardianPhone?: string | null;
  guardianEmail?: string | null;
  insuranceType?: string | null;
};

type ParentUserPrefillSource = {
  firstName: string;
  lastName: string;
  email: string;
  phone?: string | null;
};

type ParentScreeningPrefillSource = {
  concernTags?: unknown;
  evaluationRequestedAt?: Date | null;
};

export function buildEiScreeningPrefill(
  child: ChildPrefillSource,
  parentUser: ParentUserPrefillSource,
  parentScreening?: ParentScreeningPrefillSource | null,
): Record<string, unknown> {
  const dob = child.dateOfBirth.toISOString().split('T')[0];
  const prefill: Record<string, unknown> = {
    childFirstName: child.firstName,
    childLastName: child.lastName,
    childDateOfBirth: dob,
    childGender: child.gender ?? '',
    childPrimaryLanguage: child.primaryLanguage ?? '',
    guardianName:
      child.guardianName?.trim() ||
      `${parentUser.firstName} ${parentUser.lastName}`.trim(),
    guardianPhone: child.guardianPhone ?? parentUser.phone ?? '',
    guardianEmail: child.guardianEmail ?? parentUser.email ?? '',
  };

  if (child.insuranceType) {
    prefill.insuranceType = child.insuranceType;
    prefill.medicaidEnrolled = child.insuranceType
      .toLowerCase()
      .includes('medicaid');
  }

  if (parentScreening?.concernTags) {
    const tags = Array.isArray(parentScreening.concernTags)
      ? parentScreening.concernTags
      : [];
    if (tags.length > 0) {
      prefill.parentConcerns = tags.map(String).join(', ');
    }
  }

  if (parentScreening?.evaluationRequestedAt) {
    prefill.referralSource = 'Parent EI screening';
    prefill.referralType = 'Parent self-referral';
  }

  return prefill;
}

/** Saved coordinator answers override system prefill for non-empty values. */
export function mergePrefillIntoAnswers(
  prefill: Record<string, unknown>,
  answers: Record<string, unknown>,
): Record<string, unknown> {
  const merged = { ...prefill };
  for (const [key, value] of Object.entries(answers)) {
    if (value === undefined || value === null) continue;
    if (typeof value === 'boolean') {
      if (value) merged[key] = value;
      continue;
    }
    if (String(value).trim() !== '') {
      merged[key] = value;
    }
  }
  return merged;
}
