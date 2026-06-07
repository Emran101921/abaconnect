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
import { PrismaService } from '../prisma/prisma.service';
import { ClearinghouseService } from './clearinghouse.service';
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

    return this.prisma.insuranceClaim.create({
      data: {
        tenantId: parent.tenantId,
        parentId: parent.id,
        childId: child.id,
        payerName: data.payerName,
        billedAmount: data.billedAmount,
        serviceDate: data.serviceDate,
        status: 'SUBMITTED',
        submittedAt: new Date(),
      },
      include: { child: true },
    });
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

    const claim = await this.prisma.insuranceClaim.create({
      data: {
        tenantId: session.tenantId,
        parentId: parent.id,
        childId: session.childId,
        sessionId: session.id,
        payerName: parent.insuranceProvider ?? 'Demo Payer',
        billedAmount,
        serviceDate: session.appointment.scheduledStart,
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
    const nextStatus: ClaimStatus =
      result.status === 'ACCEPTED' ? 'SUBMITTED' : 'DENIED';

    return this.prisma.insuranceClaim.update({
      where: { id: claimId },
      data: {
        status: nextStatus,
        submittedAt: result.status === 'ACCEPTED' ? new Date() : undefined,
        denialReason: result.status === 'REJECTED' ? result.message : undefined,
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

  async update(id: string, data: Record<string, unknown>) {
    await this.findOne(id);
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

  async getClaimsPipelineForTenant(tenantId: string) {
    const [
      draftCount,
      submittedCount,
      pendingCount,
      paidCount,
      deniedCount,
      recentClaims,
    ] = await Promise.all([
      this.prisma.insuranceClaim.count({
        where: { tenantId, status: 'DRAFT' },
      }),
      this.prisma.insuranceClaim.count({
        where: { tenantId, status: 'SUBMITTED' },
      }),
      this.prisma.insuranceClaim.count({
        where: {
          tenantId,
          status: { in: ['PENDING', 'UNDER_REVIEW', 'APPROVED'] },
        },
      }),
      this.prisma.insuranceClaim.count({
        where: { tenantId, status: 'PAID' },
      }),
      this.prisma.insuranceClaim.count({
        where: { tenantId, status: 'DENIED' },
      }),
      this.prisma.insuranceClaim.findMany({
        where: { tenantId },
        include: { child: true },
        orderBy: { createdAt: 'desc' },
        take: 10,
      }),
    ]);

    return {
      summary: {
        draftCount,
        submittedCount,
        pendingCount,
        paidCount,
        deniedCount,
      },
      recentClaims,
    };
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
