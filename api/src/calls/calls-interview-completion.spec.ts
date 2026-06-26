import { Test, TestingModule } from '@nestjs/testing';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.service';
import { CallProviderFactory } from './call-provider.factory';
import { CallsAuditService } from './calls-audit.service';
import { CallsPermissionsService } from './calls-permissions.service';
import { CallsService } from './calls.service';

describe('CallsService job interview completion', () => {
  let service: CallsService;

  const notifications = { createForUser: jest.fn() };
  const audit = { append: jest.fn() };
  const permissions = {};
  const providerFactory = {
    getProvider: () => ({
      endRoom: jest.fn().mockResolvedValue(undefined),
    }),
  };

  const prisma = {
    callSession: {
      findUnique: jest.fn(),
      update: jest.fn(),
    },
    user: { findFirst: jest.fn(), findUnique: jest.fn() },
    jobInterview: {
      findUnique: jest.fn(),
      update: jest.fn(),
    },
    marketplaceAuditLog: { create: jest.fn() },
  };

  const startedAt = new Date(Date.now() - 5 * 60 * 1000);

  beforeEach(async () => {
    jest.clearAllMocks();
    notifications.createForUser.mockResolvedValue({});
    audit.append.mockResolvedValue(undefined);
    prisma.marketplaceAuditLog.create.mockResolvedValue({});

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CallsService,
        { provide: PrismaService, useValue: prisma },
        { provide: CallsPermissionsService, useValue: permissions },
        { provide: CallsAuditService, useValue: audit },
        { provide: CallProviderFactory, useValue: providerFactory },
        { provide: NotificationsService, useValue: notifications },
      ],
    }).compile();
    service = module.get(CallsService);
  });

  it('marks interview completed when an interview call ends', async () => {
    prisma.callSession.findUnique.mockResolvedValue({
      id: 'call-1',
      tenantId: 't1',
      agencyId: 'agency-1',
      childId: null,
      callType: 'VIDEO',
      status: 'IN_PROGRESS',
      initiatedByUserId: 'admin-1',
      startedAt,
      providerRoomId: 'room-1',
      jobInterviewId: 'interview-1',
      participants: [
        { userId: 'admin-1', joinStatus: 'JOINED' },
        { userId: 'therapist-user-1', joinStatus: 'JOINED' },
      ],
      initiatedBy: { role: 'AGENCY_ADMIN' },
    });
    prisma.user.findUnique.mockResolvedValue({
      id: 'admin-1',
      role: 'AGENCY_ADMIN',
      tenantId: 't1',
      isActive: true,
      firstName: 'Agency',
      lastName: 'Admin',
    });
    prisma.callSession.update.mockResolvedValue({
      id: 'call-1',
      callType: 'VIDEO',
      status: 'ENDED',
      initiatedByUserId: 'admin-1',
      startedAt,
      endedAt: new Date(),
      durationSeconds: 300,
      participants: [],
      initiatedBy: { firstName: 'Agency', lastName: 'Admin' },
    });
    prisma.jobInterview.findUnique.mockResolvedValue({
      id: 'interview-1',
      tenantId: 't1',
      status: 'IN_PROGRESS',
      applicationId: 'app-1',
      therapistUserId: 'therapist-user-1',
      scheduledByUserId: 'admin-1',
      application: {
        jobOpportunityId: 'job-1',
        jobOpportunity: { title: 'OT role' },
      },
      agency: { name: 'Agency A' },
    });
    prisma.jobInterview.update.mockResolvedValue({
      id: 'interview-1',
      status: 'COMPLETED',
    });

    await service.endCall('admin-1', 'call-1', {});

    expect(prisma.jobInterview.update).toHaveBeenCalledWith({
      where: { id: 'interview-1' },
      data: { status: 'COMPLETED' },
    });
    expect(prisma.marketplaceAuditLog.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          eventType: 'JOB_INTERVIEW_COMPLETED',
          entityId: 'interview-1',
        }),
      }),
    );
    expect(notifications.createForUser).toHaveBeenCalledWith(
      'therapist-user-1',
      expect.objectContaining({
        data: expect.objectContaining({ type: 'JOB_INTERVIEW_COMPLETED' }),
      }),
    );
    expect(notifications.createForUser).toHaveBeenCalledWith(
      'admin-1',
      expect.objectContaining({
        data: expect.objectContaining({ type: 'JOB_INTERVIEW_COMPLETED' }),
      }),
    );
  });
});
