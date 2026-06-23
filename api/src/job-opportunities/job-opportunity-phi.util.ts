import {
  JOB_OPPORTUNITY_DISCLAIMER,
  PROHIBITED_PHRASE_PATTERNS,
  PROHIBITED_PHRASES,
} from './job-opportunity.constants';

export type PhiScanResult = {
  passed: boolean;
  flags: string[];
  blockedMessage?: string;
};

export function scanJobOpportunityPublicText(
  ...textParts: Array<string | null | undefined>
): PhiScanResult {
  const combined = textParts
    .filter((part) => part?.trim())
    .join(' ')
    .trim()
    .toLowerCase();

  if (!combined) {
    return { passed: true, flags: [] };
  }

  const flags = new Set<string>();

  for (const phrase of PROHIBITED_PHRASES) {
    if (combined.includes(phrase.toLowerCase())) {
      flags.add(`prohibited_phrase:${phrase}`);
    }
  }

  const original = textParts.filter(Boolean).join(' ');
  for (const pattern of PROHIBITED_PHRASE_PATTERNS) {
    if (pattern.test(original)) {
      flags.add(`prohibited_pattern:${pattern.source}`);
    }
  }

  if (flags.size > 0) {
    return {
      passed: false,
      flags: [...flags],
      blockedMessage:
        'Public posting blocked: description may contain PHI or prohibited referral language. Remove identifiable details before publishing.',
    };
  }

  return { passed: true, flags: [] };
}

export function jobOpportunityDisclaimerText(): string {
  return JOB_OPPORTUNITY_DISCLAIMER;
}

export function formatJobServiceTypeLabel(serviceType: string): string {
  switch (serviceType) {
    case 'ABA':
      return 'ABA';
    case 'OT':
      return 'Occupational Therapy (OT)';
    case 'PT':
      return 'Physical Therapy (PT)';
    case 'SPEECH':
      return 'Speech-Language Pathology';
    case 'SPECIAL_INSTRUCTION':
      return 'Special Instruction';
    case 'SOCIAL_WORK':
      return 'Social Work';
    case 'PSYCHOLOGY':
      return 'Psychology';
    case 'NURSING':
      return 'Nursing';
    case 'EVALUATION':
      return 'Evaluation';
    case 'SERVICE_COORDINATION':
      return 'Service Coordination';
    default:
      return 'Therapy';
  }
}

export function buildJobOpportunityTitle(
  serviceType: string,
  locationLabel?: string | null,
): string {
  const label = formatJobServiceTypeLabel(serviceType);
  const area = locationLabel?.trim() || 'Open Area';
  return `${label} Therapist Needed – ${area}`;
}

export function buildLocationAreaLabel(
  borough?: string | null,
  county?: string | null,
  zipCode?: string | null,
): string {
  if (borough?.trim()) return borough.trim();
  if (county?.trim()) return county.trim();
  const zip = zipCode?.replace(/\D/g, '').slice(0, 5);
  return zip ? `${zip} area` : 'Open Area';
}
