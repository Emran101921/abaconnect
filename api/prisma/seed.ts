import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';
import { Prisma, PrismaClient } from '../generated/prisma/client';
import {
  buildEarlyInterventionQuestionsJson,
  EARLY_INTERVENTION_TEMPLATE_NAME,
} from '../src/screenings/early-intervention-template';
import {
  ACKNOWLEDGMENT_CHECKBOX_TEXT,
  ACKNOWLEDGMENT_SHORT_TEXT,
  buildDefaultNoticeOfPrivacyPractices,
  buildDefaultPrivacyPolicy,
} from '../src/compliance/privacy-notice.content';
import {
  jitterMapPin,
  zipToApproxCentroid,
} from '../src/marketplace/marketplace-zip.util';
import { seedEiBillingDemo } from '../src/ei-billing/ei-billing.mock';
import {
  buildJobOpportunityTitle,
  buildLocationAreaLabel,
} from '../src/job-opportunities/job-opportunity-phi.util';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

/** Fixed TOTP secret for demo users (plaintext; MFA service falls back if not encrypted). */
const DEMO_MFA_SECRET = 'JBSWY3DPEHPK3PXP';
/** Device ids used by scripts/smoke-*.sh so CI logins skip step-up MFA. */
const SMOKE_DEVICE_IDS = [
  'smoke-ci-device',
  'smoke-marketplace-device',
  'smoke-self-pay-device',
  'smoke-sc-device',
  'smoke-calls-device',
  'smoke-ei-billing-device',
] as const;
const SMOKE_DEVICE_ID = SMOKE_DEVICE_IDS[0];

async function seedActivePrivacyNotice(tenantId: string) {
  return prisma.privacyNoticeVersion.upsert({
    where: {
      tenantId_versionNumber: { tenantId, versionNumber: '1.0' },
    },
    create: {
      tenantId,
      versionNumber: '1.0',
      title: 'Notice of Privacy Practices',
      fullNoticeText: buildDefaultNoticeOfPrivacyPractices(),
      privacyPolicyText: buildDefaultPrivacyPolicy(),
      effectiveDate: new Date('2025-06-01'),
      isActive: true,
    },
    update: { isActive: true },
  });
}

async function seedNoticeAcknowledgment(
  tenantId: string,
  userId: string,
  noticeId: string,
): Promise<void> {
  const existing = await prisma.hipaaNoticeAcknowledgment.findFirst({
    where: { userId, noticeVersionId: noticeId },
  });
  if (existing) return;

  const snapshot = `${ACKNOWLEDGMENT_SHORT_TEXT}\n\n${ACKNOWLEDGMENT_CHECKBOX_TEXT}`;
  await prisma.hipaaNoticeAcknowledgment.create({
    data: {
      tenantId,
      userId,
      noticeVersionId: noticeId,
      noticeVersion: '1.0',
      ipAddress: '127.0.0.1',
      userAgent: 'seed',
      appVersion: 'seed',
      platform: 'ci',
      deviceId: SMOKE_DEVICE_ID,
      acknowledgmentTextSnapshot: snapshot,
    },
  });
}

async function seedSmokeTrustedDevices(userId: string): Promise<void> {
  const now = new Date();
  for (const deviceId of SMOKE_DEVICE_IDS) {
    await prisma.authDevice.upsert({
      where: { userId_deviceId: { userId, deviceId } },
      create: {
        userId,
        deviceId,
        deviceModel: 'CI smoke runner',
        platform: 'ci',
        trusted: true,
        mfaVerifiedAt: now,
        lastSeenAt: now,
      },
      update: {
        trusted: true,
        mfaVerifiedAt: now,
        lastSeenAt: now,
      },
    });
  }
}

async function seedDemoOnboarding(userId: string): Promise<void> {
  await prisma.user.update({
    where: { id: userId },
    data: { mfaEnabled: true, mfaSecret: DEMO_MFA_SECRET },
  });
  await seedSmokeTrustedDevices(userId);
}

const LEGACY_DEMO_CHILD_IDS = [
  '00000000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-000000000002',
];

const LEGACY_DEMO_SEED_IDS = {
  appointments: [
    '00000000-0000-4000-8000-000000000010',
    '00000000-0000-4000-8000-000000000011',
    '00000000-0000-4000-8000-000000000012',
  ],
  messageThread: '00000000-0000-4000-8000-000000000020',
  payments: [
    '00000000-0000-4000-8000-000000000030',
    '00000000-0000-4000-8000-000000000031',
  ],
  document: '00000000-0000-4000-8000-000000000040',
  claim: '00000000-0000-4000-8000-000000000050',
  treatmentPlan: '00000000-0000-4000-8000-000000000080',
  dispute: '00000000-0000-4000-8000-000000000091',
  complaint: '00000000-0000-4000-8000-000000000070',
};

