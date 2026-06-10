import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  AuditAction,
  Prisma,
  PrivacyRightsRequestStatus,
  PrivacyRightsRequestType,
} from '../../generated/prisma/client';
import { AuditService } from '../audit/audit.service';
import { PrismaService } from '../prisma/prisma.service';
import { SecurityEventService } from '../security/security-event.service';

export interface PrivacyRequestContext {
  ipAddress?: string;
  userAgent?: string;
}

const EVENT_BY_TYPE: Record<PrivacyRightsRequestType, string> = {
  RECORD_ACCESS: 'REQUESTED_RECORD_ACCESS',
  CORRECTION: 'REQUESTED_CORRECTION',
  RESTRICTION: 'REQUESTED_RESTRICTION',
  CONFIDENTIAL_COMMUNICATION: 'REQUESTED_CONFIDENTIAL_COMMUNICATION',
  ACCOUNTING_OF_DISCLOSURES: 'REQUESTED_ACCOUNTING_OF_DISCLOSURES',
  CONTACT_PRIVACY_OFFICER: 'CONTACTED_PRIVACY_OFFICER',
  DATA_DELETION: 'REQUESTED_DATA_DELETION',
};

@Injectable()
export class PrivacyRightsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly securityEvents: SecurityEventService,
  ) {}

  async submitRequest(
    userId: string,
    requestType: PrivacyRightsRequestType,
    payload: Record<string, unknown>,
    ctx?: PrivacyRequestContext,
  ) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new BadRequestException('User not found');

    const row = await this.prisma.privacyRightsRequest.create({
      data: {
        tenantId: user.tenantId,
        userId,
        requestType,
        payload: payload as Prisma.InputJsonValue,
        ipAddress: ctx?.ipAddress,
        userAgent: ctx?.userAgent,
      },
    });

    const privacyEvent = EVENT_BY_TYPE[requestType];
    await this.audit.log({
      tenantId: user.tenantId,
      actorId: userId,
      action: AuditAction.CREATE,
      resourceType: 'privacy_rights_request',
      resourceId: row.id,
      metadata: { privacyEvent, requestType },
      ipAddress: ctx?.ipAddress,
      userAgent: ctx?.userAgent,
    });
    await this.securityEvents.log({
      tenantId: user.tenantId,
      userId,
      eventType: privacyEvent,
      severity: 'INFO',
      ipAddress: ctx?.ipAddress,
      userAgent: ctx?.userAgent,
      metadata: { requestId: row.id, requestType },
    });

    return row;
  }

  async listForUser(userId: string) {
    return this.prisma.privacyRightsRequest.findMany({
      where: { userId },
      orderBy: { submittedAt: 'desc' },
      take: 50,
    });
  }

  async listForTenant(
    tenantId: string,
    status?: PrivacyRightsRequestStatus,
  ) {
    return this.prisma.privacyRightsRequest.findMany({
      where: {
        tenantId,
        ...(status ? { status } : {}),
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
      },
      orderBy: { submittedAt: 'desc' },
      take: 100,
    });
  }

  async updateStatus(
    actorId: string,
    tenantId: string,
    requestId: string,
    data: {
      status: PrivacyRightsRequestStatus;
      internalNotes?: string;
    },
  ) {
    const row = await this.prisma.privacyRightsRequest.findFirst({
      where: { id: requestId, tenantId },
    });
    if (!row) throw new NotFoundException('Privacy request not found');

    const updated = await this.prisma.privacyRightsRequest.update({
      where: { id: requestId },
      data: {
        status: data.status,
        internalNotes: data.internalNotes ?? row.internalNotes,
        completedAt:
          data.status === 'COMPLETED' || data.status === 'DENIED'
            ? new Date()
            : row.completedAt,
      },
    });

    await this.audit.log({
      tenantId,
      actorId,
      action: AuditAction.UPDATE,
      resourceType: 'privacy_rights_request',
      resourceId: requestId,
      metadata: {
        privacyEvent: 'ADMIN_UPDATED_PRIVACY_REQUEST',
        status: data.status,
      },
    });

    return updated;
  }
}
