import {
  AgencyRosterStatus,
  EiScreeningPriority,
  EiScreeningStatus,
  Prisma,
} from '../../generated/prisma/client';

/** Derive screening priority from questionnaire answers. */
export function deriveEiScreeningPriority(
  answers: Record<string, unknown>,
): EiScreeningPriority {
  const urgent =
    answers['urgentSafetyConcern'] === true ||
    answers['urgentSafetyConcern'] === 'yes' ||
    answers['familyCrisis'] === true ||
    answers['familyCrisis'] === 'yes' ||
    answers['childRegression'] === true ||
    answers['childRegression'] === 'yes' ||
    answers['severeParentConcern'] === true ||
    answers['severeParentConcern'] === 'yes' ||
    answers['noServicesStarted'] === true ||
    answers['noServicesStarted'] === 'yes';

  if (urgent) return 'HIGH';

  const medium =
    answers['providerIssues'] === true ||
    answers['providerIssues'] === 'yes' ||
    answers['missedSessions'] === true ||
    answers['missedSessions'] === 'yes' ||
    answers['followUpRequired'] === true ||
    answers['followUpRequired'] === 'yes' ||
    answers['moderateConcern'] === true ||
    answers['moderateConcern'] === 'yes';

  if (medium) return 'MEDIUM';
  return 'LOW';
}

export function screeningCompletionPercent(
  answers: Record<string, unknown>,
  requiredKeys: string[],
): number {
  if (requiredKeys.length === 0) return 100;
  const filled = requiredKeys.filter((k) => {
    const v = answers[k];
    if (typeof v === 'boolean') return v;
    return v !== undefined && v !== null && String(v).trim() !== '';
  }).length;
  return Math.round((filled / requiredKeys.length) * 100);
}

export const EI_INITIAL_REQUIRED_KEYS = [
  'childFirstName',
  'childDateOfBirth',
  'guardianName',
  'guardianPhone',
  'referralSource',
  'parentConcerns',
  'consentAcknowledged',
];

export const EI_ONGOING_REQUIRED_KEYS = [
  'servicesActive',
  'childProgress',
  'nextFollowUpDate',
];
