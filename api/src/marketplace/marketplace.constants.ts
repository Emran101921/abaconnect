export const MARKETPLACE_CONSENT_VERSION = '1.0';

export const ANONYMOUS_MARKETPLACE_CONSENT_TEXT =
  'I agree to create an anonymous service request in the provider marketplace. My child\'s name, contact information, exact address, documents, and private health details will not be shared unless I approve a specific provider or agency.';

export const SHARE_IDENTIFIABLE_INFO_CONSENT_TEMPLATE =
  'I authorize this app to share my child\'s profile, contact information, service needs, and selected documents with {providerName} for evaluation, referral, care coordination, or service matching.';

export const SCREENING_DISCLAIMER_TEXT =
  'This screening is informational only. It is not a diagnosis, medical advice, or a replacement for evaluation by a licensed professional.';

export const PROVIDER_CONFIDENTIALITY_TERMS =
  'I agree to maintain confidentiality of all marketplace service request information, use data only for authorized care coordination, and not disclose identifiable child or family information without documented parent consent.';

export const FORBIDDEN_PUBLIC_FIELDS = [
  'firstName',
  'lastName',
  'dateOfBirth',
  'guardianName',
  'guardianPhone',
  'guardianEmail',
  'addressLine1',
  'addressLine2',
  'pediatricianName',
  'insuranceType',
  'insuranceMemberId',
  'diagnosisCodes',
  'notes',
  'parentName',
  'parentEmail',
  'parentPhone',
] as const;