const DEMO_MARKETPLACE_SEED_IDS = {
  child: '00000000-0000-4000-8000-000000000003',
  activeRequest: '00000000-0000-4000-8000-000000000100',
  pausedRequest: '00000000-0000-4000-8000-000000000101',
  pendingInterest: '00000000-0000-4000-8000-000000000102',
};

const DEMO_JOB_OPPORTUNITY_SEED_IDS = {
  serviceNeed: '00000000-0000-4000-8000-000000000110',
  opportunity: '00000000-0000-4000-8000-000000000111',
};

async function seedDemoJobOpportunity(
  tenantId: string,
  agencyId: string,
  childId: string,
  createdByUserId: string,
) {
  const zipCode = '11230';
  const centroid = zipToApproxCentroid(zipCode);
  const locationLabel = buildLocationAreaLabel(null, null, zipCode);
  const title = buildJobOpportunityTitle('SPEECH', locationLabel);

  const need = await prisma.childServiceNeed.upsert({
    where: { id: DEMO_JOB_OPPORTUNITY_SEED_IDS.serviceNeed },
    update: {},
    create: {
      id: DEMO_JOB_OPPORTUNITY_SEED_IDS.serviceNeed,
      agencyId,
      childId,
      serviceType: 'SPEECH',
      internalNotes: 'Demo internal staffing need for speech therapy',
      createdByUserId,
      status: 'JOB_POSTED',
    },
  });

  await prisma.jobOpportunity.upsert({
    where: { id: DEMO_JOB_OPPORTUNITY_SEED_IDS.opportunity },
    update: {},
    create: {
      id: DEMO_JOB_OPPORTUNITY_SEED_IDS.opportunity,
      tenantId,
      agencyId,
      childServiceNeedId: need.id,
      title,
      serviceType: 'SPEECH',
      status: 'PUBLISHED',
      publicDescription:
        'Seeking a licensed speech-language pathologist for pediatric early intervention services.',
      zipCode,
      zipCentroidLat: centroid.lat,
      zipCentroidLng: centroid.lng,
      serviceRadiusMiles: 15,
      phiScanPassed: true,
      publishedAt: new Date(),
    },
  });
}

const DEMO_EI_SCREENING_ID = '00000000-0000-4000-8000-000000000052';

async function seedDemoEiEligibility(
  tenantId: string,
  parentId: string,
  childId: string,
) {
  const eiTemplate = await prisma.screeningTemplate.findFirstOrThrow({
    where: { tenantId, therapyType: 'EARLY_INTERVENTION' },
  });

  await prisma.screeningResponse.upsert({
    where: { id: DEMO_EI_SCREENING_ID },
    update: {
      riskLevel: 'MODERATE',
      evaluationRequestedAt: new Date(),
      isDraft: false,
      concernTags: ['speech_delay', 'communication'],
    },
    create: {
      id: DEMO_EI_SCREENING_ID,
      tenantId,
      childId,
      parentId,
      templateId: eiTemplate.id,
      responses: { a_premature_birth: true },
      score: 0.65,
      riskLevel: 'MODERATE',
      recommendations: ['Speech evaluation recommended'],
      concernTags: ['speech_delay', 'communication'],
      isDraft: false,
      evaluationRequestedAt: new Date(),
      disclaimerAccepted: true,
      completedAt: new Date(),
    },
  });
}

