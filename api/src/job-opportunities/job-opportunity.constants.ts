export const JOB_OPPORTUNITY_DISCLAIMER =
  'This posting describes a staffing opportunity only. It does not include identifiable child or family information. Do not share PHI in applications or messages until the agency completes credentialing and onboarding.';

export const JOB_OPPORTUNITY_PUBLISH_CONSENT =
  'I confirm this public description contains no child names, diagnoses, referral details, addresses, or other protected health information.';

/** Phrases and patterns that must never appear in public job postings. */
export const PROHIBITED_PHRASES = [
  'child named',
  'patient named',
  'referral for',
  'referred by',
  'medicaid id',
  'insurance id',
  'member id',
  'date of birth',
  'dob:',
  'diagnosis',
  'diagnosed with',
  'autism',
  'asd',
  'ifsp',
  'iep',
  'ssn',
  'social security',
  'guardian name',
  'parent name',
  'home address',
  'street address',
  'medical record',
  'mrn',
] as const;

export const PROHIBITED_PHRASE_PATTERNS: RegExp[] = [
  /\b\d{3}-\d{2}-\d{4}\b/,
  /\b\d{9}\b/,
  /\b(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s+\d{1,2},?\s+\d{4}\b/i,
  /\b\d{1,2}\/\d{1,2}\/\d{2,4}\b/,
  /\b(?:mr|mrs|ms|dr)\.?\s+[A-Z][a-z]+\s+[A-Z][a-z]+\b/,
];

export const JOB_MARKETPLACE_EVENT_TYPES = {
  CHILD_SERVICE_NEED_CREATED: 'CHILD_SERVICE_NEED_CREATED',
  JOB_OPPORTUNITY_GENERATED: 'JOB_OPPORTUNITY_GENERATED',
  JOB_OPPORTUNITY_DRAFT_UPDATED: 'JOB_OPPORTUNITY_DRAFT_UPDATED',
  JOB_OPPORTUNITY_PUBLISHED: 'JOB_OPPORTUNITY_PUBLISHED',
  JOB_OPPORTUNITY_PUBLISH_BLOCKED: 'JOB_OPPORTUNITY_PUBLISH_BLOCKED',
  JOB_OPPORTUNITY_PAUSED: 'JOB_OPPORTUNITY_PAUSED',
  JOB_OPPORTUNITY_REMOVED: 'JOB_OPPORTUNITY_REMOVED',
  JOB_APPLICATION_SUBMITTED: 'JOB_APPLICATION_SUBMITTED',
  JOB_APPLICATION_WITHDRAWN: 'JOB_APPLICATION_WITHDRAWN',
  JOB_APPLICATION_STATUS_CHANGED: 'JOB_APPLICATION_STATUS_CHANGED',
  JOB_APPLICATION_CREDENTIALS_UPDATED: 'JOB_APPLICATION_CREDENTIALS_UPDATED',
  JOB_OFFER_ACCEPTED: 'JOB_OFFER_ACCEPTED',
  JOB_OFFER_DECLINED: 'JOB_OFFER_DECLINED',
  JOB_OFFER_SENT: 'JOB_OFFER_SENT',
  THERAPIST_HIRED_CONTRACTED: 'THERAPIST_HIRED_CONTRACTED',
  THERAPIST_ADDED_TO_ROSTER: 'THERAPIST_ADDED_TO_ROSTER',
  ADMIN_MODERATION_FLAG: 'ADMIN_MODERATION_FLAG',
  DOCUMENTS_REQUESTED: 'DOCUMENTS_REQUESTED',
  THERAPIST_INVITED_TO_APPLY: 'THERAPIST_INVITED_TO_APPLY',
  JOB_INTERVIEW_SCHEDULED: 'JOB_INTERVIEW_SCHEDULED',
  JOB_INTERVIEW_RECORDING_CONSENT: 'JOB_INTERVIEW_RECORDING_CONSENT',
  JOB_INTERVIEW_CANCELLED: 'JOB_INTERVIEW_CANCELLED',
  JOB_INTERVIEW_COMPLETED: 'JOB_INTERVIEW_COMPLETED',
  JOB_INTERVIEW_STARTING_SOON: 'JOB_INTERVIEW_STARTING_SOON',
  JOB_INTERVIEW_REMINDER: 'JOB_INTERVIEW_REMINDER',
  JOB_INTERVIEW_RESCHEDULED: 'JOB_INTERVIEW_RESCHEDULED',
  JOB_OPPORTUNITY_CLOSED: 'JOB_OPPORTUNITY_CLOSED',
  FIRST_SESSION_SCHEDULED_FROM_HIRE: 'FIRST_SESSION_SCHEDULED_FROM_HIRE',
} as const;

export const FORBIDDEN_PUBLIC_JOB_FIELDS = [
  'childId',
  'childServiceNeedId',
  'internalNotes',
  'internalSchedule',
  'firstName',
  'lastName',
  'dateOfBirth',
  'diagnosisCodes',
] as const;
