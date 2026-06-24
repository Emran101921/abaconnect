import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { AuditAction } from '../../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { assertEiBillingRole, EiBillingActor } from './ei-billing-access.util';
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
          (input.reconciliationStatus as
            | 'UNRECONCILED'
            | 'PARTIAL'
            | 'RECONCILED'
            | 'DISCREPANCY') ?? 'UNRECONCILED',
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

  async importEiEraStub(
    actor: EiBillingActor,
    input: { recordId: string; eraJson: string },
  ) {
    assertEiBillingRole(actor, ['BILLING_STAFF', 'PLATFORM_ADMIN']);

    let parsed: unknown;
    try {
      parsed = JSON.parse(input.eraJson);
    } catch {
      throw new BadRequestException('eraJson must be valid JSON');
    }

    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
      throw new BadRequestException('eraJson must be a JSON object');
    }

    const data = parsed as Record<string, unknown>;
    const paidAmount = data.paidAmount;
    if (
      typeof paidAmount !== 'number' ||
      !Number.isFinite(paidAmount) ||
      paidAmount < 0
    ) {
      throw new BadRequestException(
        'paidAmount must be a non-negative number',
      );
    }

    let allowedAmount: number | undefined;
    if (data.allowedAmount !== undefined) {
      if (
        typeof data.allowedAmount !== 'number' ||
        !Number.isFinite(data.allowedAmount) ||
        data.allowedAmount < 0
      ) {
        throw new BadRequestException(
          'allowedAmount must be a non-negative number',
        );
      }
      allowedAmount = data.allowedAmount;
    }

    const eftReference =
      typeof data.eftReference === 'string' ? data.eftReference : undefined;
    const traceNumber =
      typeof data.traceNumber === 'string' ? data.traceNumber : undefined;

    return this.recordPayment(actor, {
      recordId: input.recordId,
      paidAmount,
      allowedAmount,
      eftReference,
      eraPlaceholder: traceNumber ?? 'ERA_STUB_IMPORTED',
    });
  }
}