async function seedMarketplaceDemoData(
  tenantId: string,
  parentUserId: string,
  therapistProviderProfileId: string,
) {
  const parent = await prisma.parent.findUniqueOrThrow({
    where: { userId: parentUserId },
  });

  const child = await prisma.child.upsert({
    where: { id: DEMO_MARKETPLACE_SEED_IDS.child },
    update: {
      zipCode: '11230',
      city: 'Brooklyn',
      state: 'NY',
      ageRange: 'MONTHS_25_36',
      dateOfBirth: new Date('2024-04-01'),
      gender: 'Male',
      primaryLanguage: 'English',
      guardianName: 'Parent One',
      guardianPhone: '555-0101',
      guardianEmail: 'parent1@demo.local',
      insuranceType: 'Medicaid',
    },
    create: {
      id: DEMO_MARKETPLACE_SEED_IDS.child,
      tenantId,
      parentId: parent.id,
      firstName: 'Jordan',
      lastName: 'Demo',
      dateOfBirth: new Date('2024-04-01'),
      zipCode: '11230',
      city: 'Brooklyn',
      state: 'NY',
      ageRange: 'MONTHS_25_36',
      primaryLanguage: 'English',
      gender: 'Male',
      guardianName: 'Parent One',
      guardianPhone: '555-0101',
      guardianEmail: 'parent1@demo.local',
      insuranceType: 'Medicaid',
    },
  });

  const requestIds = [
    DEMO_MARKETPLACE_SEED_IDS.activeRequest,
    DEMO_MARKETPLACE_SEED_IDS.pausedRequest,
  ];
  await prisma.marketplaceInterest.deleteMany({
    where: {
      OR: [
        { marketplaceRequestId: { in: requestIds } },
        { id: DEMO_MARKETPLACE_SEED_IDS.pendingInterest },
      ],
    },
  });
  await prisma.marketplaceConsentRecord.deleteMany({
    where: { marketplaceRequestId: { in: requestIds } },
  });
  await prisma.marketplaceRequest.deleteMany({
    where: { id: { in: requestIds } },
  });

  const sharedRequestFields = {
    tenantId,
    childId: child.id,
    parentUserId,
    serviceCategories: ['SPEECH', 'ABA'],
    concernTags: ['speech_delay'],
    ageRange: 'YEARS_3_5' as const,
    zipCode: '11230',
    city: 'Brooklyn',
    state: 'NY',
    zipCentroidLat: 40.6182,
    zipCentroidLng: -73.9607,
    mapPinJitterLat: 40.619,
    mapPinJitterLng: -73.961,
    locationType: 'HOME' as const,
    authorizationStatus: 'PARENT_SCREENING_ONLY' as const,
    urgency: 'ROUTINE' as const,
    languagePreference: 'English',
    publicDescription: 'Seeking speech and ABA support in the Brooklyn area.',
  };

  await prisma.marketplaceRequest.upsert({
    where: { id: DEMO_MARKETPLACE_SEED_IDS.activeRequest },
    update: {
      status: 'ACTIVE',
      ...sharedRequestFields,
    },
    create: {
      id: DEMO_MARKETPLACE_SEED_IDS.activeRequest,
      anonymousPublicId: 'SR-SEED01',
      status: 'ACTIVE',
      ...sharedRequestFields,
    },
  });

  await prisma.marketplaceInterest.upsert({
    where: { id: DEMO_MARKETPLACE_SEED_IDS.pendingInterest },
    update: {
      tenantId,
      marketplaceRequestId: DEMO_MARKETPLACE_SEED_IDS.activeRequest,
      providerProfileId: therapistProviderProfileId,
      status: 'PENDING_PARENT_REVIEW',
      message: 'Available weekday afternoons for evaluation.',
    },
    create: {
      id: DEMO_MARKETPLACE_SEED_IDS.pendingInterest,
      tenantId,
      marketplaceRequestId: DEMO_MARKETPLACE_SEED_IDS.activeRequest,
      providerProfileId: therapistProviderProfileId,
      status: 'PENDING_PARENT_REVIEW',
      message: 'Available weekday afternoons for evaluation.',
    },
  });

  await prisma.marketplaceRequest.upsert({
    where: { id: DEMO_MARKETPLACE_SEED_IDS.pausedRequest },
    update: {
      status: 'PAUSED',
      ...sharedRequestFields,
    },
    create: {
      id: DEMO_MARKETPLACE_SEED_IDS.pausedRequest,
      anonymousPublicId: 'SR-SEED02',
      status: 'PAUSED',
      ...sharedRequestFields,
    },
  });
}

async function repairMarketplaceZipCentroids(): Promise<void> {
  const requests = await prisma.marketplaceRequest.findMany({
    select: { id: true, zipCode: true, childId: true },
  });
  for (const request of requests) {
    const centroid = zipToApproxCentroid(request.zipCode);
    const jitter = jitterMapPin(centroid.lat, centroid.lng, request.childId);
    await prisma.marketplaceRequest.update({
      where: { id: request.id },
      data: {
        zipCentroidLat: centroid.lat,
        zipCentroidLng: centroid.lng,
        mapPinJitterLat: jitter.lat,
        mapPinJitterLng: jitter.lng,
      },
    });
  }
}

async function cleanupTherapistCaseload(
  therapistId: string,
  therapistUserId: string,
): Promise<void> {
  await prisma.session.deleteMany({ where: { therapistId } });
  await prisma.telehealthSession.deleteMany({
    where: { appointment: { therapistId } },
  });
  await prisma.appointment.deleteMany({ where: { therapistId } });
  await prisma.treatmentPlan.deleteMany({ where: { therapistId } });
  await prisma.complaint.deleteMany({ where: { therapistId } });
  await prisma.review.deleteMany({ where: { therapistId } });

  const threadParticipants = await prisma.messageParticipant.findMany({
    where: { userId: therapistUserId },
    select: { threadId: true },
  });
  const threadIds = [
    ...new Set(threadParticipants.map((row: { threadId: string }) => row.threadId)),
  ];
  if (threadIds.length > 0) {
    await prisma.message.deleteMany({ where: { threadId: { in: threadIds } } });
    await prisma.messageParticipant.deleteMany({
      where: { threadId: { in: threadIds } },
    });
    await prisma.messageThread.deleteMany({ where: { id: { in: threadIds } } });
  }
}

