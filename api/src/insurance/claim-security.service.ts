import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { createHash } from 'crypto';
import {
  AuditAction,
  ClaimStatus,
  Prisma,
} from '../../generated/prisma/client';
import { AuditService } from '../audit/audit.service';
import { PrismaService } from '../prisma/prisma.service';

const LOCKED_STATUSES = new Set<ClaimStatus>([
  ClaimStatus.SUBMITTED,
  ClaimStatus.PENDING,
  ClaimStatus.UNDER_REVIEW,
  ClaimStatus.APPROVED,
  ClaimStatus.PAID,
]);

export interface ClaimAuditContext {
  editorId: string;
  editorRole?: string;
  ipAddress?: string;
}

@Injectable()
export class ClaimSecurityService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  computeDuplicateHash(input: {
    childId: string;
    serviceDate: Date;
    cptCode?: string | null;
    billedAmount: number | Prisma.Decimal;
    payerName: string;
  }): string {
    const payload = [
      input.childId,
      input.serviceDate.toISOString().slice(0, 10),
      input.cptCode ?? '',
      String(input.billedAmount),
      input.payerName.trim().toLowerCase(),
    ].join('|');
    return createHash('sha256').update(payload).digest('hex');
  }

  async assertNoDuplicate(
    tenantId: string,
    hash: string,
    excludeClaimId?: string,
  ): Promise<void> {
    const existing = await this.prisma.insuranceClaim.findFirst({
      where: {
        tenantId,
        duplicateHash: hash,
        ...(excludeClaimId ? { id: { not: excludeClaimId } } : {}),
        status: { notIn: [ClaimStatus.DENIED, ClaimStatus.DRAFT] },
      },
    });
    if (existing) {
      throw new ConflictException(
        'A similar claim already exists for this client, date, and service',
      );
    }
  }

  assertEditable(claim: { status: ClaimStatus; lockedAt: Date | null }): void {
    if (claim.lockedAt || LOCKED_STATUSES.has(claim.status)) {
      throw new ForbiddenException(
        'Claim is locked after submission. Use the resubmission workflow for corrections.',
      );
    }
  }

  async recordHistory(
    claimId: string,
    tenantId: string,
    ctx: ClaimAuditContext,
    action: string,
    fieldChanges: Record<string, { old?: unknown; new?: unknown }>,
  ) {
    return this.prisma.claimEditHistory.create({
      data: {
        claimId,
        tenantId,
        editorId: ctx.editorId,
        editorRole: ctx.editorRole,
        action,
        fieldChanges: fieldChanges as Prisma.InputJsonValue,
        ipAddress: ctx.ipAddress,
      },
    });
  }

  async lockOnSubmit(
    claimId: string,
    tenantId: string,
    ctx: ClaimAuditContext,
    patientId?: string,
  ) {
    const updated = await this.prisma.insuranceClaim.update({
      where: { id: claimId },
      data: {
        status: ClaimStatus.SUBMITTED,
        submittedAt: new Date(),
        lockedAt: new Date(),
        submittedById: ctx.editorId,
      },
    });

    await this.recordHistory(claimId, tenantId, ctx, 'SUBMIT', {
      status: { old: ClaimStatus.DRAFT, new: ClaimStatus.SUBMITTED },
    });

    await this.audit.log({
      tenantId,
      actorId: ctx.editorId,
      actorRole: ctx.editorRole,
      action: AuditAction.CLAIM_SUBMITTED,
      resourceType: 'InsuranceClaim',
      resourceId: claimId,
      patientId,
      ipAddress: ctx.ipAddress,
      metadata: { payer: updated.payerName, cptCode: updated.cptCode },
    });

    return updated;
  }

  async createResubmission(
    originalClaimId: string,
    tenantId: string,
    ctx: ClaimAuditContext,
    corrections: Prisma.InsuranceClaimUpdateInput,
  ) {
    const original = await this.prisma.insuranceClaim.findFirst({
      where: { id: originalClaimId, tenantId },
    });
    if (!original) throw new BadRequestException('Original claim not found');
    if (!original.lockedAt) {
      throw new BadRequestException('Only submitted claims can be resubmitted');
    }

    const existingResub = await this.prisma.insuranceClaim.findFirst({
      where: { resubmissionOfId: originalClaimId },
    });
    if (existingResub) {
      throw new ConflictException(
        'A resubmission already exists for this claim',
      );
    }

    const resub = await this.prisma.insuranceClaim.create({
      data: {
        tenantId,
        parentId: original.parentId,
        childId: original.childId,
        sessionId: original.sessionId,
        therapistId: original.therapistId,
        createdById: ctx.editorId,
        payerName: original.payerName,
        billedAmount: original.billedAmount,
        serviceDate: original.serviceDate,
        cptCode: original.cptCode,
        authorizationNumber: original.authorizationNumber,
        resubmissionOfId: originalClaimId,
        status: ClaimStatus.DRAFT,
        metadata: {
          ...(original.metadata as object),
          resubmissionReason: (corrections as { denialReason?: string })
            .denialReason,
        } as Prisma.InputJsonValue,
        duplicateHash: original.duplicateHash,
      },
    });

    await this.recordHistory(resub.id, tenantId, ctx, 'RESUBMIT_CREATE', {
      originalClaimId: { new: originalClaimId },
    });

    await this.audit.log({
      tenantId,
      actorId: ctx.editorId,
      actorRole: ctx.editorRole,
      action: AuditAction.CLAIM_RESUBMITTED,
      resourceType: 'InsuranceClaim',
      resourceId: resub.id,
      patientId: original.childId,
      ipAddress: ctx.ipAddress,
      metadata: { originalClaimId },
    });

    return resub;
  }
}
