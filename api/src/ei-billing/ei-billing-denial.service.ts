import { Injectable, NotFoundException } from '@nestjs/common';
import { AuditAction, Prisma } from '../../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import {
  assertEiBillingRole,
  EiBillingActor,
  resolveAgencyIdForActor,
} from './ei-billing-access.util';
import { EiBillingAuditService } from './ei-billing-audit.service';

@Injectable()
export class EiBillingDenialService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: EiBillingAuditService,
  ) {}

  async recordDenial(
    actor: EiBillingActor,
    input: {
      recordId: string;
      code: string;
      reason: string;
      payerName?: string;
      receivedAt?: Date;
      assignedStaffId?: string;
      correctionNotes?: string;
    },
  ) {
    assertEiBillingRole(actor, ['BILLING_STAFF', 'PLATFORM_ADMIN', 'AGENCY_ADMIN']);

    const record = await this.prisma.eiBillingRecord.findFirst({
      where: { id: input.recordId, tenantId: actor.tenantId },
    });
    if (!record) {
      throw new NotFoundException('Billing record not found');
    }

    const denial = await this.prisma.eiDenialRejection.create({
      data: {
        recordId: input.recordId,
        code: input.code,
        reason: input.reason,
        payerName: input.payerName,
        receivedAt: input.receivedAt ?? new Date(),
        assignedStaffId: input.assignedStaffId ?? actor.id,
        correctionNotes: input.correctionNotes,
        correctionStatus: 'OPEN',
      },
    });

    await this.prisma.eiBillingRecord.update({
      where: { id: input.recordId },
      data: { queueStatus: 'CORRECTION_NEEDED' },
    });

    await this.audit.log(
      actor.tenantId,
      actor.id,
      actor.role,
      AuditAction.EI_BILLING_DENIAL_RECORDED,
      'EiDenialRejection',
      denial.id,
      { recordId: input.recordId, code: input.code },
      record.childId,
    );

    return denial;
  }

  async listDenials(actor: EiBillingActor, filter?: { agencyId?: string }) {
    assertEiBillingRole(actor, [
      'BILLING_STAFF',
      'PLATFORM_ADMIN',
      'AGENCY_ADMIN',
      'THERAPIST',
      'SERVICE_COORDINATOR',
    ]);

    const recordWhere = await this.buildDenialRecordScope(actor, filter?.agencyId);

    return this.prisma.eiDenialRejection.findMany({
      where: { record: recordWhere },
      orderBy: { receivedAt: 'desc' },
      take: 100,
      include: {
        record: {
          include: {
            child: { select: { firstName: true, lastName: true } },
            therapist: {
              include: {
                user: { select: { firstName: true, lastName: true } },
              },
            },
          },
        },
      },
    });
  }

  private async buildDenialRecordScope(
    actor: EiBillingActor,
    agencyId?: string,
  ): Promise<Prisma.EiBillingRecordWhereInput> {
    const scope: Prisma.EiBillingRecordWhereInput = {
      tenantId: actor.tenantId,
    };

    if (actor.role === 'PLATFORM_ADMIN') {
      if (agencyId) {
        scope.agencyId = agencyId;
      }
    } else if (
      actor.role === 'BILLING_STAFF' ||
      actor.role === 'AGENCY_ADMIN'
    ) {
      scope.agencyId = await resolveAgencyIdForActor(
        this.prisma,
        actor,
        agencyId,
      );
    } else if (actor.role === 'THERAPIST' && actor.therapistId) {
      scope.therapistId = actor.therapistId;
    } else if (actor.role === 'SERVICE_COORDINATOR') {
      scope.caseProfile = {
        scReferenceNumber: { not: null },
      };
    }

    return scope;
  }
}
