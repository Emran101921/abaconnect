import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { AuditService } from '../audit/audit.service';
import { PhiAuditService } from '../audit/phi-audit.service';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.service';
import { MarketplaceService } from './marketplace.service';

describe('MarketplaceService privacy gates', () => {
  let service: MarketplaceService;
  const prisma = {
    parent: { findUnique: jest.fn() },
    child: { findFirst: jest.fn(), findUnique: jest.fn(), update: jest.fn() },
    screeningResponse: { findFirst: jest.fn() },
    marketplaceRequest: {
      create: jest.fn(),
      findFirst: jest.fn(),
      findUnique: jest.fn(),
      findMany: jest.fn(),
      update: jest.fn(),
    },
    marketplaceConsentRecord: {
      findFirst: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
      findMany: jest.fn(),
    },
    marketplaceInterest: { upsert: jest.fn(), updateMany: jest.fn() },
    providerMarketplaceProfile: { findUnique: jest.fn(), findFirst: jest.fn() },
    marketplaceReport: { create: jest.fn() },
    auditLog: { findMany: jest.fn() },
  };
  const audit = { log: jest.fn() };
  const phiAudit = { logPhiAccess: jest.fn() };
  const notifications = { create: jest.fn() };

  beforeEach(async () => {
    jest.clearAllMocks();
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        MarketplaceService,
        { provide: PrismaService, useValue: prisma },
        { provide: AuditService, useValue: audit },
        { provide: PhiAuditService, useValue: phiAudit },
        { provide: NotificationsService, useValue: notifications },
      ],
    }).compile();

    service = module.get(MarketplaceService);
  });

  it('rejects marketplace posting without explicit anonymous consent', async () => {
    prisma.parent.findUnique.mockResolvedValue({
      id: 'parent-1',
      tenantId: 't1',
    });
    prisma.child.findFirst.mockResolvedValue({
      id: 'child-1',
      parentId: 'parent-1',
      zipCode: '11230',
      dateOfBirth: new Date('2023-01-01'),
      parent: { tenantId: 't1' },
    });

    await expect(
      service.createMarketplaceRequestForParent(
        'user-1',
        'child-1',
        {
          anonymousConsentGranted: false,
          locationType: 'HOME',
        },
        {},
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('blocks provider from viewing identifiable child details without consent', async () => {
    prisma.providerMarketplaceProfile.findUnique.mockResolvedValue({
      id: 'prov-1',
      tenantId: 't1',
      accountType: 'THERAPIST',
      confidentialityTermsAccepted: true,
      verifiedStatus: 'VERIFIED',
      coverageZipCodes: ['11230'],
    });
    prisma.marketplaceRequest.findFirst.mockResolvedValue({
      id: 'req-1',
      tenantId: 't1',
      childId: 'child-1',
      anonymousPublicId: 'SR-10001',
    });
    prisma.marketplaceConsentRecord.findFirst.mockResolvedValue(null);

    await expect(
      service.getAuthorizedChildDetailsForProvider(
        'therapist-user',
        'req-1',
        {},
      ),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('requires provider marketplace onboarding before browsing', async () => {
    prisma.providerMarketplaceProfile.findUnique.mockResolvedValue(null);

    await expect(
      service.browsePublicRequestsForProvider('therapist-user', {}, {}),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });
});
