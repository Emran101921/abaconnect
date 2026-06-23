import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import {
  AuditAction,
  EiBillingQueueStatus,
  EiClearinghouseWorkflow,
  Prisma,
} from '../../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import {
  assertEiBillingRole,
  EiBillingActor,
  resolveAgencyIdForActor,
} from './ei-billing-access.util';
import { EiBillingAuditService } from './ei-billing-audit.service';
import { EiBillingQueueService } from './ei-billing-queue.service';
import { EiBillingValidationService } from './ei-billing-validation.service';
import { EiBillingAdapterRegistry } from './adapters/ei-billing-adapter.registry';
import { computeEiBilledAmount } from './ei-billing.constants';

@Injectable()
export class EiBillingRecordService {
  private readonly logger = new Logger(EiBillingRecordService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly validation: EiBillingValidationService,
    private readonly queue: EiBillingQueueService,
    private readonly audit: EiBillingAuditService,
    private readonly adapters: EiBillingAdapterRegistry,
  ) {}

  async getDashboard(actor: EiBillingActor, agencyId?: string) {
    const resolvedAgencyId = await this.resolveScopedAgency(actor, agencyId);
    const where = this.buildRecordScope(actor, resolvedAgencyId);

    const [total, readyReview, missingInfo, submitted, paid, denied] =
      await Promise.all([
        this.prisma.eiBillingRecord.count({ where }),
        this.prisma.eiBillingRecord.count({
          where: { ...where, queueStatus: 'READY_AGENCY_REVIEW' },
        }),
        this.prisma.eiBillingRecord.count({
          where: { ...where, queueStatus: 'MISSING_INFORMATION' },
        }),
        this.prisma.eiBillingRecord.count({
          where: {
            ...where,
            queueStatus: { in: ['SUBMITTED', 'RESUBMITTED'] },
          },
        }),
        this.prisma.eiBillingRecord.count({
          where: { ...where, queueStatus: 'PAID' },
        }),
        this.prisma.eiBillingRecord.count({
          where: {
            ...where,
            queueStatus: { in: ['DENIED', 'REJECTED', 'CORRECTION_NEEDED'] },
          },
        }),
      ]);

    return {
      totalRecords: total,
      readyAgencyReview: readyReview,
      missingInformation: missingInfo,
      submitted,
      paid,
      denialsAndCorrections: denied,
    };
  }

  async listQueue(
    actor: EiBillingActor,
    filter?: {
      agencyId?: string;
      status?: EiBillingQueueStatus;
      childId?: string;
      take?: number;
    },
  ) {
    const resolvedAgencyId = await this.resolveScopedAgency(
      actor,
      filter?.agencyId,
    );
    const where = {
      ...this.buildRecordScope(actor, resolvedAgencyId),
      ...(filter?.status ? { queueStatus: filter.status } : {}),
      ...(filter?.childId ? { childId: filter.childId } : {}),
    };

    return this.prisma.eiBillingRecord.findMany({
      where,
      take: filter?.take ?? 100,
      orderBy: { updatedAt: 'desc' },
      include: {
        child: { select: { firstName: true, lastName: true } },
        therapist: {
          include: {
            user: { select: { firstName: true, lastName: true } },
          },
        },
        validationIssues: { where: { resolved: false }, take: 5 },
      },
    });
  }

  async getRecord(actor: EiBillingActor, recordId: string) {
    const record = await this.prisma.eiBillingRecord.findFirst({
      where: { id: recordId, tenantId: actor.tenantId },
      include: {
        child: { select: { firstName: true, lastName: true } },
        therapist: {
          include: {
            user: { select: { firstName: true, lastName: true } },
          },
        },
        validationIssues: true,
        denials: true,
        payments: true,
        caseProfile: true,
      },
    });
    if (!record) {
      throw new NotFoundException('EI billing record not found');
    }
    this.assertRecordAccess(actor, record);
    return record;
  }

