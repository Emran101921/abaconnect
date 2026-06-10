import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { AuditAction } from '../../generated/prisma/client';
import { AuditService } from '../audit/audit.service';
import { PrismaService } from '../prisma/prisma.service';
import { SecurityEventService } from '../security/security-event.service';
import {
  ACKNOWLEDGMENT_CHECKBOX_TEXT,
  ACKNOWLEDGMENT_SHORT_TEXT,
  buildDefaultNoticeOfPrivacyPractices,
  buildDefaultPrivacyPolicy,
} from './privacy-notice.content';

export interface PrivacyClientContext {
  ipAddress?: string;
  userAgent?: string;
  appVersion?: string;
  platform?: string;
  deviceId?: string;
}

@Injectable()
export class PrivacyNoticeService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly securityEvents: SecurityEventService,
  ) {}

  async getActiveNotice(tenantId?: string | null) {
    const notice = await this.prisma.privacyNoticeVersion.findFirst({
      where: {
        isActive: true,
        OR: [{ tenantId: tenantId ?? undefined }, { tenantId: null }],
      },
      orderBy: [{ tenantId: 'desc' }, { effectiveDate: 'desc' }],
    });
    if (!notice) {
      throw new NotFoundException(
        'No active Notice of Privacy Practices is published',
      );
    }
    return notice;
  }

  async getActiveNoticeSummary(tenantId?: string | null) {
    const notice = await this.getActiveNotice(tenantId);
    return {
      id: notice.id,
      versionNumber: notice.versionNumber,
      title: notice.title,
      effectiveDate: notice.effectiveDate,
      shortAcknowledgmentText: ACKNOWLEDGMENT_SHORT_TEXT,
      checkboxText: ACKNOWLEDGMENT_CHECKBOX_TEXT,
    };
  }

  async getFullNotice(tenantId?: string | null) {
    const notice = await this.getActiveNotice(tenantId);
    return {
      id: notice.id,
      versionNumber: notice.versionNumber,
      title: notice.title,
      effectiveDate: notice.effectiveDate,
      fullNoticeText: notice.fullNoticeText,
    };
  }

  async getPrivacyPolicy(tenantId?: string | null) {
    const notice = await this.getActiveNotice(tenantId);
    return {
      id: notice.id,
      versionNumber: notice.versionNumber,
      effectiveDate: notice.effectiveDate,
      privacyPolicyText: notice.privacyPolicyText,
    };
  }

  async hasAcknowledgedActiveNotice(
    userId: string,
    tenantId: string,
  ): Promise<boolean> {
    let active: { id: string };
    try {
      active = await this.getActiveNotice(tenantId);
    } catch {
      return false;
    }
    const ack = await this.prisma.hipaaNoticeAcknowledgment.findFirst({
      where: { userId, noticeVersionId: active.id },
      orderBy: { acknowledgedAt: 'desc' },
    });
    return ack != null;
  }

  async getAcknowledgmentStatus(userId: string, tenantId: string) {
    let active: Awaited<ReturnType<typeof this.getActiveNotice>>;
    try {
      active = await this.getActiveNotice(tenantId);
    } catch {
      return {
        required: false,
        acknowledged: true,
        activeVersion: null,
        acknowledgedAt: null,
      };
    }
    const ack = await this.prisma.hipaaNoticeAcknowledgment.findFirst({
      where: { userId, noticeVersionId: active.id },
      orderBy: { acknowledgedAt: 'desc' },
    });
    return {
      required: true,
      acknowledged: ack != null,
      activeVersion: active.versionNumber,
      activeNoticeId: active.id,
      acknowledgedAt: ack?.acknowledgedAt ?? null,
      lastAcknowledgedVersion: ack?.noticeVersion ?? null,
    };
  }

  async acknowledgeNotice(userId: string, ctx?: PrivacyClientContext) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new BadRequestException('User not found');

    const notice = await this.getActiveNotice(user.tenantId);
    const snapshot = `${ACKNOWLEDGMENT_SHORT_TEXT}\n\n${ACKNOWLEDGMENT_CHECKBOX_TEXT}`;

    const acknowledgment = await this.prisma.hipaaNoticeAcknowledgment.create({
      data: {
        tenantId: user.tenantId,
        userId,
        noticeVersionId: notice.id,
        noticeVersion: notice.versionNumber,
        ipAddress: ctx?.ipAddress,
        userAgent: ctx?.userAgent,
        appVersion: ctx?.appVersion,
        platform: ctx?.platform,
        deviceId: ctx?.deviceId,
        acknowledgmentTextSnapshot: snapshot,
      },
    });

    // Keep legacy HipaaConsent row in sync for existing gates/reporting.
    await this.prisma.hipaaConsent.updateMany({
      where: {
        userId,
        consentType: 'HIPAA_PRIVACY',
        granted: true,
        revokedAt: null,
      },
      data: { granted: false, revokedAt: new Date() },
    });
    await this.prisma.hipaaConsent.create({
      data: {
        tenantId: user.tenantId,
        userId,
        consentType: 'HIPAA_PRIVACY',
        version: notice.versionNumber,
        granted: true,
        ipAddress: ctx?.ipAddress,
        metadata: { source: 'notice_acknowledgment', noticeId: notice.id },
      },
    });

    await this.audit.log({
      tenantId: user.tenantId,
      actorId: userId,
      action: AuditAction.CONSENT_GRANTED,
      resourceType: 'hipaa_notice_acknowledgment',
      resourceId: acknowledgment.id,
      metadata: {
        privacyEvent: 'ACKNOWLEDGED_NPP',
        noticeVersion: notice.versionNumber,
        platform: ctx?.platform,
      },
      ipAddress: ctx?.ipAddress,
      userAgent: ctx?.userAgent,
    });

    await this.securityEvents.log({
      tenantId: user.tenantId,
      userId,
      eventType: 'PRIVACY_NOTICE_ACKNOWLEDGED',
      severity: 'INFO',
      ipAddress: ctx?.ipAddress,
      userAgent: ctx?.userAgent,
      metadata: {
        noticeVersion: notice.versionNumber,
        noticeId: notice.id,
      },
    });

    return acknowledgment;
  }

  async logNoticeViewed(
    userId: string,
    view: 'notice_of_privacy_practices' | 'privacy_policy',
    ctx?: PrivacyClientContext,
  ) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) return;
    const eventType =
      view === 'notice_of_privacy_practices'
        ? 'VIEWED_NPP'
        : 'VIEWED_PRIVACY_POLICY';
    await this.audit.log({
      tenantId: user.tenantId,
      actorId: userId,
      action: AuditAction.READ,
      resourceType: 'privacy_notice',
      metadata: { privacyEvent: eventType },
      ipAddress: ctx?.ipAddress,
      userAgent: ctx?.userAgent,
    });
    await this.securityEvents.log({
      tenantId: user.tenantId,
      userId,
      eventType,
      severity: 'INFO',
      ipAddress: ctx?.ipAddress,
      userAgent: ctx?.userAgent,
    });
  }

  async listAcknowledgmentsForTenant(
    tenantId: string,
    opts?: { email?: string; take?: number },
  ) {
    const take = opts?.take ?? 50;
    return this.prisma.hipaaNoticeAcknowledgment.findMany({
      where: {
        tenantId,
        ...(opts?.email
          ? { user: { email: { contains: opts.email, mode: 'insensitive' } } }
          : {}),
      },
      include: {
        user: {
          select: {
            id: true,
            email: true,
            firstName: true,
            lastName: true,
            role: true,
          },
        },
        noticeVersionRecord: {
          select: { versionNumber: true, title: true, effectiveDate: true },
        },
      },
      orderBy: { acknowledgedAt: 'desc' },
      take,
    });
  }

  async listNoticeVersions(tenantId?: string | null) {
    return this.prisma.privacyNoticeVersion.findMany({
      where: tenantId ? { OR: [{ tenantId }, { tenantId: null }] } : {},
      orderBy: { effectiveDate: 'desc' },
      take: 50,
    });
  }

  async createNoticeVersion(
    actorId: string,
    tenantId: string | null,
    data: {
      versionNumber: string;
      title?: string;
      fullNoticeText?: string;
      privacyPolicyText?: string;
      effectiveDate?: Date;
      publish?: boolean;
    },
  ) {
    const existing = await this.prisma.privacyNoticeVersion.findFirst({
      where: { tenantId, versionNumber: data.versionNumber },
    });
    if (existing) {
      throw new BadRequestException('Notice version already exists');
    }

    if (data.publish) {
      await this.prisma.privacyNoticeVersion.updateMany({
        where: { tenantId, isActive: true },
        data: { isActive: false },
      });
    }

    const notice = await this.prisma.privacyNoticeVersion.create({
      data: {
        tenantId,
        versionNumber: data.versionNumber,
        title: data.title ?? 'Notice of Privacy Practices',
        fullNoticeText:
          data.fullNoticeText ?? buildDefaultNoticeOfPrivacyPractices(),
        privacyPolicyText:
          data.privacyPolicyText ?? buildDefaultPrivacyPolicy(),
        effectiveDate: data.effectiveDate ?? new Date(),
        isActive: data.publish ?? false,
        createdByUserId: actorId,
      },
    });

    await this.audit.log({
      tenantId: tenantId ?? (await this.defaultTenantId()),
      actorId,
      action: AuditAction.CREATE,
      resourceType: 'privacy_notice_version',
      resourceId: notice.id,
      metadata: {
        privacyEvent: data.publish
          ? 'ADMIN_PUBLISHED_NOTICE'
          : 'ADMIN_CREATED_NOTICE',
        versionNumber: data.versionNumber,
      },
    });

    return notice;
  }

  async publishNoticeVersion(actorId: string, noticeId: string) {
    const notice = await this.prisma.privacyNoticeVersion.findUnique({
      where: { id: noticeId },
    });
    if (!notice) throw new NotFoundException('Notice version not found');

    await this.prisma.privacyNoticeVersion.updateMany({
      where: { tenantId: notice.tenantId, isActive: true },
      data: { isActive: false },
    });

    const published = await this.prisma.privacyNoticeVersion.update({
      where: { id: noticeId },
      data: { isActive: true },
    });

    await this.audit.log({
      tenantId: notice.tenantId ?? (await this.defaultTenantId()),
      actorId,
      action: AuditAction.UPDATE,
      resourceType: 'privacy_notice_version',
      resourceId: noticeId,
      metadata: {
        privacyEvent: 'ADMIN_PUBLISHED_NOTICE',
        versionNumber: published.versionNumber,
      },
    });

    return published;
  }

  async getLatestAcknowledgment(userId: string) {
    return this.prisma.hipaaNoticeAcknowledgment.findFirst({
      where: { userId },
      orderBy: { acknowledgedAt: 'desc' },
      include: {
        noticeVersionRecord: {
          select: { versionNumber: true, title: true, effectiveDate: true },
        },
      },
    });
  }

  async ensureDefaultActiveNotice(tenantId: string) {
    const existing = await this.prisma.privacyNoticeVersion.findFirst({
      where: { OR: [{ tenantId }, { tenantId: null }], isActive: true },
    });
    if (existing) return existing;

    return this.prisma.privacyNoticeVersion.upsert({
      where: {
        tenantId_versionNumber: { tenantId, versionNumber: '1.0' },
      },
      create: {
        tenantId,
        versionNumber: '1.0',
        title: 'Notice of Privacy Practices',
        fullNoticeText: buildDefaultNoticeOfPrivacyPractices(),
        privacyPolicyText: buildDefaultPrivacyPolicy(),
        effectiveDate: new Date(),
        isActive: true,
      },
      update: { isActive: true },
    });
  }

  private async defaultTenantId(): Promise<string> {
    const tenant = await this.prisma.tenant.findFirst({
      where: { slug: 'abaconnect' },
    });
    return tenant?.id ?? '';
  }
}
