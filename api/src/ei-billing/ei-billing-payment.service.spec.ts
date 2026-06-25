import { BadRequestException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { AuditAction } from '../../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { EiBillingAuditService } from './ei-billing-audit.service';
import { EiBillingPaymentService } from './ei-billing-payment.service';

describe('EiBillingPaymentService', () => {
  let service: EiBillingPaymentService;
  const prisma = {
    eiBillingRecord: {
      findFirst: jest.fn(),
      update: jest.fn(),
    },
    eiPaymentPosting: {
      create: jest.fn(),
    },
  };
  const audit = {
    log: jest.fn(),
  };
  const actor = {
    id: 'billing-1',
    tenantId: 'tenant-1',
    role: 'BILLING_STAFF' as const,
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        EiBillingPaymentService,
        { provide: PrismaService, useValue: prisma },
        { provide: EiBillingAuditService, useValue: audit },
      ],
    }).compile();
    service = module.get(EiBillingPaymentService);
  });

  it('imports ERA stub JSON and posts payment', async () => {
    prisma.eiBillingRecord.findFirst.mockResolvedValue({
      id: 'record-1',
      childId: 'child-1',
    });
    prisma.eiPaymentPosting.create.mockResolvedValue({
      id: 'posting-1',
      paidAmount: 120,
      reconciliationStatus: 'UNRECONCILED',
      postedAt: new Date('2025-06-01'),
    });
    prisma.eiBillingRecord.update.mockResolvedValue({});

    const posting = await service.importEiEraStub(actor, {
      recordId: 'record-1',
      eraJson: JSON.stringify({
        paidAmount: 120,
        allowedAmount: 100,
        eftReference: 'EFT123',
        traceNumber: 'ERA-001',
      }),
    });

    expect(posting.id).toBe('posting-1');
    expect(prisma.eiPaymentPosting.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          recordId: 'record-1',
          paidAmount: 120,
          allowedAmount: 100,
          eftReference: 'EFT123',
          eraPlaceholder: 'ERA-001',
        }),
      }),
    );
    expect(audit.log).toHaveBeenCalledWith(
      actor.tenantId,
      actor.id,
      actor.role,
      AuditAction.EI_BILLING_PAYMENT_POSTED,
      'EiPaymentPosting',
      'posting-1',
      { recordId: 'record-1', paidAmount: 120 },
      'child-1',
    );
  });

  it('rejects invalid ERA JSON', async () => {
    await expect(
      service.importEiEraStub(actor, {
        recordId: 'record-1',
        eraJson: 'not-json',
      }),
    ).rejects.toThrow(BadRequestException);
  });

  it('rejects ERA JSON without paidAmount', async () => {
    await expect(
      service.importEiEraStub(actor, {
        recordId: 'record-1',
        eraJson: JSON.stringify({ allowedAmount: 100 }),
      }),
    ).rejects.toThrow(BadRequestException);
  });
});