  async createFromSession(
    actor: EiBillingActor,
    sessionId: string,
    agencyId?: string,
  ) {
    assertEiBillingRole(actor, [
      'BILLING_STAFF',
      'AGENCY_ADMIN',
      'PLATFORM_ADMIN',
    ]);
    const resolvedAgencyId = await resolveAgencyIdForActor(
      this.prisma,
      actor,
      agencyId,
    );

    const session = await this.prisma.session.findFirst({
      where: { id: sessionId, tenantId: actor.tenantId },
      include: { soapNote: true, appointment: true },
    });
    if (!session) {
      throw new NotFoundException('Session not found');
    }

    const existing = await this.prisma.eiBillingRecord.findUnique({
      where: { sessionId },
    });
    if (existing) {
      throw new BadRequestException('Billing record already exists for session');
    }

    const caseProfile = await this.prisma.eiCaseBillingProfile.findUnique({
      where: {
        agencyId_childId: {
          agencyId: resolvedAgencyId,
          childId: session.childId,
        },
      },
    });
    if (!caseProfile) {
      throw new BadRequestException('Case billing profile required before creating record');
    }

    const serviceDate =
      session.checkInAt ?? session.appointment?.scheduledStart ?? new Date();
    const units =
      session.durationMinutes != null
        ? Math.ceil(session.durationMinutes / 15)
        : 0;

    const record = await this.prisma.eiBillingRecord.create({
      data: {
        tenantId: actor.tenantId,
        agencyId: resolvedAgencyId,
        childId: session.childId,
        sessionId: session.id,
        therapistId: session.therapistId,
        caseProfileId: caseProfile.id,
        serviceDate,
        startTime: session.checkInAt,
        endTime: session.checkOutAt,
        units,
        billedAmount: computeEiBilledAmount(units),
        queueStatus: 'DRAFT_INCOMPLETE',
      },
    });

    await this.audit.log(
      actor.tenantId,
      actor.id,
      actor.role,
      AuditAction.EI_BILLING_RECORD_CREATED,
      'EiBillingRecord',
      record.id,
      { sessionId },
      session.childId,
    );

    return this.validateRecord(actor, record.id);
  }

  async autoCreateFromCompletedSession(sessionId: string): Promise<void> {
    try {
      const session = await this.prisma.session.findUnique({
        where: { id: sessionId },
        include: {
          soapNote: true,
          child: true,
          appointment: true,
          therapist: {
            include: {
              user: true,
              agencyLinks: { where: { status: 'ACTIVE' } },
            },
          },
        },
      });
      if (!session || session.status !== 'COMPLETED') {
        return;
      }

      const existing = await this.prisma.eiBillingRecord.findUnique({
        where: { sessionId },
      });
      if (existing) {
        return;
      }

      let caseProfile: { id: string } | null = null;
      let agencyId: string | null = null;
      for (const link of session.therapist.agencyLinks) {
        const profile = await this.prisma.eiCaseBillingProfile.findUnique({
          where: {
            agencyId_childId: {
              agencyId: link.agencyId,
              childId: session.childId,
            },
          },
        });
        if (profile) {
          caseProfile = profile;
          agencyId = link.agencyId;
          break;
        }
      }
      if (!caseProfile || !agencyId) {
        return;
      }

      const serviceDate =
        session.checkInAt ?? session.appointment?.scheduledStart ?? new Date();
      const units =
        session.durationMinutes != null
          ? Math.ceil(session.durationMinutes / 15)
          : 0;

      const record = await this.prisma.eiBillingRecord.create({
        data: {
          tenantId: session.tenantId,
          agencyId,
          childId: session.childId,
          sessionId: session.id,
          therapistId: session.therapistId,
          caseProfileId: caseProfile.id,
          serviceDate,
          startTime: session.checkInAt,
          endTime: session.checkOutAt,
          units,
          billedAmount: computeEiBilledAmount(units),
          queueStatus: 'DRAFT_INCOMPLETE',
        },
      });

      const actor: EiBillingActor = {
        id: session.therapist.userId,
        tenantId: session.tenantId,
        role: 'THERAPIST',
        therapistId: session.therapistId,
      };

      await this.audit.log(
        session.tenantId,
        session.therapist.userId,
        'THERAPIST',
        AuditAction.EI_BILLING_RECORD_CREATED,
        'EiBillingRecord',
        record.id,
        { sessionId, autoCreated: true },
        session.childId,
      );

      await this.validateRecord(actor, record.id);
    } catch (error) {
      this.logger.warn(
        `autoCreateFromCompletedSession failed for ${sessionId}: ${error instanceof Error ? error.message : String(error)}`,
      );
    }
  }