async function deleteLegacyParentDemoAccount(tenantId: string): Promise<void> {
  const legacyParent = await prisma.user.findUnique({
    where: {
      tenantId_email: { tenantId, email: 'parent@demo.local' },
    },
    include: { parent: true },
  });
  if (!legacyParent) return;

  const parentId = legacyParent.parent?.id;
  if (parentId) {
    const children = await prisma.child.findMany({
      where: { parentId },
      select: { id: true },
    });
    const childIds = children.map((child) => child.id);

    await prisma.insuranceClaim.deleteMany({ where: { parentId } });
    await prisma.payment.deleteMany({ where: { parentId } });
    await prisma.dispute.deleteMany({ where: { parentId } });
    await prisma.complaint.deleteMany({ where: { parentId } });
    await prisma.screeningResponse.deleteMany({ where: { parentId } });
    if (childIds.length > 0) {
      await prisma.document.deleteMany({ where: { childId: { in: childIds } } });
      await prisma.session.deleteMany({ where: { childId: { in: childIds } } });
    }
    await prisma.appointment.deleteMany({ where: { parentId } });
    await prisma.child.deleteMany({ where: { parentId } });
  }

  await prisma.message.deleteMany({ where: { senderId: legacyParent.id } });
  await prisma.messageParticipant.deleteMany({
    where: { userId: legacyParent.id },
  });
  await prisma.notification.deleteMany({ where: { userId: legacyParent.id } });
  await prisma.hipaaConsent.deleteMany({ where: { userId: legacyParent.id } });
  await prisma.hipaaNoticeAcknowledgment.deleteMany({
    where: { userId: legacyParent.id },
  });
  await prisma.authDevice.deleteMany({ where: { userId: legacyParent.id } });
  await prisma.user.delete({ where: { id: legacyParent.id } });
}

async function cleanupLegacyDemoClinicalData(
  tenantId: string,
  therapistId: string,
  therapistUserId: string,
): Promise<void> {
  await deleteLegacyParentDemoAccount(tenantId);
  await cleanupTherapistCaseload(therapistId, therapistUserId);

  await prisma.messageThread.deleteMany({
    where: { id: LEGACY_DEMO_SEED_IDS.messageThread },
  });
  await prisma.child.deleteMany({
    where: { id: { in: LEGACY_DEMO_CHILD_IDS } },
  });
  await prisma.dispute.deleteMany({
    where: { id: LEGACY_DEMO_SEED_IDS.dispute },
  });
  await prisma.complaint.deleteMany({
    where: { id: LEGACY_DEMO_SEED_IDS.complaint },
  });
  await prisma.insuranceClaim.deleteMany({
    where: { id: LEGACY_DEMO_SEED_IDS.claim },
  });
  await prisma.treatmentPlan.deleteMany({
    where: { id: LEGACY_DEMO_SEED_IDS.treatmentPlan },
  });
  await prisma.document.deleteMany({
    where: { id: LEGACY_DEMO_SEED_IDS.document },
  });
  await prisma.payment.deleteMany({
    where: { id: { in: LEGACY_DEMO_SEED_IDS.payments } },
  });
  await prisma.session.deleteMany({
    where: {
      appointmentId: { in: LEGACY_DEMO_SEED_IDS.appointments },
    },
  });
  await prisma.telehealthSession.deleteMany({
    where: {
      appointmentId: { in: LEGACY_DEMO_SEED_IDS.appointments },
    },
  });
  await prisma.appointment.deleteMany({
    where: { id: { in: LEGACY_DEMO_SEED_IDS.appointments } },
  });
}

async function seedEmptyParentAccount(
  tenantId: string,
  email: string,
  passwordHash: string,
  firstName: string,
  lastName: string,
  noticeId: string,
) {
  const user = await prisma.user.upsert({
    where: { tenantId_email: { tenantId, email } },
    update: {
      passwordHash,
      firstName,
      lastName,
      role: 'PARENT',
      isActive: true,
    },
    create: {
      tenantId,
      email,
      passwordHash,
      role: 'PARENT',
      firstName,
      lastName,
    },
  });

  await prisma.parent.upsert({
    where: { userId: user.id },
    update: {},
    create: {
      userId: user.id,
      tenantId,
    },
  });

  const existingConsent = await prisma.hipaaConsent.findFirst({
    where: { userId: user.id, consentType: 'HIPAA_PRIVACY' },
  });
  if (!existingConsent) {
    await prisma.hipaaConsent.create({
      data: {
        tenantId,
        userId: user.id,
        consentType: 'HIPAA_PRIVACY',
        version: '1.0',
        granted: true,
      },
    });
  }

  await seedNoticeAcknowledgment(tenantId, user.id, noticeId);
  await seedDemoOnboarding(user.id);
  return user;
}

