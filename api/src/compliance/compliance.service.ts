import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '../../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { SecurityEventService } from '../security/security-event.service';
import { PrivacyNoticeService } from './privacy-notice.service';

@Injectable()
export class ComplianceService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly securityEvents: SecurityEventService,
    private readonly privacyNotices: PrivacyNoticeService,
  ) {}

  async listConsentsForUser(userId: string) {
    return this.prisma.hipaaConsent.findMany({
      where: { userId },
      orderBy: { grantedAt: 'desc' },
      take: 20,
    });
  }

  async hasMfaEnabled(userId: string): Promise<boolean> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { mfaEnabled: true },
    });
    return user?.mfaEnabled ?? false;
  }

  async hasActiveHipaaConsent(userId: string): Promise<boolean> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { tenantId: true },
    });
    if (!user) return false;
    return this.privacyNotices.hasAcknowledgedActiveNotice(
      userId,
      user.tenantId,
    );
  }

  async grantConsent(
    userId: string,
    data: { consentType: string; version: string },
  ) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new BadRequestException('User not found');

    await this.prisma.hipaaConsent.updateMany({
      where: {
        userId,
        consentType: data.consentType,
        granted: true,
        revokedAt: null,
      },
      data: { granted: false, revokedAt: new Date() },
    });

    const consent = await this.prisma.hipaaConsent.create({
      data: {
        tenantId: user.tenantId,
        userId,
        consentType: data.consentType,
        version: data.version,
        granted: true,
      },
    });

    if (data.consentType === 'HIPAA_PRIVACY') {
      await this.securityEvents.log({
        tenantId: user.tenantId,
        userId,
        eventType: 'CONSENT_GRANTED',
        metadata: { consentType: data.consentType, version: data.version },
      });
    }

    return consent;
  }

  async revokeConsent(userId: string, consentId: string) {
    const row = await this.prisma.hipaaConsent.findFirst({
      where: { id: consentId, userId },
    });
    if (!row) throw new NotFoundException('Consent not found');
    return this.prisma.hipaaConsent.update({
      where: { id: consentId },
      data: { granted: false, revokedAt: new Date() },
    });
  }

  async getPhiAccessReportForUser(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { parent: { include: { children: true } }, therapist: true },
    });
    if (!user) throw new NotFoundException('User not found');

    const documentWhere: Prisma.DocumentWhereInput = {
      tenantId: user.tenantId,
    };
    const phiAuditWhere: Prisma.AuditLogWhereInput = {
      tenantId: user.tenantId,
      metadata: { path: ['phi'], equals: true },
    };

    if (user.parent) {
      const childIds = user.parent.children.map((c) => c.id);
      documentWhere.childId = { in: childIds };
      phiAuditWhere.OR = [
        { actorId: userId },
        {
          entityType: {
            in: ['child', 'document', 'session', 'message_thread'],
          },
          entityId: { in: childIds },
        },
      ];
    } else if (user.therapist) {
      documentWhere.therapistId = user.therapist.id;
      const sessions = await this.prisma.session.findMany({
        where: { therapistId: user.therapist.id },
        select: { id: true },
      });
      const sessionIds = sessions.map((s) => s.id);
      phiAuditWhere.OR = [
        { actorId: userId },
        {
          entityType: { in: ['session', 'document', 'message_thread'] },
          entityId: { in: sessionIds },
        },
      ];
    } else {
      return { documentAccess: [], phiAuditEntries: [] };
    }

    const documents = await this.prisma.document.findMany({
      where: documentWhere,
      select: { id: true, title: true },
    });
    const documentIds = documents.map((d) => d.id);
    const titleById = new Map(documents.map((d) => [d.id, d.title]));

    const documentAccess =
      documentIds.length > 0
        ? await this.prisma.documentAccessLog.findMany({
            where: { documentId: { in: documentIds } },
            orderBy: { accessedAt: 'desc' },
            take: 200,
          })
        : [];

    const phiAuditEntries = await this.prisma.auditLog.findMany({
      where: phiAuditWhere,
      orderBy: { createdAt: 'desc' },
      take: 200,
    });

    return {
      documentAccess: documentAccess.map((row) => ({
        documentId: row.documentId,
        documentTitle: titleById.get(row.documentId),
        action: row.action,
        accessedAt: row.accessedAt,
        userId: row.userId,
      })),
      phiAuditEntries: phiAuditEntries.map((row) => ({
        action: row.action,
        resourceType: row.entityType,
        resourceId: row.entityId,
        createdAt: row.createdAt,
        actorId: row.actorId,
      })),
    };
  }

  getRetentionPolicy() {
    return {
      clinicalRecordsYears: 7,
      billingRecordsYears: 6,
      auditLogsYears: 7,
      securityEventsYears: 7,
      description:
        'Default CMS-aligned retention windows; confirm with legal counsel per tenant.',
    };
  }

  async summarizeRetentionStatus(tenantId: string) {
    const policy = this.getRetentionPolicy();
    const clinicalCutoff = new Date();
    clinicalCutoff.setFullYear(
      clinicalCutoff.getFullYear() - policy.clinicalRecordsYears,
    );
    const billingCutoff = new Date();
    billingCutoff.setFullYear(
      billingCutoff.getFullYear() - policy.billingRecordsYears,
    );

    const [expiredDocuments, expiredClaims, auditLogCount, securityEventCount] =
      await Promise.all([
        this.prisma.document.count({
          where: { tenantId, createdAt: { lt: clinicalCutoff } },
        }),
        this.prisma.insuranceClaim.count({
          where: { tenantId, createdAt: { lt: billingCutoff } },
        }),
        this.prisma.auditLog.count({ where: { tenantId } }),
        this.prisma.securityEvent.count({ where: { tenantId } }),
      ]);

    return {
      policy,
      expiredDocumentsEligibleForPurge: expiredDocuments,
      expiredClaimsEligibleForPurge: expiredClaims,
      auditLogCount,
      securityEventCount,
    };
  }

  async create(data: Record<string, unknown>) {
    void data;
    throw new BadRequestException('Use GraphQL grantConsent');
  }

  async findAll() {
    return this.prisma.hipaaConsent.findMany({ take: 20 });
  }

  async findOne(id: string) {
    const row = await this.prisma.hipaaConsent.findUnique({ where: { id } });
    if (!row) throw new NotFoundException('Consent not found');
    return row;
  }

  async update(id: string, data: Record<string, unknown>) {
    await this.findOne(id);
    return this.prisma.hipaaConsent.update({
      where: { id },
      data: data as Parameters<
        typeof this.prisma.hipaaConsent.update
      >[0]['data'],
    });
  }

  async remove(id: string) {
    void id;
    throw new BadRequestException('HIPAA consent records cannot be deleted');
  }
}
