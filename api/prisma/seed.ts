import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';
import { PrismaClient } from '../generated/prisma/client';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

async function main() {
  const tenant = await prisma.tenant.upsert({
    where: { slug: 'abaconnect' },
    update: {},
    create: {
      name: 'ABAConnect Platform',
      slug: 'abaconnect',
      settings: { branding: { primaryColor: '#1565C0' } },
      isActive: true,
    },
  });

  const bcrypt = await import('bcrypt');
  const adminHash = await bcrypt.hash('Admin123!', 10);
  const parentHash = await bcrypt.hash('Parent123!', 10);
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
    update: { isVerified: true, therapyTypes: ['ABA', 'SPEECH'] },
    create: {
      userId: therapistUser.id,
      tenantId: tenant.id,
      isVerified: true,
      isAcceptingClients: true,
      therapyTypes: ['ABA', 'SPEECH'],
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

  console.log('Seed complete.');
  console.log('  Admin:     admin@abaconnect.local / Admin123!');
  console.log('  Parent:    parent@demo.local / Parent123!');
  console.log('  Therapist: therapist@demo.local / Therapist123!');
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
