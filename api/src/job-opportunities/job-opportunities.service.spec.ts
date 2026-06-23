import { BadRequestException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { PrismaService } from '../prisma/prisma.service';
import { JobOpportunitiesService } from './job-opportunities.service';

describe('JobOpportunitiesService publish PHI gate', () => {
  let service: JobOpportunitiesService;

  const prisma = {
    user: { findFirst: jest.fn() },
    jobOpportunity: {
      findFirst: jest.fn(),
      update: jest.fn(),
    },
    marketplaceAuditLog: { create: jest.fn() },
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        JobOpportunitiesService,
        { provide: PrismaService, useValue: prisma },
      ],
    }).compile();
    service = module.get(JobOpportunitiesService);
  });

  it('blocks publish when public text contains PHI phrases', async () => {
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
      status: 'DRAFT',
      title: 'OT Therapist Needed',
      publicDescription: 'Referral for child named Alex with autism diagnosis',
      requiredExperience: null,
      payRateDisplay: null,
    });
    prisma.jobOpportunity.update.mockResolvedValue({});
    prisma.marketplaceAuditLog.create.mockResolvedValue({});

    await expect(
      service.publishJobOpportunity('admin-1', 't1', 'job-1'),
    ).rejects.toBeInstanceOf(BadRequestException);

    expect(prisma.jobOpportunity.update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ status: 'BLOCKED' }),
      }),
    );
    expect(prisma.marketplaceAuditLog.create).toHaveBeenCalled();
  });
});
