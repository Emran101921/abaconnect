import {
  BadRequestException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.service';
import { CallsService } from '../calls/calls.service';
import { DocumentsService } from '../documents/documents.service';
import { JobOpportunitiesService } from './job-opportunities.service';

describe('JobOpportunitiesService job interviews', () => {
  let service: JobOpportunitiesService;

  const notifications = {
    createForUser: jest.fn(),
  };

  const calls = {
    joinJobInterviewCall: jest.fn(),
  };

  const documents = {
    openFileStreamWithAudit: jest.fn(),
  };

  const tx = {
    jobInterview: {
      create: jest.fn(),
      update: jest.fn(),
    },
    jobOpportunityApplication: { update: jest.fn() },
    applicationStatusHistory: { create: jest.fn() },
  };

  const prisma = {
    user: { findFirst: jest.fn(), findMany: jest.fn() },
    therapist: { findFirst: jest.fn() },
    document: { findMany: jest.fn() },
    therapistCredentialWallet: { upsert: jest.fn() },
    jobOpportunityApplication: {
      findFirst: jest.fn(),
      update: jest.fn(),
      findMany: jest.fn(),
    },
    jobInterview: {
      findFirst: jest.fn(),
      update: jest.fn(),
      findMany: jest.fn(),
    },
    jobOpportunity: { update: jest.fn() },
    childServiceNeed: { update: jest.fn() },
    agencyTherapist: {
      upsert: jest.fn(),
      findUnique: jest.fn(),
      findFirst: jest.fn(),
      findMany: jest.fn(),
      update: jest.fn(),
    },
    appointment: { create: jest.fn() },
    marketplaceAuditLog: { create: jest.fn() },
    notification: { findMany: jest.fn() },
    $transaction: jest.fn(async (fn: (client: typeof tx) => unknown) => fn(tx)),
  };

  const agencyAdmin = {
    id: 'admin-1',
    tenantId: 't1',
    role: 'AGENCY_ADMIN',
    agencyId: 'agency-1',
    agency: { id: 'agency-1', tenantId: 't1', name: 'Agency A' },
  };

  const futureDate = new Date(Date.now() + 24 * 60 * 60 * 1000);

  beforeEach(async () => {
    jest.clearAllMocks();
    notifications.createForUser.mockResolvedValue({});
    prisma.marketplaceAuditLog.create.mockResolvedValue({});
    prisma.user.findFirst.mockResolvedValue(agencyAdmin);

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        JobOpportunitiesService,
        { provide: PrismaService, useValue: prisma },
        { provide: NotificationsService, useValue: notifications },
        { provide: CallsService, useValue: calls },
        { provide: DocumentsService, useValue: documents },
      ],
    }).compile();
    service = module.get(JobOpportunitiesService);
  });

  it('schedules interview, updates application status, and notifies therapist', async () => {
    prisma.jobOpportunityApplication.findFirst.mockResolvedValue({
      id: 'app-1',
      status: 'UNDER_REVIEW',
      jobOpportunityId: 'job-1',
      therapist: {
        userId: 'therapist-user-1',
        user: { userId: 'therapist-user-1' },
      },
      jobOpportunity: { title: 'OT role' },
      interview: null,
    });
    tx.jobInterview.create.mockResolvedValue({
      id: 'interview-1',
      applicationId: 'app-1',
      scheduledAt: futureDate,
      therapist: { userId: 'therapist-user-1' },
      application: {
        jobOpportunityId: 'job-1',
        jobOpportunity: { title: 'OT role' },
        therapist: { user: { userId: 'therapist-user-1' } },
      },
    });
    tx.jobOpportunityApplication.update.mockResolvedValue({});
    tx.applicationStatusHistory.create.mockResolvedValue({});

    const result = await service.scheduleJobInterview('admin-1', 't1', {
      applicationId: 'app-1',
      scheduledAt: futureDate,
      durationMinutes: 30,
      recordingRequested: true,
      agencyRecordingConsent: true,
    });

    expect(result.id).toBe('interview-1');
    expect(tx.jobInterview.create).toHaveBeenCalled();
    expect(tx.jobOpportunityApplication.update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: { status: 'INTERVIEW_REQUESTED' },
      }),
    );
    expect(notifications.createForUser).toHaveBeenCalledWith(
      'therapist-user-1',
      expect.objectContaining({
        data: expect.objectContaining({
          type: 'JOB_INTERVIEW_SCHEDULED',
          interviewId: 'interview-1',
        }),
      }),
    );
  });

  it('reschedules a cancelled interview instead of creating a duplicate row', async () => {
    prisma.jobOpportunityApplication.findFirst.mockResolvedValue({
      id: 'app-1',
      status: 'INTERVIEW_REQUESTED',
      jobOpportunityId: 'job-1',
      therapist: {
        userId: 'therapist-user-1',
        user: { userId: 'therapist-user-1' },
      },
      jobOpportunity: { title: 'OT role' },
      interview: { id: 'interview-1', status: 'CANCELLED' },
    });
    tx.jobInterview.update.mockResolvedValue({
      id: 'interview-1',
      applicationId: 'app-1',
      scheduledAt: futureDate,
      application: {
        jobOpportunityId: 'job-1',
        jobOpportunity: { title: 'OT role' },
        therapist: { user: { userId: 'therapist-user-1' } },
      },
    });

    const result = await service.scheduleJobInterview('admin-1', 't1', {
      applicationId: 'app-1',
      scheduledAt: futureDate,
    });

    expect(result.id).toBe('interview-1');
    expect(tx.jobInterview.update).toHaveBeenCalled();
    expect(tx.jobInterview.create).not.toHaveBeenCalled();
  });

  it('rejects scheduling in the past', async () => {
    prisma.jobOpportunityApplication.findFirst.mockResolvedValue({
      id: 'app-1',
      status: 'UNDER_REVIEW',
      jobOpportunityId: 'job-1',
      therapist: {
        userId: 'therapist-user-1',
        user: { userId: 'therapist-user-1' },
      },
      jobOpportunity: { title: 'OT role' },
      interview: null,
    });

    await expect(
      service.scheduleJobInterview('admin-1', 't1', {
        applicationId: 'app-1',
        scheduledAt: new Date(Date.now() - 60_000),
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('cancels an active interview and notifies therapist', async () => {
    prisma.jobInterview.findFirst.mockResolvedValue({
      id: 'interview-1',
      status: 'SCHEDULED',
      therapistUserId: 'therapist-user-1',
      notes: null,
      application: {
        jobOpportunityId: 'job-1',
        jobOpportunity: { title: 'OT role' },
        therapist: { user: { userId: 'therapist-user-1' } },
      },
      callSession: null,
    });
    prisma.jobInterview.update.mockResolvedValue({
      id: 'interview-1',
      status: 'CANCELLED',
      application: {
        jobOpportunityId: 'job-1',
        jobOpportunity: { title: 'OT role' },
        therapist: { user: { userId: 'therapist-user-1' } },
      },
      agency: { name: 'Agency A' },
      scheduledBy: {},
      therapistUser: {},
      callSession: null,
    });

    const result = await service.cancelJobInterview(
      'admin-1',
      't1',
      'interview-1',
      'Applicant unavailable',
    );

    expect(result.status).toBe('CANCELLED');
    expect(notifications.createForUser).toHaveBeenCalledWith(
      'therapist-user-1',
      expect.objectContaining({
        data: expect.objectContaining({ type: 'JOB_INTERVIEW_CANCELLED' }),
      }),
    );
  });

  it('rejects cancelling a completed interview', async () => {
    prisma.jobInterview.findFirst.mockResolvedValue({
      id: 'interview-1',
      status: 'COMPLETED',
      application: { jobOpportunity: { title: 'OT role' } },
      callSession: null,
    });

    await expect(
      service.cancelJobInterview('admin-1', 't1', 'interview-1'),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('rejects cancelling unknown interview', async () => {
    prisma.jobInterview.findFirst.mockResolvedValue(null);

    await expect(
      service.cancelJobInterview('admin-1', 't1', 'missing'),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('requests credentials and moves application to CREDENTIAL_REVIEW', async () => {
    prisma.user.findFirst.mockResolvedValue(agencyAdmin);
    prisma.jobOpportunityApplication.findFirst.mockResolvedValue({
      id: 'app-1',
      status: 'INTERVIEW_REQUESTED',
      jobOpportunityId: 'job-1',
      therapist: {
        userId: 'therapist-user-1',
        user: { userId: 'therapist-user-1' },
      },
      jobOpportunity: { title: 'OT role' },
    });
    prisma.$transaction.mockImplementation(
      async (fn: (client: typeof tx) => unknown) => fn(tx),
    );
    tx.jobOpportunityApplication.update.mockResolvedValue({
      id: 'app-1',
      status: 'CREDENTIAL_REVIEW',
      jobOpportunityId: 'job-1',
      therapist: {
        userId: 'therapist-user-1',
        user: { userId: 'therapist-user-1' },
      },
      jobOpportunity: { title: 'OT role' },
    });
    tx.applicationStatusHistory.create.mockResolvedValue({});

    const result = await service.requestDocuments(
      'admin-1',
      't1',
      'app-1',
      'Please upload license',
    );

    expect(result.status).toBe('CREDENTIAL_REVIEW');
    expect(prisma.marketplaceAuditLog.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          eventType: 'DOCUMENTS_REQUESTED',
        }),
      }),
    );
  });

  it('updates interview notes for agency admin', async () => {
    prisma.user.findFirst.mockResolvedValue(agencyAdmin);
    prisma.jobInterview.findFirst.mockResolvedValue({
      id: 'interview-1',
      agencyId: 'agency-1',
    });
    prisma.jobInterview.update.mockResolvedValue({
      id: 'interview-1',
      applicationId: 'app-1',
      scheduledAt: futureDate,
      durationMinutes: 30,
      status: 'COMPLETED',
      recordingRequested: false,
      agencyRecordingConsent: false,
      therapistRecordingConsent: false,
      notes: 'Strong candidate',
      application: {
        jobOpportunity: { id: 'job-1', title: 'OT role' },
        therapist: { user: { firstName: 'Sam', lastName: 'Therapist' } },
      },
      agency: { name: 'Agency A' },
      callSession: null,
    });

    const result = await service.updateJobInterviewNotes(
      'admin-1',
      't1',
      'interview-1',
      'Strong candidate',
    );

    expect(result.notes).toBe('Strong candidate');
  });

  it('refreshes application credentials from therapist documents', async () => {
    prisma.therapist.findFirst.mockResolvedValue({
      id: 'therapist-1',
      tenantId: 't1',
      userId: 'therapist-user-1',
    });
    prisma.document.findMany.mockResolvedValue([
      {
        id: 'doc-1',
        title: 'NY License',
        fileName: 'license.pdf',
        type: 'LICENSE',
        uploadedAt: new Date('2026-01-01'),
      },
    ]);
    prisma.therapistCredentialWallet.upsert.mockResolvedValue({});
    prisma.jobOpportunityApplication.findFirst.mockResolvedValue({
      id: 'app-1',
      status: 'CREDENTIAL_REVIEW',
      jobOpportunityId: 'job-1',
      therapistId: 'therapist-1',
      therapist: {
        userId: 'therapist-user-1',
        user: { firstName: 'Sam', lastName: 'Therapist' },
      },
      jobOpportunity: { title: 'OT role', agencyId: 'agency-1' },
    });
    prisma.jobOpportunityApplication.update.mockResolvedValue({
      id: 'app-1',
      status: 'CREDENTIAL_REVIEW',
      jobOpportunityId: 'job-1',
      credentialSnapshot: [{ id: 'doc-1', title: 'NY License' }],
      therapist: {
        userId: 'therapist-user-1',
        user: { firstName: 'Sam', lastName: 'Therapist' },
      },
      jobOpportunity: { title: 'OT role', agencyId: 'agency-1' },
      createdAt: new Date(),
      updatedAt: new Date(),
    });
    prisma.user.findMany.mockResolvedValue([{ id: 'admin-1' }]);

    const result = await service.refreshJobApplicationCredentials(
      'therapist-user-1',
      't1',
      'app-1',
    );

    expect(result.id).toBe('app-1');
    expect(notifications.createForUser).toHaveBeenCalled();
  });

  it('lets therapist accept a job offer', async () => {
    prisma.therapist.findFirst.mockResolvedValue({
      id: 'therapist-1',
      tenantId: 't1',
      userId: 'therapist-user-1',
    });
    prisma.jobOpportunityApplication.findFirst.mockResolvedValue({
      id: 'app-1',
      status: 'OFFER_SENT',
      jobOpportunityId: 'job-1',
      therapist: {
        userId: 'therapist-user-1',
        user: { firstName: 'Sam', lastName: 'Therapist' },
      },
      jobOpportunity: { title: 'OT role', agencyId: 'agency-1' },
    });
    tx.jobOpportunityApplication.update.mockResolvedValue({
      id: 'app-1',
      status: 'APPROVED',
      jobOpportunityId: 'job-1',
      therapist: {
        userId: 'therapist-user-1',
        user: { firstName: 'Sam', lastName: 'Therapist' },
      },
      jobOpportunity: { title: 'OT role', agencyId: 'agency-1' },
      createdAt: new Date(),
      updatedAt: new Date(),
    });
    tx.applicationStatusHistory.create.mockResolvedValue({});
    prisma.user.findMany.mockResolvedValue([{ id: 'admin-1' }]);

    const result = await service.respondToJobOffer(
      'therapist-user-1',
      't1',
      'app-1',
      true,
    );

    expect(result.status).toBe('APPROVED');
  });

  it('approves submitted credentials during credential review', async () => {
    prisma.jobOpportunityApplication.findFirst.mockResolvedValue({
      id: 'app-1',
      status: 'CREDENTIAL_REVIEW',
      jobOpportunityId: 'job-1',
      therapist: {
        userId: 'therapist-user-1',
        user: { firstName: 'Sam', lastName: 'Therapist' },
      },
      jobOpportunity: { title: 'OT role', agencyId: 'agency-1' },
    });
    tx.jobOpportunityApplication.update.mockResolvedValue({
      id: 'app-1',
      status: 'UNDER_REVIEW',
      jobOpportunityId: 'job-1',
      therapist: {
        userId: 'therapist-user-1',
        user: { firstName: 'Sam', lastName: 'Therapist' },
      },
      jobOpportunity: { title: 'OT role', agencyId: 'agency-1' },
      createdAt: new Date(),
      updatedAt: new Date(),
    });
    tx.applicationStatusHistory.create.mockResolvedValue({});

    const result = await service.approveApplicationCredentials(
      'admin-1',
      't1',
      'app-1',
      'Credentials verified',
    );

    expect(result.status).toBe('UNDER_REVIEW');
    expect(tx.applicationStatusHistory.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          fromStatus: 'CREDENTIAL_REVIEW',
          toStatus: 'UNDER_REVIEW',
        }),
      }),
    );
  });

  it('sends day-before interview reminders when listing therapist interviews', async () => {
    const scheduledAt = new Date(Date.now() + 12 * 60 * 60 * 1000);
    prisma.therapist.findFirst.mockResolvedValue({
      id: 'therapist-1',
      tenantId: 't1',
      userId: 'therapist-user-1',
    });
    prisma.jobInterview.findMany.mockResolvedValue([
      {
        id: 'int-1',
        scheduledAt,
        status: 'CONFIRMED',
        therapistUserId: 'therapist-user-1',
        scheduledByUserId: 'admin-1',
        application: {
          jobOpportunityId: 'job-1',
          jobOpportunity: { title: 'OT role' },
          therapist: { user: { firstName: 'Sam', lastName: 'Therapist' } },
        },
        agency: { name: 'Agency A' },
        scheduledBy: {},
        callSession: null,
      },
    ]);
    prisma.notification.findMany.mockResolvedValue([]);

    await service.listTherapistJobInterviews('therapist-user-1', 't1');

    expect(notifications.createForUser).toHaveBeenCalledTimes(2);
    expect(notifications.createForUser).toHaveBeenCalledWith(
      'therapist-user-1',
      expect.objectContaining({
        data: expect.objectContaining({ type: 'JOB_INTERVIEW_REMINDER' }),
      }),
    );
  });

  it('skips duplicate day-before interview reminders', async () => {
    const scheduledAt = new Date(Date.now() + 12 * 60 * 60 * 1000);
    prisma.therapist.findFirst.mockResolvedValue({
      id: 'therapist-1',
      tenantId: 't1',
      userId: 'therapist-user-1',
    });
    prisma.jobInterview.findMany.mockResolvedValue([
      {
        id: 'int-1',
        scheduledAt,
        status: 'CONFIRMED',
        therapistUserId: 'therapist-user-1',
        scheduledByUserId: 'admin-1',
        application: {
          jobOpportunityId: 'job-1',
          jobOpportunity: { title: 'OT role' },
          therapist: { user: { firstName: 'Sam', lastName: 'Therapist' } },
        },
        agency: { name: 'Agency A' },
        scheduledBy: {},
        callSession: null,
      },
    ]);
    prisma.notification.findMany.mockResolvedValue([
      {
        data: { type: 'JOB_INTERVIEW_REMINDER', interviewId: 'int-1' },
      },
    ]);

    await service.listTherapistJobInterviews('therapist-user-1', 't1');

    expect(notifications.createForUser).not.toHaveBeenCalled();
  });

  it('sends a structured job offer with compensation and start date', async () => {
    prisma.jobOpportunityApplication.findFirst.mockResolvedValue({
      id: 'app-1',
      status: 'UNDER_REVIEW',
      jobOpportunityId: 'job-1',
      therapist: {
        userId: 'therapist-user-1',
        user: { firstName: 'Sam', lastName: 'Therapist' },
      },
      jobOpportunity: { title: 'OT role', agencyId: 'agency-1' },
      interview: { status: 'COMPLETED' },
    });
    tx.jobOpportunityApplication.update.mockResolvedValue({
      id: 'app-1',
      status: 'OFFER_SENT',
      jobOpportunityId: 'job-1',
      therapist: {
        userId: 'therapist-user-1',
        user: { firstName: 'Sam', lastName: 'Therapist' },
      },
      jobOpportunity: { title: 'OT role', agencyId: 'agency-1' },
      statusHistory: [],
      createdAt: new Date(),
      updatedAt: new Date(),
    });
    tx.applicationStatusHistory.create.mockResolvedValue({});

    const result = await service.sendJobOffer('admin-1', 't1', {
      applicationId: 'app-1',
      compensationRate: '$65/hr',
      startDate: new Date('2026-07-01'),
      message: 'Welcome aboard',
    });

    expect(result.status).toBe('OFFER_SENT');
    expect(tx.applicationStatusHistory.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          toStatus: 'OFFER_SENT',
          note: expect.stringContaining('$65/hr'),
        }),
      }),
    );
    expect(notifications.createForUser).toHaveBeenCalledWith(
      'therapist-user-1',
      expect.objectContaining({
        data: expect.objectContaining({ type: 'JOB_OFFER_SENT' }),
      }),
    );
  });

  it('summarizes agency hiring pipeline pending actions', async () => {
    prisma.jobOpportunityApplication.findMany.mockResolvedValue([
      { status: 'NEW_APPLICANT', credentialSnapshot: {} },
      {
        status: 'CREDENTIAL_REVIEW',
        credentialSnapshot: [{ id: 'd1', title: 'License' }],
      },
      { status: 'APPROVED', credentialSnapshot: {} },
    ]);

    const summary = await service.agencyHiringPipelineSummary('admin-1', 't1');

    expect(summary.newApplicants).toBe(1);
    expect(summary.credentialsSubmitted).toBe(1);
    expect(summary.readyToHire).toBe(1);
    expect(summary.totalPendingActions).toBe(3);
  });

  it('counts pending actions per job posting', async () => {
    prisma.jobOpportunityApplication.findMany.mockResolvedValue([
      {
        jobOpportunityId: 'job-1',
        status: 'NEW_APPLICANT',
        credentialSnapshot: {},
      },
      {
        jobOpportunityId: 'job-1',
        status: 'APPROVED',
        credentialSnapshot: {},
      },
      {
        jobOpportunityId: 'job-2',
        status: 'REJECTED',
        credentialSnapshot: {},
      },
    ]);

    const counts = await service.agencyPendingActionsByJob('admin-1', 't1');

    expect(counts['job-1']).toBe(2);
    expect(counts['job-2']).toBeUndefined();
  });

  it('closes job posting when therapist is added to roster', async () => {
    prisma.jobOpportunityApplication.findFirst.mockResolvedValue({
      id: 'app-1',
      status: 'HIRED_CONTRACTED',
      jobOpportunityId: 'job-1',
      therapistId: 'therapist-1',
      jobOpportunity: { childServiceNeedId: 'need-1' },
      therapist: { user: { firstName: 'Sam', lastName: 'Therapist' } },
    });
    prisma.agencyTherapist.upsert.mockResolvedValue({ id: 'link-1' });
    prisma.childServiceNeed.update.mockResolvedValue({});
    prisma.jobOpportunity.update.mockResolvedValue({});

    await service.addTherapistToAgencyRosterFromApplication(
      'admin-1',
      't1',
      'app-1',
    );

    expect(prisma.jobOpportunity.update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: { status: 'CLOSED' },
      }),
    );
  });

  it('reschedules an active interview and notifies therapist', async () => {
    const scheduledAt = new Date(Date.now() + 48 * 60 * 60 * 1000);
    prisma.jobInterview.findFirst.mockResolvedValue({
      id: 'int-1',
      status: 'CONFIRMED',
      durationMinutes: 30,
      recordingRequested: false,
      agencyRecordingConsent: false,
      therapistRecordingConsent: false,
      notes: null,
      therapistUserId: 'therapist-user-1',
      application: {
        jobOpportunityId: 'job-1',
        jobOpportunity: { title: 'OT role' },
        therapist: { user: { firstName: 'Sam', lastName: 'Therapist' } },
      },
      agency: { name: 'Agency A' },
    });
    prisma.jobInterview.update.mockResolvedValue({
      id: 'int-1',
      status: 'CONFIRMED',
      scheduledAt,
      durationMinutes: 45,
      applicationId: 'app-1',
      application: {
        jobOpportunityId: 'job-1',
        jobOpportunity: { title: 'OT role' },
        therapist: { user: { firstName: 'Sam', lastName: 'Therapist' } },
      },
      agency: { name: 'Agency A' },
      scheduledBy: {},
      therapistUser: {},
      callSession: null,
    });

    await service.rescheduleJobInterview('admin-1', 't1', {
      interviewId: 'int-1',
      scheduledAt,
      durationMinutes: 45,
    });

    expect(notifications.createForUser).toHaveBeenCalledWith(
      'therapist-user-1',
      expect.objectContaining({ title: 'Interview rescheduled' }),
    );
  });

  it('allows agency to download credential snapshot documents', async () => {
    prisma.jobOpportunityApplication.findFirst.mockResolvedValue({
      id: 'app-1',
      credentialSnapshot: [{ id: 'doc-1', title: 'License' }],
    });
    documents.openFileStreamWithAudit.mockResolvedValue({
      doc: { mimeType: 'application/pdf', fileName: 'license.pdf' },
      stream: { pipe: jest.fn() },
    });

    const result = await service.openApplicationCredentialFile(
      'admin-1',
      't1',
      'app-1',
      'doc-1',
    );

    expect(result.doc.fileName).toBe('license.pdf');
    expect(documents.openFileStreamWithAudit).toHaveBeenCalledWith(
      'admin-1',
      'doc-1',
    );
  });

  it('rejects credential download when document is not in snapshot', async () => {
    prisma.jobOpportunityApplication.findFirst.mockResolvedValue({
      id: 'app-1',
      credentialSnapshot: [{ id: 'doc-1', title: 'License' }],
    });

    await expect(
      service.openApplicationCredentialFile('admin-1', 't1', 'app-1', 'doc-2'),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('lets therapist complete W-9 onboarding step', async () => {
    prisma.agencyTherapist.findFirst.mockResolvedValue({
      id: 'link-1',
      agencyId: 'agency-1',
      therapistId: 'therapist-1',
      hireOnboarding: {},
      agency: { id: 'agency-1', name: 'Agency A' },
      therapist: { user: { firstName: 'Sam', lastName: 'Therapist' } },
    });
    prisma.therapist.findFirst.mockResolvedValue({ id: 'therapist-1' });
    prisma.agencyTherapist.update.mockResolvedValue({
      id: 'link-1',
      therapistId: 'therapist-1',
      hireOnboarding: {
        w9: { complete: true, completedAt: new Date().toISOString() },
      },
      agency: { id: 'agency-1', name: 'Agency A' },
      therapist: { user: { firstName: 'Sam', lastName: 'Therapist' } },
    });

    const result = await service.updateHireOnboardingStep(
      'therapist-user-1',
      't1',
      { agencyTherapistLinkId: 'link-1', step: 'W9', complete: true },
      'THERAPIST',
    );

    expect(result.completedCount).toBe(1);
    expect(prisma.agencyTherapist.update).toHaveBeenCalled();
  });
});
