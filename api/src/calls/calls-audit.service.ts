import { Injectable } from '@nestjs/common';
import { createHash } from 'crypto';
import type {
  CallAuditEventType,
  CallSessionStatus,
  CallType,
  Prisma,
  UserRole,
} from '../../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';

export interface CallAuditInput {
  tenantId: string;
  callSessionId: string;
  agencyId?: string;
  childId?: string;
  actorUserId: string;
  actorRole: UserRole;
  targetUserId?: string;
  targetRole?: UserRole;
  eventType: CallAuditEventType;
  callType?: CallType;
  callStatus?: CallSessionStatus;
  callStartTime?: Date;
  callEndTime?: Date;
  callDurationSeconds?: number;
  eventDetails?: Record<string, unknown>;
  reason?: string;
  deviceType?: string;
  ipAddress?: string;
  userAgent?: string;
}

/**
 * Append-only call audit trail. Records are never updated or deleted by app code.
 */
@Injectable()
export class CallsAuditService {
  constructor(private readonly prisma: PrismaService) {}

  async append(input: CallAuditInput) {
    const payload = {
      tenantId: input.tenantId,
      callSessionId: input.callSessionId,
      agencyId: input.agencyId,
      childId: input.childId,
      actorUserId: input.actorUserId,
      actorRole: input.actorRole,
      targetUserId: input.targetUserId,
      targetRole: input.targetRole,
      eventType: input.eventType,
      callType: input.callType,
      callStatus: input.callStatus,
      callStartTime: input.callStartTime,
      callEndTime: input.callEndTime,
      callDurationSeconds: input.callDurationSeconds,
      eventDetails: (input.eventDetails ?? {}) as Prisma.InputJsonValue,
      reason: input.reason,
      deviceType: input.deviceType,
      ipAddress: input.ipAddress,
      userAgent: input.userAgent,
      createdBy: input.actorUserId,
    };

    const immutableHash = createHash('sha256')
      .update(JSON.stringify({ ...payload, timestamp: new Date().toISOString() }))
      .digest('hex');

    return this.prisma.callAuditLog.create({
      data: { ...payload, immutableHash },
    });
  }
}