  async validateRecord(actor: EiBillingActor, recordId: string) {
    const record = await this.getRecord(actor, recordId);
    const context = await this.buildValidationContext(record);

    const issues = this.validation.validate(context);
    const nextStatus = this.validation.deriveQueueStatus(issues);

    await this.prisma.eiBillingValidationIssue.deleteMany({
      where: { recordId: record.id },
    });
    if (issues.length) {
      await this.prisma.eiBillingValidationIssue.createMany({
        data: issues.map((issue) => ({
          recordId: record.id,
          code: issue.code,
          severity: issue.severity,
          message: issue.message,
        })),
      });
    }

    const updated = await this.prisma.eiBillingRecord.update({
      where: { id: record.id },
      data: {
        queueStatus: nextStatus,
        validationSnapshot: JSON.parse(
          JSON.stringify({
            validatedAt: new Date().toISOString(),
            issueCount: issues.length,
            issues,
          }),
        ) as Prisma.InputJsonValue,
      },
      include: { validationIssues: true },
    });

    await this.audit.log(
      actor.tenantId,
      actor.id,
      actor.role,
      AuditAction.EI_BILLING_RECORD_VALIDATED,
      'EiBillingRecord',
      record.id,
      { issueCount: issues.length, queueStatus: nextStatus },
      record.childId,
    );

    return updated;
  }

  async transitionQueue(
    actor: EiBillingActor,
    recordId: string,
    targetStatus: EiBillingQueueStatus,
  ) {
    const record = await this.getRecord(actor, recordId);
    this.queue.assertTransitionAllowed(record.queueStatus, targetStatus);
    this.queue.assertRoleForTargetStatus(actor, targetStatus);

    if (
      targetStatus === 'READY_BILLING_VALIDATION' ||
      targetStatus === 'READY_AUTHORIZED_SUBMISSION'
    ) {
      const refreshed = await this.validateRecord(actor, recordId);
      if (refreshed.validationIssues.some((i) => i.severity === 'ERROR')) {
        throw new BadRequestException(
          'Cannot advance queue while validation errors remain',
        );
      }
    }

    const updated = await this.prisma.eiBillingRecord.update({
      where: { id: recordId },
      data: {
        queueStatus: targetStatus,
        reviewedById:
          targetStatus === 'READY_AUTHORIZED_SUBMISSION' ? actor.id : undefined,
        reviewedAt:
          targetStatus === 'READY_AUTHORIZED_SUBMISSION'
            ? new Date()
            : undefined,
      },
    });

    await this.queue.logTransition(
      actor.tenantId,
      actor,
      recordId,
      record.queueStatus,
      targetStatus,
      record.childId,
    );

    return updated;
  }

  async lockSessionForBilling(actor: EiBillingActor, sessionId: string) {
    assertEiBillingRole(actor, [
      'BILLING_STAFF',
      'AGENCY_ADMIN',
      'PLATFORM_ADMIN',
    ]);
    const record = await this.prisma.eiBillingRecord.findFirst({
      where: { sessionId, tenantId: actor.tenantId },
    });
    if (!record) {
      throw new NotFoundException('Create billing record before locking session');
    }

    const validated = await this.validateRecord(actor, record.id);
    if (validated.validationIssues.some((i) => i.severity === 'ERROR')) {
      throw new BadRequestException(
        'Resolve validation errors before locking for billing',
      );
    }

    const locked = await this.prisma.eiBillingRecord.update({
      where: { id: record.id },
      data: { lockedAt: new Date() },
    });

    await this.audit.log(
      actor.tenantId,
      actor.id,
      actor.role,
      AuditAction.EI_BILLING_RECORD_LOCKED,
      'EiBillingRecord',
      record.id,
      { sessionId },
      record.childId,
    );

    return locked;
  }

