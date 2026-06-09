import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';
import { Prisma, PrismaClient } from '../generated/prisma/client';
import {
  buildEarlyInterventionQuestionsJson,
  EARLY_INTERVENTION_TEMPLATE_NAME,
} from '../src/screenings/early-intervention-template';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

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
  const parentHash = await bcrypt.hash('Parent123!', 10);
  const agencyHash = await bcrypt.hash('Agency123!', 10);
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

  const parentUser = await prisma.user.upsert({
    where: {
      tenantId_email: { tenantId: tenant.id, email: 'parent@demo.local' },
    },
    update: {},
    create: {
      tenantId: tenant.id,
      email: 'parent@demo.local',
      passwordHash: parentHash,
      role: 'PARENT',
      firstName: 'Jamie',
      lastName: 'Parent',
    },
  });

  const parentProfile = await prisma.parent.upsert({
    where: { userId: parentUser.id },
    update: {},
    create: {
      userId: parentUser.id,
      tenantId: tenant.id,
      city: 'Austin',
      state: 'TX',
      zipCode: '78701',
    },
  });

  await prisma.child.upsert({
    where: { id: '00000000-0000-4000-8000-000000000001' },
    update: {},
    create: {
      id: '00000000-0000-4000-8000-000000000001',
      parentId: parentProfile.id,
      tenantId: tenant.id,
      firstName: 'Alex',
      lastName: 'Parent',
      dateOfBirth: new Date('2018-06-15'),
      gender: 'non-binary',
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
      therapyTypes: ['ABA', 'SPEECH'],
      npi: '1234567893',
      licenseNumber: 'SLP-123456',
      licenseState: 'NY',
    },
    create: {
      userId: therapistUser.id,
      tenantId: tenant.id,
      isVerified: true,
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
    },
  });

  const start = new Date();
  start.setDate(start.getDate() + 2);
  const end = new Date(start);
  end.setHours(end.getHours() + 1);

  await prisma.appointment.upsert({
    where: { id: '00000000-0000-4000-8000-000000000010' },
    update: {},
    create: {
      id: '00000000-0000-4000-8000-000000000010',
      tenantId: tenant.id,
      parentId: parentProfile.id,
      childId: '00000000-0000-4000-8000-000000000001',
      therapistId: therapistProfile.id,
      therapyType: 'ABA',
      status: 'CONFIRMED',
      scheduledStart: start,
      scheduledEnd: end,
    },
  });

  const pendingStart = new Date();
  pendingStart.setDate(pendingStart.getDate() + 5);
  const pendingEnd = new Date(pendingStart);
  pendingEnd.setHours(pendingEnd.getHours() + 1);

  await prisma.appointment.upsert({
    where: { id: '00000000-0000-4000-8000-000000000011' },
    update: { status: 'REQUESTED' },
    create: {
      id: '00000000-0000-4000-8000-000000000011',
      tenantId: tenant.id,
      parentId: parentProfile.id,
      childId: '00000000-0000-4000-8000-000000000001',
      therapistId: therapistProfile.id,
      therapyType: 'SPEECH',
      status: 'REQUESTED',
      scheduledStart: pendingStart,
      scheduledEnd: pendingEnd,
      notes: 'Demo pending confirmation',
    },
  });

  const threadId = '00000000-0000-4000-8000-000000000020';
  await prisma.messageThread.upsert({
    where: { id: threadId },
    update: {},
    create: {
      id: threadId,
      tenantId: tenant.id,
      subject: 'Care team — Sam Therapist',
      participants: {
        create: [
          { userId: parentUser.id },
          { userId: therapistUser.id },
        ],
      },
    },
  });

  const existingMessages = await prisma.message.count({
    where: { threadId },
  });
  if (existingMessages === 0) {
    await prisma.message.createMany({
      data: [
        {
          threadId,
          senderId: therapistUser.id,
          body: 'Hi Jamie! Looking forward to Alex\'s first session.',
        },
        {
          threadId,
          senderId: parentUser.id,
          body: 'Thanks Sam! We are excited to get started.',
        },
      ],
    });
  }

  await prisma.payment.upsert({
    where: { id: '00000000-0000-4000-8000-000000000030' },
    update: {},
    create: {
      id: '00000000-0000-4000-8000-000000000030',
      tenantId: tenant.id,
      parentId: parentProfile.id,
      amount: 150,
      currency: 'USD',
      status: 'SUCCEEDED',
      description: 'ABA session — May 2026',
      paidAt: new Date(),
      stripePaymentIntentId: 'pi_seed_succeeded',
    },
  });

  await prisma.payment.upsert({
    where: { id: '00000000-0000-4000-8000-000000000031' },
    update: {},
    create: {
      id: '00000000-0000-4000-8000-000000000031',
      tenantId: tenant.id,
      parentId: parentProfile.id,
      amount: 175,
      currency: 'USD',
      status: 'PENDING',
      description: 'Upcoming ABA session',
      stripePaymentIntentId: 'pi_seed_pending',
    },
  });

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

  await prisma.user.upsert({
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
      },
    });
  }

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

  await prisma.telehealthSession.upsert({
    where: { appointmentId: '00000000-0000-4000-8000-000000000010' },
    update: {},
    create: {
      tenantId: tenant.id,
      appointmentId: '00000000-0000-4000-8000-000000000010',
      roomId: 'demo_room_aba_001',
      providerUrl: 'https://meet.abaconnect.local/demo_room_aba_001?role=provider',
      patientUrl: 'https://meet.abaconnect.local/demo_room_aba_001?role=patient',
    },
  });

  await prisma.session.upsert({
    where: { appointmentId: '00000000-0000-4000-8000-000000000010' },
    update: {
      status: 'COMPLETED',
      checkInAt: new Date(Date.now() - 2 * 60 * 60 * 1000),
      checkOutAt: new Date(Date.now() - 60 * 60 * 1000),
      durationMinutes: 60,
      evvVerified: true,
    },
    create: {
      appointmentId: '00000000-0000-4000-8000-000000000010',
      tenantId: tenant.id,
      childId: '00000000-0000-4000-8000-000000000001',
      therapistId: therapistProfile.id,
      status: 'COMPLETED',
      checkInAt: new Date(Date.now() - 2 * 60 * 60 * 1000),
      checkOutAt: new Date(Date.now() - 60 * 60 * 1000),
      durationMinutes: 60,
      evvVerified: true,
    },
  });

  const notifCount = await prisma.notification.count({
    where: { userId: parentUser.id },
  });
  if (notifCount === 0) {
    await prisma.notification.createMany({
      data: [
        {
          tenantId: tenant.id,
          userId: parentUser.id,
          title: 'Appointment confirmed',
          body: 'Your ABA session is confirmed for 2 days from now.',
        },
        {
          tenantId: tenant.id,
          userId: parentUser.id,
          title: 'Complete screening',
          body: 'Please finish intake forms before the first visit.',
        },
      ],
    });
  }

  await prisma.document.upsert({
    where: { id: '00000000-0000-4000-8000-000000000040' },
    update: {},
    create: {
      id: '00000000-0000-4000-8000-000000000040',
      tenantId: tenant.id,
      childId: '00000000-0000-4000-8000-000000000001',
      type: 'INSURANCE_CARD',
      title: 'Insurance card — Alex',
      fileName: 'insurance_card.pdf',
      mimeType: 'application/pdf',
      fileSize: 245000,
      storageKey: `tenants/${tenant.id}/docs/insurance_card.pdf`,
    },
  });

  await prisma.insuranceClaim.upsert({
    where: { id: '00000000-0000-4000-8000-000000000050' },
    update: {},
    create: {
      id: '00000000-0000-4000-8000-000000000050',
      tenantId: tenant.id,
      parentId: parentProfile.id,
      childId: '00000000-0000-4000-8000-000000000001',
      payerName: 'Demo Health Plan',
      billedAmount: 200,
      serviceDate: new Date(),
      status: 'PENDING',
    },
  });

  await prisma.treatmentPlan.upsert({
    where: { id: '00000000-0000-4000-8000-000000000080' },
    update: {},
    create: {
      id: '00000000-0000-4000-8000-000000000080',
      tenantId: tenant.id,
      childId: '00000000-0000-4000-8000-000000000001',
      therapistId: therapistProfile.id,
      authorId: therapistUser.id,
      therapyType: 'ABA',
      title: 'ABA Goals — Q2 2026',
      goals: [
        {
          id: 'communication',
          label: 'Increase functional communication',
          status: 'done',
        },
        {
          id: 'behavior',
          label: 'Reduce challenging behaviors',
          status: 'in_progress',
        },
        {
          id: 'social',
          label: 'Initiate peer interactions',
          status: 'active',
        },
      ],
      startDate: new Date(),
      isActive: true,
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

  await prisma.dispute.upsert({
    where: { id: '00000000-0000-4000-8000-000000000091' },
    update: {},
    create: {
      id: '00000000-0000-4000-8000-000000000091',
      tenantId: tenant.id,
      paymentId: '00000000-0000-4000-8000-000000000031',
      parentId: parentProfile.id,
      openerId: parentUser.id,
      reason: 'Demo: charged twice for same session',
      amount: 175,
      status: 'OPEN',
    },
  });

  await prisma.complaint.upsert({
    where: { id: '00000000-0000-4000-8000-000000000070' },
    update: {},
    create: {
      id: '00000000-0000-4000-8000-000000000070',
      tenantId: tenant.id,
      reporterId: parentUser.id,
      parentId: parentProfile.id,
      therapistId: therapistProfile.id,
      category: 'SERVICE',
      subject: 'Demo scheduling question',
      description: 'Need to confirm first session time window.',
      status: 'OPEN',
    },
  });

  await prisma.hipaaConsent.upsert({
    where: { id: '00000000-0000-4000-8000-000000000060' },
    update: {},
    create: {
      id: '00000000-0000-4000-8000-000000000060',
      tenantId: tenant.id,
      userId: parentUser.id,
      consentType: 'HIPAA_PRIVACY',
      version: '1.0',
      granted: true,
    },
  });

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

  console.log('Seed complete.');
  console.log('  Admin:     admin@abaconnect.local / Admin123!');
  console.log('  Parent:    parent@demo.local / Parent123!');
  console.log('  Therapist: therapist@demo.local / Therapist123!');
  console.log('  Agency:    agency@demo.local / Agency123!');
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
