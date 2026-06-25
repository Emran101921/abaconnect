import { BadRequestException, NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.service';
import { JobOpportunitiesService } from './job-opportunities.service';

describe('JobOpportunitiesService inviteTherapistToApply', () => {
  let service: JobOpportunitiesService;

  const notifications = {
    createForUser: jest.fn(),
  };

  const prisma = {
    user: { findFirst: jest.fn() },
    jobOpportunity: { findFirst: jest.fn() },
    therapist: { findFirst: jest.fn() },
    agencyInviteToApply: { upsert: jest.fn() },
    marketplaceAuditLog: { create: jest.fn() },
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    notifications.createForUser.mockResolvedValue({});
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        JobOpportunitiesService,
        { provide: PrismaService, useValue: prisma },
        { provide: NotificationsService, useValue: notifications },
      ],
    }).compile();
    service = module.get(JobOpportunitiesService);
  });

  it('upserts invite for roster therapist and logs audit', async () => {
    prisma.user.findFirst.mockResolvedValue({
      id: 'admin-1',
      tenantId: 't1',
      role: 'AGENCY_ADMIN',
      agencyId: 'agency-1',
      agency: { id: 'agency-1', tenantId: 't1', name: 'Agency A' },
    });
    prisma.jobOpportunity.findFirst.mockResolvedValue({
      id: 'job-1',
      agencyId: 'agency-1',
      title: 'OT role',
      agency: { name: 'Agency A' },
    });
    prisma.therapist.findFirst.mockResolvedValue({
      id: 'therapist-1',
      tenantId: 't1',
      userId: 'therapist-user-1',
      isVerified: false,
      agencyLinks: [{ agencyId: 'agency-1' }],
      user: { id: 'therapist-user-1' },
    });
    prisma.agencyInviteToApply.upsert.mockResolvedValue({
      id: 'invite-1',
      jobOpportunityId: 'job-1',
      therapistId: 'therapist-1',
      createdAt: new Date('2026-01-01'),
      jobOpportunity: {
        title: 'OT role',
        agency: { name: 'Agency A' },
      },
    });
    prisma.marketplaceAuditLog.create.mockResolvedValue({});

    const result = await service.inviteTherapistToApply(
      'admin-1',
      't1',
      'job-1',
      'therapist-1',
    );

    expect(result.id).toBe('invite-1');
    expect(prisma.agencyInviteToApply.upsert).toHaveBeenCalled();
    expect(prisma.marketplaceAuditLog.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          eventType: 'THERAPIST_INVITED_TO_APPLY',
        }),
      }),
    );
    expect(notifications.createForUser).toHaveBeenCalledWith(
      'therapist-user-1',
      expect.objectContaining({
        data: expect.objectContaining({
          type: 'JOB_INVITE_TO_APPLY',
          jobOpportunityId: 'job-1',
        }),
      }),
    );
  });

  it('rejects therapist not on roster and not verified', async () => {
    prisma.user.findFirst.mockResolvedValue({
      id: 'admin-1',
      tenantId: 't1',
      role: 'AGENCY_ADMIN',
      agencyId: 'agency-1',
      agency: { id: 'agency-1', tenantId: 't1' },
    });
    prisma.jobOpportunity.findFirst.mockResolvedValue({
      id: 'job-1',
      agencyId: 'agency-1',
      title: 'OT role',
      agency: { name: 'Agency A' },
    });
    prisma.therapist.findFirst.mockResolvedValue({
      id: 'therapist-1',
      tenantId: 't1',
      isVerified: false,
      agencyLinks: [],
    });

    await expect(
      service.inviteTherapistToApply('admin-1', 't1', 'job-1', 'therapist-1'),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('rejects unknown therapist in tenant', async () => {
    prisma.user.findFirst.mockResolvedValue({
      id: 'admin-1',
      tenantId: 't1',
      role: 'AGENCY_ADMIN',
      agencyId: 'agency-1',
      agency: { id: 'agency-1', tenantId: 't1' },
    });
    prisma.jobOpportunity.findFirst.mockResolvedValue({
      id: 'job-1',
      agencyId: 'agency-1',
      title: 'OT role',
      agency: { name: 'Agency A' },
    });
    prisma.therapist.findFirst.mockResolvedValue(null);

    await expect(
      service.inviteTherapistToApply('admin-1', 't1', 'job-1', 'therapist-1'),
    ).rejects.toBeInstanceOf(NotFoundException);
  });
});
