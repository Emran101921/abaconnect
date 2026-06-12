import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  ClaimStatus,
  Prisma,
  TherapyType,
} from '../../generated/prisma/client';
import {
  DateRangeFilter,
  priorPeriodBounds,
  prismaBoundsRange,
  prismaDateRange,
  resolveAnalyticsBounds,
  ResolvedDateBounds,
} from '../common/date-range.util';
import { PrismaService } from '../prisma/prisma.service';
import { AuditAction } from '../../generated/prisma/client';
import { AuditService } from '../audit/audit.service';
import { ClearinghouseService } from './clearinghouse.service';
import { ClaimSecurityService } from './claim-security.service';
import { Edi837Service } from './edi837.service';

const CPT_BY_THERAPY: Record<TherapyType, string> = {
  ABA: '97153',
  SPEECH: '92507',
  OCCUPATIONAL: '97110',
  PHYSICAL: '97110',
  EARLY_INTERVENTION: '97153',
  BEHAVIORAL_CONSULTATION: '97155',
  PARENT_TRAINING: '97156',
  DEVELOPMENTAL_EVALUATION: '96110',
};

@Injectable()
export class InsuranceService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly edi837: Edi837Service,
    private readonly clearinghouse: ClearinghouseService,
    private readonly claimSecurity: ClaimSecurityService,
    private readonly audit: AuditService,
  ) {}

  async listClaimsForParentUser(userId: string) {
    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (!parent) return [];
    return this.prisma.insuranceClaim.findMany({
      where: { parentId: parent.id },
      include: { child: true },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
  }

  async submitClaim(
    userId: string,
    data: {
      childId: string;
      payerName: string;
      billedAmount: number;
      serviceDate: Date;
    },
  ) {
    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (!parent) throw new BadRequestException('Parent profile not found');

    const child = await this.prisma.child.findFirst({
      where: { id: data.childId, parentId: parent.id },
    });
    if (!child) throw new NotFoundException('Child not found');

    const duplicateHash = this.claimSecurity.computeDuplicateHash({
      childId: child.id,
      serviceDate: data.serviceDate,
      billedAmount: data.billedAmount,
      payerName: data.payerName,
    });
    await this.claimSecurity.assertNoDuplicate(parent.tenantId, duplicateHash);

    const claim = await this.prisma.insuranceClaim.create({
      data: {
        tenantId: parent.tenantId,
        parentId: parent.id,
        childId: child.id,
        createdById: userId,
        payerName: data.payerName,
        billedAmount: data.billedAmount,
        serviceDate: data.serviceDate,
        duplicateHash,
        status: 'DRAFT',
      },
      include: { child: true },
    });

    await this.audit.log({
      tenantId: parent.tenantId,
      actorId: userId,
      action: AuditAction.CLAIM_CREATED,
      resourceType: 'InsuranceClaim',
      resourceId: claim.id,
      patientId: child.id,
    });

    return this.claimSecurity.lockOnSubmit(
      claim.id,
      parent.tenantId,
      {
        editorId: userId,
      },
      child.id,
    );
  }

  async draftClaimFromSession(sessionId: string) {
    const existing = await this.prisma.insuranceClaim.findUnique({
      where: { sessionId },
    });
    if (existing) return existing;

    const session = await this.prisma.session.findUnique({
      where: { id: sessionId },
      include: {
        child: true,
        appointment: true,
        therapist: { include: { agencyLinks: { include: { agency: true } } } },
      },
    });
    if (!session) return null;

    const parent = await this.prisma.parent.findFirst({
      where: { children: { some: { id: session.childId } } },
    });
    if (!parent) return null;

    const hourlyRate = session.therapist.hourlyRate
      ? Number(session.therapist.hourlyRate)
      : 120;
    const units = Math.max(1, Math.round((session.durationMinutes ?? 60) / 15));
    const billedAmount = Number(((hourlyRate / 4) * units).toFixed(2));
    const cptCode =
      CPT_BY_THERAPY[session.appointment.therapyType] ?? CPT_BY_THERAPY.ABA;
    const agencyNpi = session.therapist.agencyLinks[0]?.agency?.npi ?? null;

    const duplicateHash = this.claimSecurity.computeDuplicateHash({
      childId: session.childId,
      serviceDate: session.appointment.scheduledStart,
      cptCode,
      billedAmount,
      payerName: parent.insuranceProvider ?? 'Demo Payer',
    });
    await this.claimSecurity.assertNoDuplicate(session.tenantId, duplicateHash);

    const claim = await this.prisma.insuranceClaim.create({
      data: {
        tenantId: session.tenantId,
        parentId: parent.id,
        childId: session.childId,
        sessionId: session.id,
        therapistId: session.therapistId,
        payerName: parent.insuranceProvider ?? 'Demo Payer',
        billedAmount,
        serviceDate: session.appointment.scheduledStart,
        cptCode,
        duplicateHash,
        status: 'DRAFT',
        metadata: {
          cptCode,
          units,
          diagnosisCodes: session.child.diagnosisCodes,
          providerNpi: agencyNpi,
          memberId: parent.insuranceMemberId,
        },
      },
      include: { child: true },
    });

    await this.audit.log({
      tenantId: session.tenantId,
      action: AuditAction.CLAIM_CREATED,
      resourceType: 'InsuranceClaim',
      resourceId: claim.id,
      patientId: session.childId,
    });

    return claim;
  }

  async prepareClaimEdi(claimId: string, tenantId?: string) {
    const claim = await this.prisma.insuranceClaim.findFirst({
      where: {
        id: claimId,
        ...(tenantId ? { tenantId } : {}),
      },
      include: {
        child: true,
        parent: true,
        session: { include: { appointment: true } },
      },
    });
    if (!claim) throw new NotFoundException('Claim not found');

    const meta = (claim.metadata ?? {}) as Record<string, unknown>;
    const cptCode =
      (meta.cptCode as string) ??
      (claim.session
        ? CPT_BY_THERAPY[claim.session.appointment.therapyType]
        : CPT_BY_THERAPY.ABA);
    const units = (meta.units as number) ?? 4;

    const ediPayload = this.edi837.build837Payload({
      claimId: claim.id,
      claimNumber: claim.claimNumber,
      payerName: claim.payerName,
      billedAmount: Number(claim.billedAmount),
      serviceDate: claim.serviceDate,
      childFirstName: claim.child.firstName,
      childLastName: claim.child.lastName,
      diagnosisCodes: claim.child.diagnosisCodes.length
        ? claim.child.diagnosisCodes
        : ['F84.0'],
      cptCode,
      units,
      providerNpi: (meta.providerNpi as string) ?? null,
      memberId: claim.parent.insuranceMemberId,
    });

    const claimNumber =
      claim.claimNumber ?? `CLM-${claim.id.slice(0, 8).toUpperCase()}`;

    return this.prisma.insuranceClaim.update({
      where: { id: claim.id },
      data: {
        claimNumber,
        status: claim.status === 'DRAFT' ? 'PENDING' : claim.status,
        metadata: {
          ...meta,
          ediPayload,
          ediReady: true,
          ediGeneratedAt: new Date().toISOString(),
        } as Prisma.InputJsonValue,
      },
      include: { child: true, parent: { include: { user: true } } },
    });
  }

  async submitClaimToClearinghouse(claimId: string, tenantId: string) {
    const prepared = await this.prepareClaimEdi(claimId, tenantId);
    const meta = (prepared.metadata ?? {}) as Record<string, unknown>;
    const ediPayload = meta.ediPayload as Record<string, unknown>;

    const result = await this.clearinghouse.submit837(claimId, ediPayload);
    if (result.status !== 'ACCEPTED') {
      return this.prisma.insuranceClaim.update({
        where: { id: claimId },
        data: {
          status: 'DENIED',
          denialReason: result.message,
          metadata: {
            ...meta,
            clearinghouse: {
              externalId: result.externalId,
              status: result.status,
              message: result.message,
              submittedAt: new Date().toISOString(),
            },
          } as Prisma.InputJsonValue,
        },
        include: { child: true, parent: { include: { user: true } } },
      });
    }

    await this.prisma.insuranceClaim.update({
      where: { id: claimId },
      data: {
        status: 'SUBMITTED',
        submittedAt: new Date(),
        metadata: {
          ...meta,
          clearinghouse: {
            externalId: result.externalId,
            status: result.status,
            message: result.message,
            submittedAt: new Date().toISOString(),
          },
        } as Prisma.InputJsonValue,
      },
    });

    return this.processRemittance835ForClaim(tenantId, claimId);
  }

  async create(data: Record<string, unknown>) {
    void data;
    throw new BadRequestException('Use GraphQL submitInsuranceClaim');
  }

  async findAll() {
    return this.prisma.insuranceClaim.findMany({ take: 20 });
  }

  async findOne(id: string) {
    const row = await this.prisma.insuranceClaim.findUnique({ where: { id } });
    if (!row) throw new NotFoundException('Claim not found');
    return row;
  }

  async update(
    id: string,
    data: Record<string, unknown>,
    editorId?: string,
    editorRole?: string,
  ) {
    const existing = await this.findOne(id);
    this.claimSecurity.assertEditable(existing);
    if (editorId) {
      await this.claimSecurity.recordHistory(
        id,
        existing.tenantId,
        { editorId, editorRole },
        'UPDATE',
        Object.fromEntries(
          Object.keys(data).map((key) => [
            key,
            { old: (existing as Record<string, unknown>)[key], new: data[key] },
          ]),
        ),
      );
    }
    return this.prisma.insuranceClaim.update({
      where: { id },
      data: data as Parameters<
        typeof this.prisma.insuranceClaim.update
      >[0]['data'],
    });
  }

  async remove(id: string) {
    await this.findOne(id);
    await this.prisma.insuranceClaim.delete({ where: { id } });
    return { id, deleted: true };
  }

  async listClaimsForTenant(tenantId: string, status?: ClaimStatus) {
    return this.prisma.insuranceClaim.findMany({
      where: {
        tenantId,
        ...(status ? { status } : {}),
      },
      include: {
        child: true,
        parent: { include: { user: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  async countOpenClaimsForParent(parentId: string) {
    return this.prisma.insuranceClaim.count({
      where: {
        parentId,
        status: { in: ['DRAFT', 'SUBMITTED', 'PENDING', 'UNDER_REVIEW'] },
      },
    });
  }

  async countDraftClaimsForTenant(tenantId: string) {
    return this.prisma.insuranceClaim.count({
      where: { tenantId, status: 'DRAFT' },
    });
  }

  async listAnalyticsClaimsForTenant(
    tenantId: string,
    filter: 'DRAFT' | 'SUBMITTED' | 'PENDING' | 'PAID' | 'DENIED',
    limit = 50,
    dateRange?: { fromDate?: Date; toDate?: Date },
  ) {
    const status =
      filter === 'PENDING'
        ? { in: ['PENDING', 'UNDER_REVIEW', 'APPROVED'] as ClaimStatus[] }
        : filter;
    const serviceDate = prismaDateRange('serviceDate', dateRange ?? {});
    return this.prisma.insuranceClaim.findMany({
      where: {
        tenantId,
        status,
        ...serviceDate,
      },
      include: { child: true },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });
  }

  async getClaimsPipelineForTenant(
    tenantId: string,
    dateRange?: DateRangeFilter,
  ) {
    const currentBounds = resolveAnalyticsBounds(dateRange);
    const priorBounds = priorPeriodBounds(currentBounds.from, currentBounds.to);

    const [current, prior, recentClaims] = await Promise.all([
      this.queryClaimsPipelineCounts(tenantId, currentBounds),
      this.queryClaimsPipelineCounts(tenantId, priorBounds),
      this.prisma.insuranceClaim.findMany({
        where: {
          tenantId,
          ...prismaBoundsRange('serviceDate', currentBounds),
        },
        include: { child: true },
        orderBy: { createdAt: 'desc' },
        take: 10,
      }),
    ]);

    return {
      summary: {
        ...current,
        priorDraftCount: prior.draftCount,
        priorSubmittedCount: prior.submittedCount,
        priorPendingCount: prior.pendingCount,
        priorPaidCount: prior.paidCount,
        priorDeniedCount: prior.deniedCount,
        priorPaidAmountTotal: prior.paidAmountTotal,
      },
      recentClaims,
    };
  }

  private async queryClaimsPipelineCounts(
    tenantId: string,
    bounds: ResolvedDateBounds,
  ) {
    const baseWhere = {
      tenantId,
      ...prismaBoundsRange('serviceDate', bounds),
    };
    const paidWhere = { ...baseWhere, status: 'PAID' as ClaimStatus };

    const [
      draftCount,
      submittedCount,
      pendingCount,
      paidCount,
      deniedCount,
      paidClaims,
    ] = await Promise.all([
      this.prisma.insuranceClaim.count({
        where: { ...baseWhere, status: 'DRAFT' },
      }),
      this.prisma.insuranceClaim.count({
        where: { ...baseWhere, status: 'SUBMITTED' },
      }),
      this.prisma.insuranceClaim.count({
        where: {
          ...baseWhere,
          status: { in: ['PENDING', 'UNDER_REVIEW', 'APPROVED'] },
        },
      }),
      this.prisma.insuranceClaim.count({ where: paidWhere }),
      this.prisma.insuranceClaim.count({
        where: { ...baseWhere, status: 'DENIED' },
      }),
      this.prisma.insuranceClaim.findMany({
        where: paidWhere,
        select: { paidAmount: true, approvedAmount: true, billedAmount: true },
      }),
    ]);

    const paidAmountTotal = paidClaims.reduce((sum, claim) => {
      const amount =
        claim.paidAmount ?? claim.approvedAmount ?? claim.billedAmount;
      return sum + Number(amount ?? 0);
    }, 0);

    return {
      draftCount,
      submittedCount,
      pendingCount,
      paidCount,
      deniedCount,
      paidAmountTotal,
    };
  }

  async getClaimForTenant(tenantId: string, claimId: string) {
    const claim = await this.prisma.insuranceClaim.findFirst({
      where: { id: claimId, tenantId },
      include: { child: true, parent: { include: { user: true } } },
    });
    if (!claim) throw new NotFoundException('Claim not found');
    return claim;
  }

  async processRemittance835ForClaim(tenantId: string, claimId: string) {
    const claim = await this.prisma.insuranceClaim.findFirst({
      where: { id: claimId, tenantId },
      include: { child: true, parent: { include: { user: true } } },
    });
    if (!claim) throw new NotFoundException('Claim not found');

    const payableStatuses: ClaimStatus[] = [
      'SUBMITTED',
      'PENDING',
      'UNDER_REVIEW',
      'APPROVED',
    ];
    if (!payableStatuses.includes(claim.status)) {
      throw new BadRequestException(
        `Claim status ${claim.status} cannot receive 835 remittance`,
      );
    }

    const meta = (claim.metadata ?? {}) as Record<string, unknown>;
    const clearinghouse = meta.clearinghouse as
      | { externalId?: string }
      | undefined;
    const externalId =
      clearinghouse?.externalId ?? `STUB-${claim.id.slice(0, 8).toUpperCase()}`;

    const remittance = await this.clearinghouse.poll835Remittance(
      claim.id,
      externalId,
      Number(claim.billedAmount),
    );

    if (remittance.status !== 'PAID') {
      return this.prisma.insuranceClaim.update({
        where: { id: claimId },
        data: {
          status: 'DENIED',
          denialReason: remittance.message,
          resolvedAt: new Date(),
          metadata: {
            ...meta,
            remittance835: remittance,
          } as unknown as Prisma.InputJsonValue,
        },
        include: { child: true, parent: { include: { user: true } } },
      });
    }

    return this.prisma.insuranceClaim.update({
      where: { id: claimId },
      data: {
        status: 'PAID',
        approvedAmount: remittance.paidAmount,
        paidAmount: remittance.paidAmount,
        resolvedAt: new Date(),
        metadata: {
          ...meta,
          remittance835: remittance,
        } as unknown as Prisma.InputJsonValue,
      },
      include: { child: true, parent: { include: { user: true } } },
    });
  }

  async resubmitClaimForTenant(
    tenantId: string,
    claimId: string,
    editorId: string,
    editorRole?: string,
  ) {
    const claim = await this.prisma.insuranceClaim.findFirst({
      where: { id: claimId, tenantId },
    });
    if (!claim) throw new NotFoundException('Claim not found');

    return this.claimSecurity.createResubmission(
      claimId,
      tenantId,
      { editorId, editorRole },
      { denialReason: claim.denialReason },
    );
  }

  async updateClaimStatusForTenant(
    tenantId: string,
    claimId: string,
    status: ClaimStatus,
    options?: { denialReason?: string; approvedAmount?: number },
  ) {
    const claim = await this.prisma.insuranceClaim.findFirst({
      where: { id: claimId, tenantId },
      include: { child: true, parent: { include: { user: true } } },
    });
    if (!claim) throw new NotFoundException('Claim not found');

    const resolvedStatuses: ClaimStatus[] = ['APPROVED', 'DENIED', 'PAID'];
    return this.prisma.insuranceClaim.update({
      where: { id: claimId },
      data: {
        status,
        denialReason: options?.denialReason,
        approvedAmount: options?.approvedAmount,
        paidAmount: status === 'PAID' ? options?.approvedAmount : undefined,
        resolvedAt: resolvedStatuses.includes(status) ? new Date() : undefined,
      },
      include: { child: true, parent: { include: { user: true } } },
    });
  }
}
