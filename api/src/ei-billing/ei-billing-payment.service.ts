import { Injectable, NotFoundException } from '@nestjs/common';
import { AuditAction } from '../../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import {
  assertEiBillingRole,
  EiBillingActor,
} from './ei-billing-access.util';
import { EiBillingAuditService } from './ei-billing-audit.service';

@Injectable()
export class EiBillingPaymentService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: EiBillingAuditService,
  ) {}

  async recordPayment(
    actor: EiBillingActor,
    input: {
      recordId: string;
      paidAmount: number;
      allowedAmount?: number;
      adjustmentAmount?: number;
      deniedAmount?: number;
      eftReference?: string;
      eraPlaceholder?: string;
      reconciliationStatus?: string;
      postedAt?: Date;
    },
  ) {
    assertEiBillingRole(actor, ['BILLING_STAFF', 'PLATFORM_ADMIN']);

    const record = await this.prisma.eiBillingRecord.findFirst({
      where: { id: input.recordId, tenantId: actor.tenantId },
    });
    if (!record) {
      throw new NotFoundException('Billing record not found');
    }

    const posting = await this.prisma.eiPaymentPosting.create({
      data: {
        recordId: input.recordId,
        paidAmount: input.paidAmount,
        allowedAmount: input.allowedAmount,
        adjustmentAmount: input.adjustmentAmount,
        deniedAmount: input.deniedAmount,
        eftReference: input.eftReference,
        eraPlaceholder: input.eraPlaceholder ?? 'ERA_IMPORT_PENDING',
        reconciliationStatus:
          (input.reconciliationStatus as 'UNRECONCILED' | 'PARTIAL' | 'RECONCILED' | 'DISCREPANCY') ??
          'UNRECONCILED',
        postedAt: input.postedAt ?? new Date(),
        postedById: actor.id,
      },
    });

    await this.prisma.eiBillingRecord.update({
      where: { id: input.recordId },
      data: {
        queueStatus: 'PAID',
        allowedAmount: input.allowedAmount,
      },
    });

    await this.audit.log(
      actor.tenantId,
      actor.id,
      actor.role,
      AuditAction.EI_BILLING_PAYMENT_POSTED,
      'EiPaymentPosting',
      posting.id,
      { recordId: input.recordId, paidAmount: input.paidAmount },
      record.childId,
    );

    return posting;
  }
}
