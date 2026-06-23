import { Test, TestingModule } from '@nestjs/testing';
import { Decimal } from '@prisma/client/runtime/client';
import {
  EiAgencyBillingProfile,
  EiCaseBillingProfile,
  EiConsentStatus,
  EiCredentialStatus,
  EiMedicaidEnrollmentStatus,
  EiProviderEnrollment,
  SessionStatus,
} from '../../generated/prisma/client';
import { EI_VALIDATION_CODES } from './ei-billing.constants';
import {
  EiBillingValidationService,
  EiValidationContext,
} from './ei-billing-validation.service';

describe('EiBillingValidationService', () => {
  let service: EiBillingValidationService;

  const baseRecord = {
    sessionId: 'session-1',
    serviceDate: new Date('2025-06-01'),
    units: new Decimal(4),
    startTime: new Date('2025-06-01T10:00:00Z'),
    endTime: new Date('2025-06-01T11:00:00Z'),
  };

  const completeAgencyProfile = {
    legalName: 'Demo EI Agency LLC',
    npi: '1234567890',
    medicaidProviderId: 'MP123',
    ein: '12-3456789',
    baaSignedAt: new Date('2025-01-01'),
    enrollmentComplete: true,
  } as EiAgencyBillingProfile;

  const activeEnrollment = {
    isActive: true,
    credentialStatus: EiCredentialStatus.ACTIVE,
    medicaidEnrollmentStatus: EiMedicaidEnrollmentStatus.ENROLLED,
    licenseExpiry: new Date('2026-12-31'),
    scrClearanceExpiry: new Date('2026-06-30'),
  } as EiProviderEnrollment;

  const validCaseProfile = {
    ifspAuthorizationNumber: 'IFSP-2025-001',
    medicaidCin: 'AB12345C',
    consentStatus: EiConsentStatus.GRANTED,
    authorizationStartDate: new Date('2025-01-01'),
    authorizationEndDate: new Date('2025-12-31'),
    placeOfService: 'CLINIC',
  } as EiCaseBillingProfile;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [EiBillingValidationService],
    }).compile();
    service = module.get(EiBillingValidationService);
  });

  function ctx(overrides: Partial<EiValidationContext> = {}): EiValidationContext {
    return {
      record: baseRecord,
      session: {
        id: 'session-1',
        status: SessionStatus.COMPLETED,
        durationMinutes: 60,
        evvVerified: true,
        soapNote: { signedAt: new Date('2025-06-01T11:30:00Z') },
      } as EiValidationContext['session'],
      agencyProfile: completeAgencyProfile,
      providerEnrollment: activeEnrollment,
      caseProfile: validCaseProfile,
      duplicateSessionBilling: false,
      ...overrides,
    };
  }

  it('passes validation for a complete EI billing context', () => {
    const issues = service.validate(ctx());
    expect(issues.filter((i) => i.severity === 'ERROR')).toHaveLength(0);
    expect(service.deriveQueueStatus(issues)).toBe('READY_AGENCY_REVIEW');
  });

  it('blocks billing when session is not completed', () => {
    const issues = service.validate(
      ctx({
        session: {
          ...(ctx().session as NonNullable<EiValidationContext['session']>),
          status: SessionStatus.IN_PROGRESS,
        },
      }),
    );
    expect(issues.some((i) => i.code === EI_VALIDATION_CODES.SESSION_NOT_COMPLETED)).toBe(true);
  });

  it('blocks billing when SOAP note is unsigned', () => {
    const issues = service.validate(
      ctx({
        session: {
          ...(ctx().session as NonNullable<EiValidationContext['session']>),
          soapNote: { signedAt: null },
        } as EiValidationContext['session'],
      }),
    );
    expect(issues.some((i) => i.code === EI_VALIDATION_CODES.SOAP_NOTE_UNSIGNED)).toBe(true);
  });

  it('flags missing agency billing profile', () => {
    const issues = service.validate(ctx({ agencyProfile: null }));
    expect(issues.some((i) => i.code === EI_VALIDATION_CODES.AGENCY_PROFILE_INCOMPLETE)).toBe(true);
    expect(service.deriveQueueStatus(issues)).toBe('DRAFT_INCOMPLETE');
  });

  it('flags unsigned agency BAA', () => {
    const issues = service.validate(
      ctx({
        agencyProfile: {
          ...completeAgencyProfile,
          baaSignedAt: null,
          enrollmentComplete: false,
        },
      }),
    );
    expect(issues.some((i) => i.code === EI_VALIDATION_CODES.AGENCY_BAA_MISSING)).toBe(true);
  });

  it('blocks inactive provider enrollment', () => {
    const issues = service.validate(
      ctx({
        providerEnrollment: {
          ...activeEnrollment,
          credentialStatus: EiCredentialStatus.SUSPENDED,
        },
      }),
    );
    expect(
      issues.some((i) => i.code === EI_VALIDATION_CODES.PROVIDER_CREDENTIAL_INACTIVE),
    ).toBe(true);
  });

  it('blocks expired provider license', () => {
    const issues = service.validate(
      ctx({
        providerEnrollment: {
          ...activeEnrollment,
          licenseExpiry: new Date('2020-01-01'),
        },
      }),
    );
    expect(issues.some((i) => i.code === EI_VALIDATION_CODES.LICENSE_EXPIRED)).toBe(true);
  });

  it('requires Medicaid CIN on case profile', () => {
    const issues = service.validate(
      ctx({
        caseProfile: { ...validCaseProfile, medicaidCin: '' },
      }),
    );
    expect(issues.some((i) => i.code === EI_VALIDATION_CODES.MEDICAID_CIN_MISSING)).toBe(true);
    expect(service.deriveQueueStatus(issues)).toBe('MISSING_INFORMATION');
  });

  it('rejects service dates outside authorization window', () => {
    const issues = service.validate(
      ctx({
        record: { ...baseRecord, serviceDate: new Date('2026-03-01') },
      }),
    );
    expect(issues.some((i) => i.code === EI_VALIDATION_CODES.AUTH_DATE_OUT_OF_RANGE)).toBe(true);
  });

  it('detects duplicate session billing', () => {
    const issues = service.validate(ctx({ duplicateSessionBilling: true }));
    expect(issues.some((i) => i.code === EI_VALIDATION_CODES.DUPLICATE_SESSION_BILLING)).toBe(true);
  });
});