  async exportRecord(
    actor: EiBillingActor,
    recordId: string,
    workflow: EiClearinghouseWorkflow,
    authorizedConfirm: boolean,
  ) {
    await this.assertSubmissionSafeguards(actor, recordId, authorizedConfirm);
    const record = await this.getRecord(actor, recordId);
    const config = await this.getActiveClearinghouseConfig(
      actor.tenantId,
      record.agencyId,
      workflow,
    );

    const adapter = this.adapters.getAdapter(workflow);
    const result = await adapter.export(record, config);

    await this.audit.log(
      actor.tenantId,
      actor.id,
      actor.role,
      AuditAction.EI_BILLING_RECORD_EXPORTED,
      'EiBillingRecord',
      recordId,
      { workflow, artifactType: result.artifactType },
      record.childId,
    );

    return result;
  }

  async submitRecord(
    actor: EiBillingActor,
    recordId: string,
    workflow: EiClearinghouseWorkflow,
    authorizedConfirm: boolean,
  ) {
    assertEiBillingRole(actor, ['BILLING_STAFF', 'PLATFORM_ADMIN']);
    await this.assertSubmissionSafeguards(actor, recordId, authorizedConfirm);

    const record = await this.getRecord(actor, recordId);
    if (record.queueStatus !== 'READY_AUTHORIZED_SUBMISSION') {
      throw new ForbiddenException(
        'Record must be in READY_AUTHORIZED_SUBMISSION status',
      );
    }

    const config = await this.getActiveClearinghouseConfig(
      actor.tenantId,
      record.agencyId,
      workflow,
    );
    const adapter = this.adapters.getAdapter(workflow);
    const result = await adapter.submit(record, config);

    const updated = await this.prisma.eiBillingRecord.update({
      where: { id: recordId },
      data: {
        queueStatus: result.accepted ? 'SUBMITTED' : 'REJECTED',
        submittedAt: new Date(),
        externalReferenceId: result.externalReferenceId,
        clearinghouseWorkflow: workflow,
      },
    });

    await this.audit.log(
      actor.tenantId,
      actor.id,
      actor.role,
      AuditAction.EI_BILLING_RECORD_SUBMITTED,
      'EiBillingRecord',
      recordId,
      {
        workflow,
        accepted: result.accepted,
        externalReferenceId: result.externalReferenceId,
      },
      record.childId,
    );

    return { record: updated, result };
  }

  async getReports(actor: EiBillingActor, agencyId?: string) {
    const resolvedAgencyId = await this.resolveScopedAgency(actor, agencyId);
    const where = this.buildRecordScope(actor, resolvedAgencyId);
    const grouped = await this.prisma.eiBillingRecord.groupBy({
      by: ['queueStatus'],
      where,
      _count: { _all: true },
      _sum: { billedAmount: true, allowedAmount: true },
    });
    return grouped.map((row) => ({
      status: row.queueStatus,
      count: row._count._all,
      billedTotal: row._sum.billedAmount,
      allowedTotal: row._sum.allowedAmount,
    }));
  }

  private async assertSubmissionSafeguards(
    actor: EiBillingActor,
    recordId: string,
    authorizedConfirm: boolean,
  ) {
    if (!authorizedConfirm) {
      throw new ForbiddenException(
        'Explicit authorized confirmation required for export/submit',
      );
    }

    const record = await this.getRecord(actor, recordId);
    const agencyProfile = await this.prisma.eiAgencyBillingProfile.findUnique({
      where: { agencyId: record.agencyId },
    });
    if (
      !agencyProfile?.enrollmentComplete ||
      !agencyProfile.baaSignedAt ||
      !agencyProfile.npi ||
      !agencyProfile.medicaidProviderId
    ) {
      throw new ForbiddenException(
        'Agency enrollment profile incomplete or BAA not signed',
      );
    }

    const enrollment = await this.prisma.eiProviderEnrollment.findUnique({
      where: {
        agencyId_therapistId: {
          agencyId: record.agencyId,
          therapistId: record.therapistId,
        },
      },
    });
    if (
      !enrollment?.isActive ||
      enrollment.credentialStatus !== 'ACTIVE' ||
      enrollment.medicaidEnrollmentStatus !== 'ENROLLED'
    ) {
      throw new ForbiddenException('Provider credentials not active for submission');
    }

    const config = await this.prisma.eiClearinghouseConfig.findFirst({
      where: {
        tenantId: actor.tenantId,
        OR: [{ agencyId: record.agencyId }, { agencyId: null }],
        isActive: true,
      },
    });
    if (!config?.baaSignedAt) {
      throw new ForbiddenException(
        'Clearinghouse configuration requires signed BAA before transmission',
      );
    }
  }

