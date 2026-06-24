import { Injectable } from '@nestjs/common';
import {
  EiAgencyBillingProfile,
  EiBillingRecord,
  EiCaseBillingProfile,
  EiCredentialStatus,
  EiConsentStatus,
  EiMedicaidEnrollmentStatus,
  EiProviderEnrollment,
  Session,
  SoapNote,
} from '../../generated/prisma/client';
import { EI_VALIDATION_CODES, EiValidationCode } from './ei-billing.constants';

export interface EiValidationIssueInput {
  code: EiValidationCode;
  severity: 'ERROR' | 'WARNING';
  message: string;
}

export interface EiValidationContext {
  record: Pick<
    EiBillingRecord,
    'sessionId' | 'serviceDate' | 'units' | 'startTime' | 'endTime'
  >;
  session?: (Session & { soapNote?: SoapNote | null }) | null;
  agencyProfile?: EiAgencyBillingProfile | null;
  providerEnrollment?: EiProviderEnrollment | null;
  caseProfile?: EiCaseBillingProfile | null;
  duplicateSessionBilling?: boolean;
}

@Injectable()
export class EiBillingValidationService {
  validate(context: EiValidationContext): EiValidationIssueInput[] {
    const issues: EiValidationIssueInput[] = [];

    if (!context.record.serviceDate) {
      issues.push({
        code: EI_VALIDATION_CODES.SERVICE_DATE_MISSING,
        severity: 'ERROR',
        message: 'Service date is required for NY EI billing.',
      });
    }

    this.validateSessionGate(context, issues);
    this.validateAgencyProfile(context.agencyProfile, issues);
    this.validateProviderEnrollment(context.providerEnrollment, issues);
    this.validateCaseProfile(context.caseProfile, context.record, issues);
    this.validateDuplicate(context.duplicateSessionBilling, issues);
    this.validateUnits(context, issues);

    return issues;
  }

  deriveQueueStatus(
    issues: EiValidationIssueInput[],
  ): 'DRAFT_INCOMPLETE' | 'MISSING_INFORMATION' | 'READY_AGENCY_REVIEW' {
    if (issues.some((i) => i.severity === 'ERROR')) {
      const blockingCodes = new Set<string>([
        EI_VALIDATION_CODES.AGENCY_PROFILE_INCOMPLETE,
        EI_VALIDATION_CODES.AGENCY_BAA_MISSING,
        EI_VALIDATION_CODES.PROVIDER_NOT_ENROLLED,
        EI_VALIDATION_CODES.CASE_PROFILE_MISSING,
      ]);
      if (issues.some((i) => blockingCodes.has(i.code))) {
        return 'DRAFT_INCOMPLETE';
      }
      return 'MISSING_INFORMATION';
    }
    return 'READY_AGENCY_REVIEW';
  }

  private validateSessionGate(
    context: EiValidationContext,
    issues: EiValidationIssueInput[],
  ): void {
    if (!context.session) {
      return;
    }

    if (context.session.status !== 'COMPLETED') {
      issues.push({
        code: EI_VALIDATION_CODES.SESSION_NOT_COMPLETED,
        severity: 'ERROR',
        message: 'Session must be marked completed before EI billing.',
      });
    }

    const note = context.session.soapNote;
    if (!note?.signedAt) {
      issues.push({
        code: EI_VALIDATION_CODES.SOAP_NOTE_UNSIGNED,
        severity: 'ERROR',
        message: 'Signed SOAP note is required before billing lock.',
      });
    }

    if (
      context.caseProfile?.placeOfService === 'HOME' &&
      !context.session.evvVerified
    ) {
      issues.push({
        code: EI_VALIDATION_CODES.EVV_NOT_VERIFIED,
        severity: 'ERROR',
        message: 'EVV verification required for home-based EI services.',
      });
    }
  }

  private validateAgencyProfile(
    profile: EiAgencyBillingProfile | null | undefined,
    issues: EiValidationIssueInput[],
  ): void {
    if (!profile) {
      issues.push({
        code: EI_VALIDATION_CODES.AGENCY_PROFILE_INCOMPLETE,
        severity: 'ERROR',
        message: 'Agency NY EI billing profile is not configured.',
      });
      return;
    }

    const required = [
      profile.legalName,
      profile.npi,
      profile.medicaidProviderId,
      profile.ein,
    ];
    if (required.some((v) => !v?.trim())) {
      issues.push({
        code: EI_VALIDATION_CODES.AGENCY_PROFILE_INCOMPLETE,
        severity: 'ERROR',
        message:
          'Agency billing profile missing legal name, NPI, Medicaid provider ID, or EIN.',
      });
    }

    if (!profile.baaSignedAt || !profile.enrollmentComplete) {
      issues.push({
        code: EI_VALIDATION_CODES.AGENCY_BAA_MISSING,
        severity: 'ERROR',
        message: 'Agency BAA must be signed and enrollment marked complete.',
      });
    }
  }

