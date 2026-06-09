import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '../../generated/prisma/client';
import { AuditService } from '../audit/audit.service';
import { PhiAuditService } from '../audit/phi-audit.service';
import {
  DateRangeFilter,
  priorPeriodBounds,
  prismaBoundsRange,
  prismaDateRange,
  resolveAnalyticsBounds,
  ResolvedDateBounds,
} from '../common/date-range.util';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.service';
import { EarlyInterventionScoringService } from './early-intervention-scoring.service';
import {
  buildEarlyInterventionQuestionsJson,
  buildSanitizedEiSectionAnswers,
  EARLY_INTERVENTION_TEMPLATE_NAME,
} from './early-intervention-template';

@Injectable()
export class ScreeningsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly eiScoring: EarlyInterventionScoringService,
    private readonly audit: AuditService,
    private readonly phiAudit: PhiAuditService,
    private readonly notifications: NotificationsService,
  ) {}

  async ensureEarlyInterventionTemplate(tenantId: string) {
    const existing = await this.prisma.screeningTemplate.findFirst({
      where: { tenantId, therapyType: 'EARLY_INTERVENTION', isActive: true },
    });
    if (existing) return existing;

    const eiQuestions = buildEarlyInterventionQuestionsJson();
    return this.prisma.screeningTemplate.create({
      data: {
        tenantId,
        name: EARLY_INTERVENTION_TEMPLATE_NAME,
        description:
          'Comprehensive parent screening for Early Intervention services (sections A–G).',
        therapyType: 'EARLY_INTERVENTION',
        version: 1,
        questions: JSON.parse(
          JSON.stringify(eiQuestions),
        ) as Prisma.InputJsonValue,
        scoringRules: {
          engine: 'early_intervention_v1',
        } as Prisma.InputJsonValue,
        isActive: true,
      },
    });
  }

  async listTemplatesForTenant(tenantId: string) {
    await this.ensureEarlyInterventionTemplate(tenantId);
    return this.prisma.screeningTemplate.findMany({
      where: { tenantId, isActive: true },
      orderBy: [{ therapyType: 'asc' }, { version: 'desc' }],
    });
  }

  async saveDraftForParent(
    userId: string,
    data: {
      templateId: string;
      childId: string;
      responses: Record<string, unknown>;
      draftId?: string;
    },
  ) {
    const parent = await this.requireParent(userId);
    const child = await this.requireChild(parent.id, data.childId);
    const template = await this.requireTemplate(
      parent.tenantId,
      data.templateId,
    );

    if (data.draftId) {
      const existing = await this.prisma.screeningResponse.findFirst({
        where: {
          id: data.draftId,
          parentId: parent.id,
          isDraft: true,
        },
      });
      if (!existing) {
        throw new NotFoundException('Draft screening not found');
      }
      return this.prisma.screeningResponse.update({
        where: { id: existing.id },
        data: {
          responses: data.responses as Prisma.InputJsonValue,
          completedAt: new Date(),
        },
        include: { template: true, child: true },
      });
    }

    const priorDraft = await this.prisma.screeningResponse.findFirst({
      where: {
        templateId: template.id,
        childId: child.id,
        parentId: parent.id,
        isDraft: true,
      },
    });
    if (priorDraft) {
      return this.prisma.screeningResponse.update({
        where: { id: priorDraft.id },
        data: {
          responses: data.responses as Prisma.InputJsonValue,
          completedAt: new Date(),
        },
        include: { template: true, child: true },
      });
    }

    return this.prisma.screeningResponse.create({
      data: {
        templateId: template.id,
        childId: child.id,
        parentId: parent.id,
        tenantId: parent.tenantId,
        responses: data.responses as Prisma.InputJsonValue,
        isDraft: true,
        score: null,
        riskLevel: null,
        recommendations: [],
      },
      include: { template: true, child: true },
    });
  }

  async submitResponseForParent(
    userId: string,
    data: {
      templateId: string;
      childId: string;
      responses: Record<string, unknown>;
      consentGranted?: boolean;
      draftId?: string;
    },
    actorId?: string,
  ) {
    const parent = await this.requireParent(userId);
    const child = await this.requireChild(parent.id, data.childId);
    const template = await this.requireTemplate(
      parent.tenantId,
      data.templateId,
    );

    const scored = this.scoreForTemplate(template, data.responses);
    const consentGrantedAt = data.consentGranted ? new Date() : null;

    let row;
    if (data.draftId) {
      const draft = await this.prisma.screeningResponse.findFirst({
        where: { id: data.draftId, parentId: parent.id, isDraft: true },
      });
      if (!draft) throw new NotFoundException('Draft screening not found');
      row = await this.prisma.screeningResponse.update({
        where: { id: draft.id },
        data: {
          responses: data.responses as Prisma.InputJsonValue,
          score: scored.score,
          riskLevel: scored.riskLevel,
          recommendations: scored.recommendations as Prisma.InputJsonValue,
          isDraft: false,
          consentGrantedAt,
          completedAt: new Date(),
        },
        include: { template: true, child: true },
      });
    } else {
      row = await this.prisma.screeningResponse.create({
        data: {
          templateId: template.id,
          childId: child.id,
          parentId: parent.id,
          tenantId: parent.tenantId,
          responses: data.responses as Prisma.InputJsonValue,
          score: scored.score,
          riskLevel: scored.riskLevel,
          recommendations: scored.recommendations as Prisma.InputJsonValue,
          isDraft: false,
          consentGrantedAt,
        },
        include: { template: true, child: true },
      });
    }

    await this.audit.log({
      tenantId: parent.tenantId,
      actorId: actorId ?? userId,
      action: 'CREATE',
      resourceType: 'ScreeningResponse',
      resourceId: row.id,
      metadata: {
        templateId: template.id,
        childId: child.id,
        riskLevel: scored.riskLevel,
        isDraft: false,
        consentGranted: Boolean(data.consentGranted),
      },
    });

    if (data.consentGranted) {
      await this.audit.log({
        tenantId: parent.tenantId,
        actorId: actorId ?? userId,
        action: 'CONSENT_GRANTED',
        resourceType: 'ScreeningResponse',
        resourceId: row.id,
        metadata: { consentType: 'SHARE_WITH_PROVIDERS' },
      });
    }

    return row;
  }

  async listHistoryForParentUser(userId: string) {
    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (!parent) return [];

    return this.prisma.screeningResponse.findMany({
      where: { parentId: parent.id, isDraft: false },
      include: { template: true, child: true },
      orderBy: { completedAt: 'desc' },
      take: 50,
    });
  }

  async getResponseForParent(userId: string, responseId: string) {
    const parent = await this.requireParent(userId);
    const row = await this.prisma.screeningResponse.findFirst({
      where: {
        id: responseId,
        parentId: parent.id,
        isDraft: false,
      },
      include: { template: true, child: true },
    });
    if (!row) throw new NotFoundException('Screening not found');
    await this.phiAudit.logPhiAccess({
      tenantId: parent.tenantId,
      actorId: userId,
      action: 'READ',
      resourceType: 'screening',
      resourceId: row.id,
    });
    return row;
  }

  async getDraftForParent(userId: string, templateId: string, childId: string) {
    const parent = await this.requireParent(userId);
    return this.prisma.screeningResponse.findFirst({
      where: {
        parentId: parent.id,
        templateId,
        childId,
        isDraft: true,
      },
      include: { template: true, child: true },
    });
  }

  async getResponseForTenant(
    tenantId: string,
    responseId: string,
    actorId?: string,
  ) {
    const row = await this.prisma.screeningResponse.findFirst({
      where: { id: responseId, tenantId, isDraft: false },
      include: {
        template: true,
        child: {
          select: {
            id: true,
            firstName: true,
            lastName: true,
            dateOfBirth: true,
            gender: true,
            primaryLanguage: true,
            insuranceType: true,
            hadEarlyIntervention: true,
          },
        },
      },
    });
    if (!row) throw new NotFoundException('Screening not found');

    if (actorId) {
      await this.audit.log({
        tenantId,
        actorId,
        action: 'READ',
        resourceType: 'ScreeningResponse',
        resourceId: row.id,
        metadata: {
          templateId: row.templateId,
          riskLevel: row.riskLevel,
        },
      });
    }

    return row;
  }

  async requestEarlyInterventionEvaluation(
    userId: string,
    screeningResponseId: string,
  ) {
    const parent = await this.requireParent(userId);
    const row = await this.prisma.screeningResponse.findFirst({
      where: {
        id: screeningResponseId,
        parentId: parent.id,
        isDraft: false,
      },
      include: { template: true, child: true },
    });
    if (!row) {
      throw new NotFoundException('Screening not found');
    }

    if (row.evaluationRequestedAt) {
      throw new ConflictException(
        'Evaluation already requested for this screening',
      );
    }

    const recommendations = Array.isArray(row.recommendations)
      ? (row.recommendations as Array<{ code?: string }>)
      : [];
    const serviceCodes = recommendations
      .map((rec) => rec.code)
      .filter((code): code is string => Boolean(code));

    const requestedAt = new Date();
    const updated = await this.prisma.screeningResponse.update({
      where: { id: row.id },
      data: { evaluationRequestedAt: requestedAt },
      include: { template: true, child: true },
    });

    await this.audit.log({
      tenantId: parent.tenantId,
      actorId: userId,
      action: 'CREATE',
      resourceType: 'EvaluationRequest',
      resourceId: row.id,
      metadata: {
        screeningResponseId: row.id,
        childId: row.childId,
        serviceCodes,
        riskLevel: row.riskLevel,
      },
    });

    const staffUsers = await this.prisma.user.findMany({
      where: {
        tenantId: parent.tenantId,
        role: { in: ['PLATFORM_ADMIN', 'AGENCY_ADMIN'] },
        isActive: true,
      },
      select: { id: true },
    });

    await Promise.all(
      staffUsers.map((staff) =>
        this.notifications.createForUser(staff.id, {
          title: 'Early Intervention evaluation requested',
          body: 'A parent requested an evaluation following an EI screening. Review the screening in analytics.',
          data: {
            type: 'EI_EVALUATION_REQUEST',
            screeningResponseId: row.id,
            childId: row.childId,
          },
        }),
      ),
    );

    return {
      id: updated.id,
      screeningResponseId: updated.id,
      childId: updated.childId,
      requestedAt,
      serviceCodes,
    };
  }

  buildAnalyticsScreeningDetail(row: {
    id: string;
    completedAt: Date;
    score?: unknown | null;
    riskLevel?: string | null;
    responses: unknown;
    recommendations?: unknown;
    consentGrantedAt?: Date | null;
    evaluationRequestedAt?: Date | null;
    template?: { name: string; therapyType: string } | null;
    child?: {
      firstName: string;
      lastName: string;
      dateOfBirth: Date;
      gender?: string | null;
      primaryLanguage?: string | null;
      insuranceType?: string | null;
      hadEarlyIntervention?: boolean | null;
    } | null;
  }) {
    const responses =
      row.responses && typeof row.responses === 'object'
        ? (row.responses as Record<string, unknown>)
        : {};
    const isEi =
      row.template?.therapyType === 'EARLY_INTERVENTION' ||
      row.template?.name === EARLY_INTERVENTION_TEMPLATE_NAME;

    return {
      id: row.id,
      completedAt: row.completedAt,
      childName: row.child
        ? `${row.child.firstName} ${row.child.lastName}`
        : undefined,
      templateName: row.template?.name,
      score: row.score != null ? Number(row.score) : undefined,
      riskLevel: row.riskLevel ?? undefined,
      responsesJson: JSON.stringify(row.responses ?? {}),
      recommendationsJson: JSON.stringify(row.recommendations ?? []),
      consentGrantedAt: row.consentGrantedAt ?? undefined,
      evaluationRequestedAt: row.evaluationRequestedAt ?? undefined,
      childProfileSummaryJson: row.child
        ? JSON.stringify({
            dateOfBirth: row.child.dateOfBirth.toISOString().slice(0, 10),
            gender: row.child.gender ?? null,
            primaryLanguage: row.child.primaryLanguage ?? null,
            insuranceType: row.child.insuranceType ?? null,
            hadEarlyIntervention: row.child.hadEarlyIntervention ?? null,
          })
        : undefined,
      sectionAnswersJson: isEi
        ? JSON.stringify(buildSanitizedEiSectionAnswers(responses))
        : undefined,
    };
  }

  async listAnalyticsScreeningsForTenant(
    tenantId: string,
    riskLevel?: string,
    limit = 50,
    dateRange?: { fromDate?: Date; toDate?: Date },
    actorId?: string,
  ) {
    if (actorId) {
      await this.phiAudit.logPhiAccess({
        tenantId,
        actorId,
        action: 'EXPORT',
        resourceType: 'screening_analytics',
      });
    }
    const completedAt = prismaDateRange('completedAt', dateRange ?? {});
    return this.prisma.screeningResponse.findMany({
      where: {
        tenantId,
        isDraft: false,
        ...(riskLevel ? { riskLevel } : {}),
        ...completedAt,
      },
      include: { template: true, child: true },
      orderBy: { completedAt: 'desc' },
      take: limit,
    });
  }

  async getScreeningFunnelForTenant(
    tenantId: string,
    dateRange?: DateRangeFilter,
  ) {
    const currentBounds = resolveAnalyticsBounds(dateRange);
    const priorBounds = priorPeriodBounds(currentBounds.from, currentBounds.to);

    const [current, prior, recentScreenings] = await Promise.all([
      this.queryScreeningFunnelCounts(tenantId, currentBounds),
      this.queryScreeningFunnelCounts(tenantId, priorBounds),
      this.prisma.screeningResponse.findMany({
        where: {
          tenantId,
          isDraft: false,
          ...prismaBoundsRange('completedAt', currentBounds),
        },
        include: { template: true, child: true },
        orderBy: { completedAt: 'desc' },
        take: 10,
      }),
    ]);

    return {
      summary: {
        ...current,
        priorCompletedCount: prior.completedCount,
        priorLowRiskCount: prior.lowRiskCount,
        priorModerateRiskCount: prior.moderateRiskCount,
        priorHighRiskCount: prior.highRiskCount,
      },
      recentScreenings,
    };
  }

  private async queryScreeningFunnelCounts(
    tenantId: string,
    bounds: ResolvedDateBounds,
  ) {
    const baseWhere = {
      tenantId,
      isDraft: false,
      ...prismaBoundsRange('completedAt', bounds),
    };
    const [completedCount, lowRiskCount, moderateRiskCount, highRiskCount] =
      await Promise.all([
        this.prisma.screeningResponse.count({ where: baseWhere }),
        this.prisma.screeningResponse.count({
          where: { ...baseWhere, riskLevel: 'LOW' },
        }),
        this.prisma.screeningResponse.count({
          where: { ...baseWhere, riskLevel: 'MODERATE' },
        }),
        this.prisma.screeningResponse.count({
          where: { ...baseWhere, riskLevel: 'HIGH' },
        }),
      ]);

    return {
      completedCount,
      lowRiskCount,
      moderateRiskCount,
      highRiskCount,
    };
  }

  private scoreForTemplate(
    template: { name: string; therapyType: string },
    responses: Record<string, unknown>,
  ) {
    if (
      template.therapyType === 'EARLY_INTERVENTION' ||
      template.name === EARLY_INTERVENTION_TEMPLATE_NAME
    ) {
      const result = this.eiScoring.score(responses);
      return {
        score: result.score,
        riskLevel: result.riskLevel,
        recommendations: result.recommendations,
      };
    }

    const score = this.scoreResponses(responses);
    return {
      score,
      riskLevel: this.riskLevelFromScore(score),
      recommendations: [],
    };
  }

  private scoreResponses(responses: Record<string, unknown>) {
    let total = 0;
    let count = 0;
    for (const value of Object.values(responses)) {
      if (typeof value === 'number') {
        total += value;
        count += 1;
      } else if (value === true) {
        total += 1;
        count += 1;
      } else if (value === false) {
        count += 1;
      }
    }
    if (count === 0) return null;
    return Number((total / count).toFixed(2));
  }

  private riskLevelFromScore(score: number | null) {
    if (score == null) return null;
    if (score >= 0.7) return 'HIGH';
    if (score >= 0.4) return 'MODERATE';
    return 'LOW';
  }

  private async requireParent(userId: string) {
    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (!parent) {
      throw new BadRequestException('Parent profile not found');
    }
    return parent;
  }

  private async requireChild(parentId: string, childId: string) {
    const child = await this.prisma.child.findFirst({
      where: { id: childId, parentId },
    });
    if (!child) {
      throw new NotFoundException('Child not found');
    }
    return child;
  }

  private async requireTemplate(tenantId: string, templateId: string) {
    const template = await this.prisma.screeningTemplate.findFirst({
      where: { id: templateId, tenantId },
    });
    if (!template) {
      throw new NotFoundException('Screening template not found');
    }
    return template;
  }

  async create(data: Record<string, unknown>) {
    void data;
    throw new BadRequestException('Use GraphQL submitScreening');
  }

  async findAll() {
    return this.prisma.screeningTemplate.findMany({ take: 50 });
  }

  async findOne(id: string) {
    const row = await this.prisma.screeningTemplate.findUnique({
      where: { id },
    });
    if (!row) {
      throw new NotFoundException('Screening template not found');
    }
    return row;
  }

  async update(id: string, data: Record<string, unknown>) {
    await this.findOne(id);
    return this.prisma.screeningTemplate.update({
      where: { id },
      data: data as Parameters<
        typeof this.prisma.screeningTemplate.update
      >[0]['data'],
    });
  }

  async remove(id: string) {
    await this.findOne(id);
    await this.prisma.screeningResponse.deleteMany({
      where: { templateId: id },
    });
    await this.prisma.screeningTemplate.delete({ where: { id } });
    return { id, deleted: true };
  }
}
