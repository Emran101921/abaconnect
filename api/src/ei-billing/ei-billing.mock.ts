import { PrismaClient } from '../../generated/prisma/client';
import { EI_VALIDATION_CODES } from './ei-billing.constants';

const DEMO_RECORD_IDS = {
  readyAgencyReview: '00000000-0000-4000-8000-0000000000e2',
  missingInformation: '00000000-0000-4000-8000-0000000000e3',
  submitted: '00000000-0000-4000-8000-0000000000e4',
  correctionNeeded: '00000000-0000-4000-8000-0000000000e5',
  paid: '00000000-0000-4000-8000-0000000000e6',
  validationIssue: '00000000-0000-4000-8000-0000000000e7',
  denial: '00000000-0000-4000-8000-0000000000e8',
  payment: '00000000-0000-4000-8000-0000000000e9',
} as const;

/** Optional demo NY EI billing seed for Demo Therapy Agency. */
export async function seedEiBillingDemo(
  prisma: PrismaClient,
  tenantId: string,
  agencyId: string,
  therapistId: string,
  childId: string,
  postedById: string,
) {
  await prisma.eiAgencyBillingProfile.upsert({
    where: { agencyId },
    update: {},
    create: {
      tenantId,
      agencyId,
      legalName: 'Demo Therapy Agency LLC',
      npi: '1234567893',
      medicaidProviderId: 'NY-EI-DEMO-001',
      ein: '12-3456789',
      etin: 'ETIN-DEMO',
      eiHubReferenceId: 'EI-HUB-DEMO',
      eftEnrollmentStatus: 'ACTIVE',
      baaSignedAt: new Date('2025-01-15'),
      baaSignerName: 'Alex Agency',
      enrollmentComplete: true,
      city: 'Brooklyn',
      state: 'NY',
      zipCode: '11201',
    },
  });

  await prisma.eiProviderEnrollment.upsert({
    where: { agencyId_therapistId: { agencyId, therapistId } },
    update: {},
    create: {
      agencyId,
      therapistId,
      renderingNpi: '9876543210',
      licenseNumber: 'SLP-NY-12345',
      licenseState: 'NY',
      licenseExpiry: new Date('2026-12-31'),
      discipline: 'SPEECH',
      eiCategory: 'SPEECH_LANGUAGE_PATHOLOGY',
      medicaidEnrollmentStatus: 'ENROLLED',
      credentialStatus: 'ACTIVE',
      scrClearanceDate: new Date('2025-01-01'),
      scrClearanceExpiry: new Date('2026-12-31'),
      isActive: true,
    },
  });

  const caseProfile = await prisma.eiCaseBillingProfile.upsert({
    where: { agencyId_childId: { agencyId, childId } },
    update: {},
    create: {
      agencyId,
      childId,
      eiCaseId: 'EI-CASE-DEMO-001',
      municipality: 'Kings County',
      scReferenceNumber: 'SC-REF-001',
      ifspAuthorizationNumber: 'IFSP-2025-DEMO',
      serviceType: 'SPEECH',
      frequencyPerWeek: 2,
      durationMinutes: 60,
      authorizationStartDate: new Date('2025-01-01'),
      authorizationEndDate: new Date('2025-12-31'),
      placeOfService: 'HOME',
      medicaidCin: 'AB12345C',
      consentStatus: 'GRANTED',
      consentSignedAt: new Date('2025-01-10'),
    },
  });

  await prisma.eiClearinghouseConfig.upsert({
    where: { id: '00000000-0000-4000-8000-0000000000e1' },
    update: {},
    create: {
      id: '00000000-0000-4000-8000-0000000000e1',
      tenantId,
      agencyId,
      name: 'Demo EI-Hub Stub',
      workflow: 'EI_HUB',
      tradingPartnerId: 'DEMO-TP',
      submitterId: 'DEMO-SUB',
      receiverId: 'DEMO-REC',
      baaSignedAt: new Date('2025-01-15'),
      testMode: true,
      isActive: true,
      credentialsRef: 'vault://demo/ei-hub-credentials',
    },
  });

  const demoRecords = [
    {
      id: DEMO_RECORD_IDS.readyAgencyReview,
      queueStatus: 'READY_AGENCY_REVIEW' as const,
      serviceDate: new Date('2025-06-01'),
      units: 4,
      billedAmount: 240,
    },
    {
      id: DEMO_RECORD_IDS.missingInformation,
      queueStatus: 'MISSING_INFORMATION' as const,
      serviceDate: new Date('2025-06-08'),
      units: 4,
      billedAmount: 240,
    },
    {
      id: DEMO_RECORD_IDS.submitted,
      queueStatus: 'SUBMITTED' as const,
      serviceDate: new Date('2025-06-15'),
      units: 4,
      billedAmount: 240,
      submittedAt: new Date('2025-06-16'),
      externalReferenceId: 'EI-HUB-DEMO-REF-001',
      clearinghouseWorkflow: 'EI_HUB' as const,
    },
    {
      id: DEMO_RECORD_IDS.correctionNeeded,
      queueStatus: 'CORRECTION_NEEDED' as const,
      serviceDate: new Date('2025-05-20'),
      units: 4,
      billedAmount: 240,
      submittedAt: new Date('2025-05-21'),
      externalReferenceId: 'EI-HUB-DEMO-REF-002',
      clearinghouseWorkflow: 'EI_HUB' as const,
    },
    {
      id: DEMO_RECORD_IDS.paid,
      queueStatus: 'PAID' as const,
      serviceDate: new Date('2025-05-01'),
      units: 4,
      billedAmount: 240,
      allowedAmount: 220,
      submittedAt: new Date('2025-05-02'),
      externalReferenceId: 'EI-HUB-DEMO-REF-003',
      clearinghouseWorkflow: 'EI_HUB' as const,
    },
  ];

  for (const record of demoRecords) {
    await prisma.eiBillingRecord.upsert({
      where: { id: record.id },
      update: {
        queueStatus: record.queueStatus,
        units: record.units,
        serviceDate: record.serviceDate,
        billedAmount: record.billedAmount,
        submittedAt: record.submittedAt ?? null,
        externalReferenceId: record.externalReferenceId ?? null,
        clearinghouseWorkflow: record.clearinghouseWorkflow ?? null,
        allowedAmount: record.allowedAmount ?? null,
      },
      create: {
        id: record.id,
        tenantId,
        agencyId,
        childId,
        therapistId,
        caseProfileId: caseProfile.id,
        queueStatus: record.queueStatus,
        units: record.units,
        serviceDate: record.serviceDate,
        billedAmount: record.billedAmount,
        allowedAmount: record.allowedAmount,
        submittedAt: record.submittedAt,
        externalReferenceId: record.externalReferenceId,
        clearinghouseWorkflow: record.clearinghouseWorkflow,
        lockedAt:
          record.queueStatus !== 'MISSING_INFORMATION'
            ? new Date('2025-06-01')
            : null,
      },
    });
  }

  await prisma.eiBillingValidationIssue.upsert({
    where: { id: DEMO_RECORD_IDS.validationIssue },
    update: {},
    create: {
      id: DEMO_RECORD_IDS.validationIssue,
      recordId: DEMO_RECORD_IDS.missingInformation,
      code: EI_VALIDATION_CODES.IFSP_AUTH_MISSING,
      severity: 'ERROR',
      message: 'IFSP authorization number is missing or expired for service date.',
      resolved: false,
    },
  });

  await prisma.eiDenialRejection.upsert({
    where: { id: DEMO_RECORD_IDS.denial },
    update: {},
    create: {
      id: DEMO_RECORD_IDS.denial,
      recordId: DEMO_RECORD_IDS.correctionNeeded,
      code: 'CO-16',
      reason: 'Claim/service lacks information needed for adjudication.',
      payerName: 'NY Medicaid EI',
      receivedAt: new Date('2025-05-25'),
      assignedStaffId: postedById,
      correctionStatus: 'OPEN',
      correctionNotes: 'Resubmit with corrected municipality code.',
    },
  });

  await prisma.eiPaymentPosting.upsert({
    where: { id: DEMO_RECORD_IDS.payment },
    update: {},
    create: {
      id: DEMO_RECORD_IDS.payment,
      recordId: DEMO_RECORD_IDS.paid,
      paidAmount: 220,
      allowedAmount: 220,
      adjustmentAmount: 20,
      eftReference: 'EFT-DEMO-2025-05',
      eraPlaceholder: 'ERA_IMPORT_PENDING',
      reconciliationStatus: 'RECONCILED',
      postedAt: new Date('2025-05-28'),
      postedById,
    },
  });
}