  private validateProviderEnrollment(
    enrollment: EiProviderEnrollment | null | undefined,
    issues: EiValidationIssueInput[],
  ): void {
    if (!enrollment) {
      issues.push({
        code: EI_VALIDATION_CODES.PROVIDER_NOT_ENROLLED,
        severity: 'ERROR',
        message: 'Therapist is not enrolled for NY EI billing at this agency.',
      });
      return;
    }

    if (
      !enrollment.isActive ||
      enrollment.credentialStatus !== EiCredentialStatus.ACTIVE
    ) {
      issues.push({
        code: EI_VALIDATION_CODES.PROVIDER_CREDENTIAL_INACTIVE,
        severity: 'ERROR',
        message: 'Provider credentials are not active for billing.',
      });
    }

    if (
      enrollment.medicaidEnrollmentStatus !== EiMedicaidEnrollmentStatus.ENROLLED
    ) {
      issues.push({
        code: EI_VALIDATION_CODES.PROVIDER_NOT_ENROLLED,
        severity: 'ERROR',
        message: 'Provider Medicaid enrollment is not active.',
      });
    }

    if (
      enrollment.licenseExpiry &&
      enrollment.licenseExpiry < new Date()
    ) {
      issues.push({
        code: EI_VALIDATION_CODES.LICENSE_EXPIRED,
        severity: 'ERROR',
        message: 'Provider professional license has expired.',
      });
    }

    if (
      enrollment.scrClearanceExpiry &&
      enrollment.scrClearanceExpiry < new Date()
    ) {
      issues.push({
        code: EI_VALIDATION_CODES.SCR_CLEARANCE_EXPIRED,
        severity: 'ERROR',
        message: 'SCR clearance has expired for this provider.',
      });
    }
  }

  private validateCaseProfile(
    caseProfile: EiCaseBillingProfile | null | undefined,
    record: EiValidationContext['record'],
    issues: EiValidationIssueInput[],
  ): void {
    if (!caseProfile) {
      issues.push({
        code: EI_VALIDATION_CODES.CASE_PROFILE_MISSING,
        severity: 'ERROR',
        message: 'EI case billing profile is missing for this child.',
      });
      return;
    }

    if (!caseProfile.ifspAuthorizationNumber?.trim()) {
      issues.push({
        code: EI_VALIDATION_CODES.IFSP_AUTH_MISSING,
        severity: 'ERROR',
        message: 'IFSP authorization number is required.',
      });
    }

    if (!caseProfile.medicaidCin?.trim()) {
      issues.push({
        code: EI_VALIDATION_CODES.MEDICAID_CIN_MISSING,
        severity: 'ERROR',
        message: 'Medicaid CIN is required for NY EI billing.',
      });
    }

    if (caseProfile.consentStatus !== EiConsentStatus.GRANTED) {
      issues.push({
        code: EI_VALIDATION_CODES.CONSENT_NOT_GRANTED,
        severity: 'ERROR',
        message: 'Parent/guardian billing consent must be granted.',
      });
    }

    const serviceDate = record.serviceDate;
    if (
      caseProfile.authorizationStartDate &&
      caseProfile.authorizationEndDate &&
      serviceDate
    ) {
      const start = caseProfile.authorizationStartDate;
      const end = caseProfile.authorizationEndDate;
      if (serviceDate < start || serviceDate > end) {
        issues.push({
          code: EI_VALIDATION_CODES.AUTH_DATE_OUT_OF_RANGE,
          severity: 'ERROR',
          message: 'Service date falls outside IFSP authorization period.',
        });
      }
    }
  }

  private validateDuplicate(
    duplicate: boolean | undefined,
    issues: EiValidationIssueInput[],
  ): void {
    if (duplicate) {
      issues.push({
        code: EI_VALIDATION_CODES.DUPLICATE_SESSION_BILLING,
        severity: 'ERROR',
        message: 'A billing record already exists for this session.',
      });
    }
  }

  private validateUnits(
    context: EiValidationContext,
    issues: EiValidationIssueInput[],
  ): void {
    const session = context.session;
    const duration = session?.durationMinutes;
    if (duration && Number(context.record.units) > 0) {
      const expectedUnits = Math.ceil(duration / 15);
      if (Number(context.record.units) !== expectedUnits) {
        issues.push({
          code: EI_VALIDATION_CODES.UNITS_MISMATCH,
          severity: 'WARNING',
          message: `Units (${context.record.units}) may not match session duration (${duration} min).`,
        });
      }
    }
  }
}