async function main() {
  const tenant = await prisma.tenant.upsert({
    where: { slug: 'abaconnect' },
    update: {},
    create: {
      name: 'BloomOra Platform',
      slug: 'abaconnect',
      settings: { branding: { primaryColor: '#1565C0' } },
      isActive: true,
    },
  });

  const bcrypt = await import('bcrypt');
  const adminHash = await bcrypt.hash('Admin123!', 10);
  const parent1Hash = await bcrypt.hash('Parent1Demo!', 10);
  const parent2Hash = await bcrypt.hash('Parent2Demo!', 10);
  const agencyHash = await bcrypt.hash('Agency123!', 10);
  const scHash = await bcrypt.hash('SC123!', 10);
  const billingHash = await bcrypt.hash('Billing123!', 10);
  const therapistHash = await bcrypt.hash('Therapist123!', 10);

  await prisma.user.upsert({
    where: {
      tenantId_email: { tenantId: tenant.id, email: 'admin@abaconnect.local' },
    },
    update: {},
    create: {
      tenantId: tenant.id,
      email: 'admin@abaconnect.local',
      passwordHash: adminHash,
      role: 'PLATFORM_ADMIN',
      firstName: 'Platform',
      lastName: 'Admin',
    },
  });

  const therapistUser = await prisma.user.upsert({
    where: {
      tenantId_email: { tenantId: tenant.id, email: 'therapist@demo.local' },
    },
    update: {},
    create: {
      tenantId: tenant.id,
      email: 'therapist@demo.local',
      passwordHash: therapistHash,
      role: 'THERAPIST',
      firstName: 'Sam',
      lastName: 'Therapist',
    },
  });

  const therapistProfile = await prisma.therapist.upsert({
    where: { userId: therapistUser.id },
    update: {
      isVerified: true,
      phiAccessApproved: true,
      onboardingStatus: 'APPROVED',
      therapyTypes: ['ABA', 'SPEECH'],
      npi: '1234567893',
      licenseNumber: 'SLP-123456',
      licenseState: 'NY',
      backgroundCheckStatus: 'PASSED',
      backgroundCheckCompletedAt: new Date('2025-01-01'),
      hipaaTrainingAttestedAt: new Date('2025-01-01'),
      confidentialityAgreementSignedAt: new Date('2025-01-01'),
      agencyApprovedAt: new Date('2025-01-01'),
    },
    create: {
      userId: therapistUser.id,
      tenantId: tenant.id,
      isVerified: true,
      phiAccessApproved: true,
      onboardingStatus: 'APPROVED',
      isAcceptingClients: true,
      therapyTypes: ['ABA', 'SPEECH'],
      npi: '1234567893',
      licenseNumber: 'SLP-123456',
      licenseState: 'NY',
      yearsExperience: 8,
      ratingAverage: 4.9,
      ratingCount: 42,
      latitude: 30.2672,
      longitude: -97.7431,
      city: 'Austin',
      state: 'TX',
      backgroundCheckStatus: 'PASSED',
      backgroundCheckCompletedAt: new Date('2025-01-01'),
      hipaaTrainingAttestedAt: new Date('2025-01-01'),
      confidentialityAgreementSignedAt: new Date('2025-01-01'),
      agencyApprovedAt: new Date('2025-01-01'),
    },
  });

  await prisma.providerMarketplaceProfile.upsert({
    where: { userId: therapistUser.id },
    update: {
      verifiedStatus: 'VERIFIED',
      confidentialityTermsAccepted: true,
      confidentialityAcceptedAt: new Date('2025-01-01'),
      serviceCategories: ['SPEECH', 'ABA', 'EVALUATION'],
      coverageZipCodes: ['11230', '11201', '10001', '78701'],
      languages: ['English', 'Spanish'],
    },
    create: {
      tenantId: tenant.id,
      userId: therapistUser.id,
      accountType: 'THERAPIST',
      therapistId: therapistProfile.id,
      legalName: 'Sam Therapist',
      displayName: 'Sam Therapist, SLP',
      licenseNumber: 'SLP-123456',
      npi: '1234567893',
      serviceCategories: ['SPEECH', 'ABA', 'EVALUATION'],
      coverageZipCodes: ['11230', '11201', '10001', '78701'],
      languages: ['English', 'Spanish'],
      availability: { weekdays: ['morning', 'afternoon'] },
      verifiedStatus: 'VERIFIED',
      confidentialityTermsAccepted: true,
      confidentialityAcceptedAt: new Date('2025-01-01'),
    },
  });

  await cleanupLegacyDemoClinicalData(
    tenant.id,
    therapistProfile.id,
    therapistUser.id,
  );

  const screeningTypes = [
    { therapyType: 'ABA' as const, name: 'ABA Intake', questions: [{ id: 'aggression', label: 'Aggression' }] },
    { therapyType: 'SPEECH' as const, name: 'Speech Intake', questions: [{ id: 'speech_delay', label: 'Speech delay' }] },
    { therapyType: 'OCCUPATIONAL' as const, name: 'OT Intake', questions: [{ id: 'fine_motor', label: 'Fine motor' }] },
    { therapyType: 'PHYSICAL' as const, name: 'PT Intake', questions: [{ id: 'mobility', label: 'Mobility' }] },
  ];

  for (const t of screeningTypes) {
    const existing = await prisma.screeningTemplate.findFirst({
      where: { tenantId: tenant.id, therapyType: t.therapyType, version: 1 },
    });
    if (!existing) {
      await prisma.screeningTemplate.create({
        data: {
          tenantId: tenant.id,
          name: t.name,
          therapyType: t.therapyType,
          version: 1,
          questions: t.questions,
          isActive: true,
        },
      });
    }
  }

  const eiQuestions = buildEarlyInterventionQuestionsJson();
  const eiExisting = await prisma.screeningTemplate.findFirst({
    where: {
      tenantId: tenant.id,
      therapyType: 'EARLY_INTERVENTION',
      name: EARLY_INTERVENTION_TEMPLATE_NAME,
    },
  });
  if (!eiExisting) {
    await prisma.screeningTemplate.create({
      data: {
        tenantId: tenant.id,
        name: EARLY_INTERVENTION_TEMPLATE_NAME,
        description:
          'Comprehensive parent screening for Early Intervention services (sections A–G).',
        therapyType: 'EARLY_INTERVENTION',
        version: 1,
        questions: JSON.parse(JSON.stringify(eiQuestions)) as Prisma.InputJsonValue,
        scoringRules: JSON.parse(
          JSON.stringify({ engine: 'early_intervention_v1' }),
        ) as Prisma.InputJsonValue,
        isActive: true,
      },
    });
  }

  const pendingHash = await bcrypt.hash('Pending123!', 10);
  const pendingUser = await prisma.user.upsert({
    where: {
      tenantId_email: { tenantId: tenant.id, email: 'pending@demo.local' },
    },
    update: {},
    create: {
      tenantId: tenant.id,
      email: 'pending@demo.local',
      passwordHash: pendingHash,
      role: 'THERAPIST',
      firstName: 'Pat',
      lastName: 'Pending',
    },
  });

  await prisma.therapist.upsert({
    where: { userId: pendingUser.id },
    update: {},
    create: {
      userId: pendingUser.id,
      tenantId: tenant.id,
      isVerified: false,
      licenseNumber: 'PEND-001',
      licenseState: 'TX',
    },
  });

  const agencyUser = await prisma.user.upsert({
    where: {
      tenantId_email: { tenantId: tenant.id, email: 'agency@demo.local' },
    },
    update: {},
    create: {
      tenantId: tenant.id,
      email: 'agency@demo.local',
      passwordHash: agencyHash,
      role: 'AGENCY_ADMIN',
      firstName: 'Alex',
      lastName: 'Agency',
    },
  });

  let agency = await prisma.agency.findFirst({
    where: { tenantId: tenant.id, name: 'Demo Therapy Agency' },
  });
  if (!agency) {
    agency = await prisma.agency.create({
      data: {
        tenantId: tenant.id,
        name: 'Demo Therapy Agency',
        city: 'Austin',
        state: 'TX',
        isVerified: true,
        onboardingComplete: true,
      },
    });
  } else {
    await prisma.agency.update({
      where: { id: agency.id },
      data: { onboardingComplete: true },
    });
  }

  await prisma.user.update({
    where: { id: agencyUser.id },
    data: { agencyId: agency.id },
  });

  await prisma.agencyTherapist.upsert({
    where: {
      agencyId_therapistId: {
        agencyId: agency.id,
        therapistId: therapistProfile.id,
      },
    },
    update: { status: 'ACTIVE' },
    create: {
      agencyId: agency.id,
      therapistId: therapistProfile.id,
      status: 'ACTIVE',
      joinedAt: new Date(),
    },
  });

  await prisma.providerBadge.upsert({
    where: {
      therapistId_type: {
        therapistId: therapistProfile.id,
        type: 'VERIFIED_LICENSE',
      },
    },
    update: {},
    create: {
      tenantId: tenant.id,
      therapistId: therapistProfile.id,
      type: 'VERIFIED_LICENSE',
      label: 'Texas BCBA',
    },
  });

  await prisma.providerBadge.upsert({
    where: {
      therapistId_type: {
        therapistId: therapistProfile.id,
        type: 'TOP_RATED',
      },
    },
    update: {},
    create: {
      tenantId: tenant.id,
      therapistId: therapistProfile.id,
      type: 'TOP_RATED',
      label: '4.9 parent rating',
    },
  });

  const periodStart = new Date();
  periodStart.setDate(1);
  const periodEnd = new Date();
  await prisma.payout.upsert({
    where: { id: '00000000-0000-4000-8000-000000000090' },
    update: {},
    create: {
      id: '00000000-0000-4000-8000-000000000090',
      tenantId: tenant.id,
      therapistId: therapistProfile.id,
      amount: 450,
      status: 'SUCCEEDED',
      periodStart,
      periodEnd,
      paidAt: new Date(),
      stripeTransferId: 'tr_seed_demo',
    },
  });

  await prisma.providerMarketplaceProfile.upsert({
    where: { userId: therapistUser.id },
    update: {
      confidentialityTermsAccepted: true,
      confidentialityAcceptedAt: new Date(),
      verifiedStatus: 'VERIFIED',
    },
    create: {
      tenantId: tenant.id,
      userId: therapistUser.id,
      accountType: 'THERAPIST',
      therapistId: therapistProfile.id,
      legalName: 'Sam Therapist',
      displayName: 'Sam Therapist, SLP',
      licenseNumber: 'SLP-123456',
      npi: '1234567893',
      serviceCategories: ['SPEECH', 'ABA', 'EVALUATION', 'OT'],
      coverageZipCodes: ['11230', '11201', '78701'],
      languages: ['English', 'Spanish'],
      availability: { weekdays: ['Mon', 'Wed', 'Fri'], times: 'afternoons' },
      confidentialityTermsAccepted: true,
      confidentialityAcceptedAt: new Date(),
      verifiedStatus: 'VERIFIED',
    },
  });

  const activeNotice = await seedActivePrivacyNotice(tenant.id);

  const parent1User = await seedEmptyParentAccount(
    tenant.id,
    'parent1@demo.local',
    parent1Hash,
    'Parent',
    'One',
    activeNotice.id,
  );

  const therapistMarketplaceProfile =
    await prisma.providerMarketplaceProfile.findUniqueOrThrow({
      where: { userId: therapistUser.id },
      select: { id: true },
    });
  await seedMarketplaceDemoData(
    tenant.id,
    parent1User.id,
    therapistMarketplaceProfile.id,
  );
  await repairMarketplaceZipCentroids();

  const scUser = await prisma.user.upsert({
    where: {
      tenantId_email: { tenantId: tenant.id, email: 'sc@demo.local' },
    },
    update: {
      passwordHash: scHash,
      role: 'SERVICE_COORDINATOR',
      agencyId: agency.id,
      isActive: true,
    },
    create: {
      tenantId: tenant.id,
      email: 'sc@demo.local',
      passwordHash: scHash,
      role: 'SERVICE_COORDINATOR',
      firstName: 'Sarah',
      lastName: 'Coordinator',
      agencyId: agency.id,
      createdById: agencyUser.id,
    },
  });

  await prisma.agencyRoster.upsert({
    where: {
      agencyId_userId: { agencyId: agency.id, userId: scUser.id },
    },
    update: {
      status: 'ACTIVE',
      removedAt: null,
      languages: ['English', 'Spanish'],
    },
    create: {
      agencyId: agency.id,
      userId: scUser.id,
      role: 'SERVICE_COORDINATOR',
      status: 'ACTIVE',
      languages: ['English', 'Spanish'],
      notes: 'Demo service coordinator for EI case management',
      addedById: agencyUser.id,
      addedAt: new Date(),
    },
  });

  await prisma.childServiceCoordinatorAssignment.upsert({
    where: {
      childId_serviceCoordinatorId_agencyId: {
        childId: DEMO_MARKETPLACE_SEED_IDS.child,
        serviceCoordinatorId: scUser.id,
        agencyId: agency.id,
      },
    },
    update: {
      status: 'ACTIVE',
      removedAt: null,
      assignedById: agencyUser.id,
    },
    create: {
      childId: DEMO_MARKETPLACE_SEED_IDS.child,
      serviceCoordinatorId: scUser.id,
      agencyId: agency.id,
      assignedById: agencyUser.id,
      status: 'ACTIVE',
    },
  });

  const parent1Record = await prisma.parent.findUniqueOrThrow({
    where: { userId: parent1User.id },
  });
  await seedDemoEiEligibility(
    tenant.id,
    parent1Record.id,
    DEMO_MARKETPLACE_SEED_IDS.child,
  );

  const billingUser = await prisma.user.upsert({
    where: {
      tenantId_email: { tenantId: tenant.id, email: 'billing@demo.local' },
    },
    update: {
      agencyId: agency.id,
      isActive: true,
    },
    create: {
      tenantId: tenant.id,
      email: 'billing@demo.local',
      passwordHash: billingHash,
      role: 'BILLING_STAFF',
      firstName: 'Blake',
      lastName: 'Billing',
      agencyId: agency.id,
      createdById: agencyUser.id,
    },
  });

  await seedEiBillingDemo(
    prisma,
    tenant.id,
    agency.id,
    therapistProfile.id,
    DEMO_MARKETPLACE_SEED_IDS.child,
    billingUser.id,
  );

  await seedDemoJobOpportunity(
    tenant.id,
    agency.id,
    DEMO_MARKETPLACE_SEED_IDS.child,
    agencyUser.id,
  );

  await seedEmptyParentAccount(
    tenant.id,
    'parent2@demo.local',
    parent2Hash,
    'Parent',
    'Two',
    activeNotice.id,
  );

  await prisma.hipaaConsent.upsert({
    where: { id: '00000000-0000-4000-8000-000000000061' },
    update: {},
    create: {
      id: '00000000-0000-4000-8000-000000000061',
      tenantId: tenant.id,
      userId: therapistUser.id,
      consentType: 'HIPAA_PRIVACY',
      version: '1.0',
      granted: true,
    },
  });

  await prisma.hipaaConsent.upsert({
    where: { id: '00000000-0000-4000-8000-000000000062' },
    update: {},
    create: {
      id: '00000000-0000-4000-8000-000000000062',
      tenantId: tenant.id,
      userId: agencyUser.id,
      consentType: 'HIPAA_PRIVACY',
      version: '1.0',
      granted: true,
    },
  });

  await prisma.hipaaConsent.upsert({
    where: { id: '00000000-0000-4000-8000-000000000063' },
    update: {},
    create: {
      id: '00000000-0000-4000-8000-000000000063',
      tenantId: tenant.id,
      userId: scUser.id,
      consentType: 'HIPAA_PRIVACY',
      version: '1.0',
      granted: true,
    },
  });

  await prisma.hipaaConsent.upsert({
    where: { id: '00000000-0000-4000-8000-000000000064' },
    update: {},
    create: {
      id: '00000000-0000-4000-8000-000000000064',
      tenantId: tenant.id,
      userId: billingUser.id,
      consentType: 'HIPAA_PRIVACY',
      version: '1.0',
      granted: true,
    },
  });

  // Demo clinical-role accounts must satisfy onboarding gates used in CI smoke tests.
  await seedNoticeAcknowledgment(tenant.id, therapistUser.id, activeNotice.id);
  await seedNoticeAcknowledgment(tenant.id, agencyUser.id, activeNotice.id);
  await seedNoticeAcknowledgment(tenant.id, scUser.id, activeNotice.id);
  await seedNoticeAcknowledgment(tenant.id, billingUser.id, activeNotice.id);
  await seedDemoOnboarding(therapistUser.id);
  await seedDemoOnboarding(agencyUser.id);
  await seedDemoOnboarding(scUser.id);
  await seedDemoOnboarding(billingUser.id);
  await seedSmokeTrustedDevices(scUser.id);

  const legalDocs: Array<{
    documentType:
      | 'PRIVACY_POLICY'
      | 'TERMS_OF_USE'
      | 'HIPAA_NOTICE'
      | 'DATA_RETENTION_POLICY'
      | 'BREACH_NOTIFICATION_POLICY'
      | 'CONTACT_COMPLIANCE_OFFICER';
    title: string;
    content: string;
  }> = [
    {
      documentType: 'PRIVACY_POLICY',
      title: 'Privacy Policy',
      content:
        'This Privacy Policy describes how BloomOra collects, uses, and protects your information.',
    },
    {
      documentType: 'TERMS_OF_USE',
      title: 'Terms of Use',
      content: 'By using BloomOra you agree to these Terms of Use.',
    },
    {
      documentType: 'HIPAA_NOTICE',
      title: 'HIPAA Notice of Privacy Practices',
      content:
        'This Notice describes how medical information about you may be used and disclosed.',
    },
    {
      documentType: 'DATA_RETENTION_POLICY',
      title: 'Data Retention Policy',
      content:
        'Clinical records are retained for seven (7) years; billing records for six (6) years.',
    },
    {
      documentType: 'BREACH_NOTIFICATION_POLICY',
      title: 'Breach Notification Policy',
      content:
        'Affected individuals and HHS will be notified as required by applicable breach notification rules.',
    },
    {
      documentType: 'CONTACT_COMPLIANCE_OFFICER',
      title: 'Contact the Compliance Officer',
      content:
        'Report privacy concerns to privacy@bloomora.health or via the in-app Privacy Center.',
    },
  ];
  for (const doc of legalDocs) {
    const existing = await prisma.complianceDocument.findFirst({
      where: {
        tenantId: tenant.id,
        documentType: doc.documentType,
        isActive: true,
      },
    });
    if (existing) continue;
    await prisma.complianceDocument.create({
      data: {
        tenantId: tenant.id,
        documentType: doc.documentType,
        version: '1.0',
        title: doc.title,
        content: doc.content,
        effectiveDate: new Date('2025-06-01'),
        isActive: true,
        publishedAt: new Date(),
      },
    });
  }

  console.log('Seed complete.');
  console.log('  Admin:     admin@abaconnect.local / Admin123!');
  console.log('  Parent 1:  parent1@demo.local / Parent1Demo!  (MFA: 000000)');
  console.log('  Parent 2:  parent2@demo.local / Parent2Demo!  (MFA: 000000)');
  console.log('  Therapist: therapist@demo.local / Therapist123!');
  console.log('  Agency:    agency@demo.local / Agency123!');
  console.log('  SC:        sc@demo.local / SC123!  (MFA: 000000)');
  console.log('  Billing:   billing@demo.local / Billing123!  (MFA: 000000)');
  console.log('  Pending:   pending@demo.local / Pending123! (unverified)');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
    await pool.end();
  });