  private async getActiveClearinghouseConfig(
    tenantId: string,
    agencyId: string,
    workflow: EiClearinghouseWorkflow,
  ) {
    const config = await this.prisma.eiClearinghouseConfig.findFirst({
      where: {
        tenantId,
        workflow,
        isActive: true,
        OR: [{ agencyId }, { agencyId: null }],
      },
      orderBy: { updatedAt: 'desc' },
    });
    if (!config) {
      throw new BadRequestException(
        `No active clearinghouse config for workflow ${workflow}`,
      );
    }
    return config;
  }

  private async buildValidationContext(
    record: Awaited<ReturnType<EiBillingRecordService['getRecord']>>,
  ) {
    const [session, agencyProfile, providerEnrollment, caseProfile, duplicate] =
      await Promise.all([
        record.sessionId
          ? this.prisma.session.findUnique({
              where: { id: record.sessionId },
              include: { soapNote: true },
            })
          : null,
        this.prisma.eiAgencyBillingProfile.findUnique({
          where: { agencyId: record.agencyId },
        }),
        this.prisma.eiProviderEnrollment.findUnique({
          where: {
            agencyId_therapistId: {
              agencyId: record.agencyId,
              therapistId: record.therapistId,
            },
          },
        }),
        this.prisma.eiCaseBillingProfile.findUnique({
          where: { id: record.caseProfileId },
        }),
        record.sessionId
          ? this.prisma.eiBillingRecord
              .count({
                where: {
                  sessionId: record.sessionId,
                  id: { not: record.id },
                },
              })
              .then((c) => c > 0)
          : false,
      ]);

    return {
      record,
      session,
      agencyProfile,
      providerEnrollment,
      caseProfile,
      duplicateSessionBilling: duplicate,
    };
  }

  private buildRecordScope(actor: EiBillingActor, agencyId?: string) {
    const scope: Prisma.EiBillingRecordWhereInput = {
      tenantId: actor.tenantId,
    };
    if (agencyId) {
      scope.agencyId = agencyId;
    }
    if (actor.role === 'THERAPIST' && actor.therapistId) {
      scope.therapistId = actor.therapistId;
    }
    if (actor.role === 'SERVICE_COORDINATOR') {
      scope.caseProfile = {
        scReferenceNumber: { not: null },
      };
    }
    return scope;
  }

  private async resolveScopedAgency(actor: EiBillingActor, agencyId?: string) {
    if (actor.role === 'PLATFORM_ADMIN') {
      return agencyId;
    }
    return resolveAgencyIdForActor(this.prisma, actor, agencyId);
  }

  private assertRecordAccess(
    actor: EiBillingActor,
    record: { agencyId: string; therapistId: string; childId: string },
  ) {
    if (actor.role === 'PLATFORM_ADMIN' || actor.role === 'BILLING_STAFF') {
      return;
    }
    if (actor.role === 'AGENCY_ADMIN' && actor.agencyId === record.agencyId) {
      return;
    }
    if (
      actor.role === 'THERAPIST' &&
      actor.therapistId === record.therapistId
    ) {
      return;
    }
    if (actor.role === 'SERVICE_COORDINATOR') {
      return;
    }
    throw new ForbiddenException('Access denied to EI billing record');
  }
}
