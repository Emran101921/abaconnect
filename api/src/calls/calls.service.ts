import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { randomUUID } from 'crypto';
import type {
  CallSessionStatus,
  CallType,
  UserRole,
} from '../../generated/prisma/client';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.service';
import { CallProviderFactory } from './call-provider.factory';
import { CallsAuditService } from './calls-audit.service';
import { CallsPermissionsService } from './calls-permissions.service';

const RINGING_TTL_MS = 60_000;
const MAX_CALLS_PER_HOUR = 20;

export interface CallRequestContext {
  ipAddress?: string;
  userAgent?: string;
  deviceType?: string;
}

@Injectable()
export class CallsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly permissions: CallsPermissionsService,
    private readonly audit: CallsAuditService,
    private readonly providerFactory: CallProviderFactory,
    private readonly notifications: NotificationsService,
  ) {}

  async initiateCall(
    callerUserId: string,
    recipientUserId: string,
    callType: CallType,
    childId: string | undefined,
    ctx: CallRequestContext,
  ) {
    const caller = await this.requireActiveUser(callerUserId);
    const recipient = await this.requireActiveUser(recipientUserId);

    await this.enforceRateLimit(callerUserId);

    let permissionCtx: { agencyId?: string; childId?: string };
    try {
      permissionCtx = await this.permissions.assertCanCall(
        callerUserId,
        recipientUserId,
        childId,
      );
    } catch (e) {
      await this.logPermissionDenied(
        caller,
        recipient,
        callType,
        childId,
        ctx,
        e instanceof Error ? e.message : 'Permission denied',
      );
      throw e;
    }

    const provider = this.providerFactory.getProvider();
    const roomId = `call-${randomUUID()}`;
    const now = new Date();
    const ringingExpiresAt = new Date(now.getTime() + RINGING_TTL_MS);

    const session = await this.prisma.callSession.create({
      data: {
        tenantId: caller.tenantId,
        agencyId: permissionCtx.agencyId,
        childId: permissionCtx.childId ?? childId,
        callType,
        status: 'RINGING',
        initiatedByUserId: callerUserId,
        providerName: provider.name,
        providerRoomId: roomId,
        ringingExpiresAt,
        participants: {
          create: [
            {
              userId: callerUserId,
              role: caller.role,
              joinStatus: 'INVITED',
            },
            {
              userId: recipientUserId,
              role: recipient.role,
              joinStatus: 'RINGING',
            },
          ],
        },
      },
      include: {
        participants: { include: { user: true } },
        initiatedBy: true,
      },
    });

    const auditBase = {
      tenantId: caller.tenantId,
      callSessionId: session.id,
      agencyId: session.agencyId ?? undefined,
      childId: session.childId ?? undefined,
      actorUserId: callerUserId,
      actorRole: caller.role,
      targetUserId: recipientUserId,
      targetRole: recipient.role,
      callType,
      callStatus: 'RINGING' as CallSessionStatus,
      ipAddress: ctx.ipAddress,
      userAgent: ctx.userAgent,
      deviceType: ctx.deviceType,
    };

    await this.audit.append({ ...auditBase, eventType: 'CALL_INITIATED' });
    await this.audit.append({ ...auditBase, eventType: 'CALL_RINGING' });

    const callerToken = await provider.createParticipantToken({
      roomId,
      callType,
      userDisplayName: `${caller.firstName} ${caller.lastName}`,
      isOwner: true,
    });

    await this.audit.append({
      ...auditBase,
      eventType: 'CALL_TOKEN_CREATED',
      eventDetails: {
        participantUserId: callerUserId,
        expiresAt: callerToken.expiresAt.toISOString(),
      },
    });

    // PHI-safe push: no child names or diagnoses in notification body.
    await this.notifications.createForUser(recipientUserId, {
      title: 'Incoming secure call',
      body: 'You have an incoming secure call. Open the app to respond.',
      data: {
        type: 'INCOMING_CALL',
        callSessionId: session.id,
        callType,
        callerUserId,
      },
    });

    await this.prisma.callNotification.create({
      data: {
        tenantId: recipient.tenantId,
        callSessionId: session.id,
        userId: recipientUserId,
        title: 'Incoming secure call',
        body: 'You have an incoming secure call.',
        data: {
          type: 'INCOMING_CALL',
          callSessionId: session.id,
        },
      },
    });

    return this.toCallSessionDto(session, {
      joinUrl: callerToken.joinUrl,
      token: callerToken.token,
      tokenExpiresAt: callerToken.expiresAt,
    });
  }

  async acceptCall(
    userId: string,
    callSessionId: string,
    ctx: CallRequestContext,
  ) {
    const session = await this.loadSession(callSessionId);
    const participant = session.participants.find((p) => p.userId === userId);
    if (!participant || participant.userId === session.initiatedByUserId) {
      throw new ForbiddenException('Only the recipient can accept this call');
    }
    if (session.status !== 'RINGING') {
      throw new BadRequestException('Call is no longer ringing');
    }
    if (session.ringingExpiresAt && session.ringingExpiresAt < new Date()) {
      await this.markMissed(session, 'Ringing timeout', ctx);
      throw new BadRequestException('Call expired');
    }

    const user = await this.requireActiveUser(userId);
    const provider = this.providerFactory.getProvider();
    const token = await provider.createParticipantToken({
      roomId: session.providerRoomId!,
      callType: session.callType,
      userDisplayName: `${user.firstName} ${user.lastName}`,
      isOwner: false,
    });

    const startedAt = new Date();
    const updated = await this.prisma.callSession.update({
      where: { id: callSessionId },
      data: {
        status: 'IN_PROGRESS',
        startedAt,
        participants: {
          update: {
            where: {
              callSessionId_userId: {
                callSessionId,
                userId,
              },
            },
            data: { joinStatus: 'JOINED', joinedAt: startedAt },
          },
        },
      },
      include: {
        participants: { include: { user: true } },
        initiatedBy: true,
      },
    });

    await this.audit.append({
      tenantId: session.tenantId,
      callSessionId,
      agencyId: session.agencyId ?? undefined,
      childId: session.childId ?? undefined,
      actorUserId: userId,
      actorRole: user.role,
      targetUserId: session.initiatedByUserId,
      targetRole: session.initiatedBy.role,
      eventType: 'CALL_ACCEPTED',
      callType: session.callType,
      callStatus: 'IN_PROGRESS',
      callStartTime: startedAt,
      ipAddress: ctx.ipAddress,
      userAgent: ctx.userAgent,
      deviceType: ctx.deviceType,
      eventDetails: { tokenExpiresAt: token.expiresAt.toISOString() },
    });

    await this.audit.append({
      tenantId: session.tenantId,
      callSessionId,
      agencyId: session.agencyId ?? undefined,
      childId: session.childId ?? undefined,
      actorUserId: userId,
      actorRole: user.role,
      eventType: 'CALL_TOKEN_CREATED',
      eventDetails: {
        participantUserId: userId,
        expiresAt: token.expiresAt.toISOString(),
      },
    });

    return this.toCallSessionDto(updated, {
      joinUrl: token.joinUrl,
      token: token.token,
      tokenExpiresAt: token.expiresAt,
    });
  }

  async declineCall(
    userId: string,
    callSessionId: string,
    reason: string | undefined,
    ctx: CallRequestContext,
  ) {
    const session = await this.loadSession(callSessionId);
    if (session.status !== 'RINGING') {
      throw new BadRequestException('Call is not ringing');
    }
    const user = await this.requireActiveUser(userId);
    const isRecipient = session.participants.some(
      (p) => p.userId === userId && p.userId !== session.initiatedByUserId,
    );
    if (!isRecipient) {
      throw new ForbiddenException('Not authorized to decline this call');
    }

    const updated = await this.prisma.callSession.update({
      where: { id: callSessionId },
      data: {
        status: 'DECLINED',
        endedAt: new Date(),
        failureReason: reason ?? 'Declined by recipient',
        participants: {
          update: {
            where: {
              callSessionId_userId: { callSessionId, userId },
            },
            data: { joinStatus: 'DECLINED' },
          },
        },
      },
      include: {
        participants: { include: { user: true } },
        initiatedBy: true,
      },
    });

    await this.audit.append({
      tenantId: session.tenantId,
      callSessionId,
      agencyId: session.agencyId ?? undefined,
      childId: session.childId ?? undefined,
      actorUserId: userId,
      actorRole: user.role,
      targetUserId: session.initiatedByUserId,
      targetRole: session.initiatedBy.role,
      eventType: 'CALL_DECLINED',
      callType: session.callType,
      callStatus: 'DECLINED',
      reason: reason ?? 'Declined',
      ipAddress: ctx.ipAddress,
      userAgent: ctx.userAgent,
      deviceType: ctx.deviceType,
    });

    return this.toCallSessionDto(updated);
  }

  async cancelCall(
    userId: string,
    callSessionId: string,
    ctx: CallRequestContext,
  ) {
    const session = await this.loadSession(callSessionId);
    if (session.initiatedByUserId !== userId) {
      throw new ForbiddenException('Only the caller can cancel');
    }
    if (!['INITIATED', 'RINGING'].includes(session.status)) {
      throw new BadRequestException('Call cannot be cancelled');
    }

    const user = await this.requireActiveUser(userId);
    const updated = await this.prisma.callSession.update({
      where: { id: callSessionId },
      data: { status: 'CANCELLED', endedAt: new Date() },
      include: {
        participants: { include: { user: true } },
        initiatedBy: true,
      },
    });

    await this.audit.append({
      tenantId: session.tenantId,
      callSessionId,
      agencyId: session.agencyId ?? undefined,
      childId: session.childId ?? undefined,
      actorUserId: userId,
      actorRole: user.role,
      eventType: 'CALL_CANCELLED',
      callType: session.callType,
      callStatus: 'CANCELLED',
      ipAddress: ctx.ipAddress,
      userAgent: ctx.userAgent,
      deviceType: ctx.deviceType,
    });

    return this.toCallSessionDto(updated);
  }

  async endCall(
    userId: string,
    callSessionId: string,
    ctx: CallRequestContext,
  ) {
    const session = await this.loadSession(callSessionId);
    if (['ENDED', 'CANCELLED', 'DECLINED', 'MISSED'].includes(session.status)) {
      return this.toCallSessionDto(session);
    }
    if (session.status === 'RINGING' || session.status === 'INITIATED') {
      if (session.initiatedByUserId === userId) {
        return this.cancelCall(userId, callSessionId, ctx);
      }
      return this.declineCall(userId, callSessionId, 'Ended by recipient', ctx);
    }
    if (!['ACCEPTED', 'IN_PROGRESS'].includes(session.status)) {
      throw new BadRequestException('Call is not active');
    }
    const participant = session.participants.find((p) => p.userId === userId);
    if (!participant) {
      throw new ForbiddenException('Not a participant');
    }

    const user = await this.requireActiveUser(userId);
    const endedAt = new Date();
    const durationSeconds = session.startedAt
      ? Math.max(
          0,
          Math.floor((endedAt.getTime() - session.startedAt.getTime()) / 1000),
        )
      : 0;

    const updated = await this.prisma.callSession.update({
      where: { id: callSessionId },
      data: {
        status: 'ENDED',
        endedAt,
        durationSeconds,
        participants: {
          updateMany: {
            where: { callSessionId, joinStatus: 'JOINED' },
            data: { joinStatus: 'LEFT', leftAt: endedAt },
          },
        },
      },
      include: {
        participants: { include: { user: true } },
        initiatedBy: true,
      },
    });

    const provider = this.providerFactory.getProvider();
    if (session.providerRoomId && provider.endRoom) {
      await provider.endRoom(session.providerRoomId).catch(() => undefined);
    }

    await this.audit.append({
      tenantId: session.tenantId,
      callSessionId,
      agencyId: session.agencyId ?? undefined,
      childId: session.childId ?? undefined,
      actorUserId: userId,
      actorRole: user.role,
      eventType: 'CALL_ENDED',
      callType: session.callType,
      callStatus: 'ENDED',
      callStartTime: session.startedAt ?? undefined,
      callEndTime: endedAt,
      callDurationSeconds: durationSeconds,
      ipAddress: ctx.ipAddress,
      userAgent: ctx.userAgent,
      deviceType: ctx.deviceType,
    });

    return this.toCallSessionDto(updated);
  }

  async getCallHistory(
    userId: string,
    role: UserRole,
    filters: {
      childId?: string;
      userId?: string;
      agencyId?: string;
      status?: CallSessionStatus;
      callType?: CallType;
      from?: Date;
      to?: Date;
      limit?: number;
    },
  ) {
    await this.permissions.assertCanViewCallHistory(userId, role, filters);

    const where: Record<string, unknown> = {
      tenantId: (await this.requireActiveUser(userId)).tenantId,
    };

    if (role === 'AGENCY_ADMIN') {
      const admin = await this.prisma.user.findUnique({ where: { id: userId } });
      where.agencyId = admin?.agencyId;
    } else if (role === 'SERVICE_COORDINATOR') {
      where.childId = filters.childId;
      where.participants = { some: { userId } };
    } else if (role === 'PARENT') {
      where.childId = filters.childId;
      where.participants = { some: { userId } };
    } else if (role === 'THERAPIST') {
      where.participants = { some: { userId } };
      if (filters.childId) where.childId = filters.childId;
    } else if (role === 'PLATFORM_ADMIN') {
      // Platform admin: no PHI-bearing call history in clinical views.
      return [];
    } else {
      where.participants = { some: { userId } };
    }

    if (filters.status) where.status = filters.status;
    if (filters.callType) where.callType = filters.callType;
    if (filters.from || filters.to) {
      where.createdAt = {
        ...(filters.from ? { gte: filters.from } : {}),
        ...(filters.to ? { lte: filters.to } : {}),
      };
    }

    const sessions = await this.prisma.callSession.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: filters.limit ?? 50,
      include: {
        participants: { include: { user: true } },
        initiatedBy: true,
      },
    });

    return sessions.map((s) => this.toCallSessionDto(s));
  }

  async getAgencyAuditLogs(
    userId: string,
    filters: {
      agencyId?: string;
      childId?: string;
      userId?: string;
      role?: UserRole;
      status?: CallSessionStatus;
      callType?: CallType;
      from?: Date;
      to?: Date;
      limit?: number;
    },
  ) {
    const admin = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!admin || admin.role !== 'AGENCY_ADMIN' || !admin.agencyId) {
      throw new ForbiddenException('Agency admin access required');
    }

    const where: Record<string, unknown> = {
      agencyId: admin.agencyId,
    };
    if (filters.childId) where.childId = filters.childId;
    if (filters.userId) {
      where.OR = [
        { actorUserId: filters.userId },
        { targetUserId: filters.userId },
      ];
    }
    if (filters.role) where.actorRole = filters.role;
    if (filters.status) where.callStatus = filters.status;
    if (filters.callType) where.callType = filters.callType;
    if (filters.from || filters.to) {
      where.createdAt = {
        ...(filters.from ? { gte: filters.from } : {}),
        ...(filters.to ? { lte: filters.to } : {}),
      };
    }

    return this.prisma.callAuditLog.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: filters.limit ?? 100,
    });
  }

  async getIncomingRingingCall(userId: string) {
    const session = await this.prisma.callSession.findFirst({
      where: {
        status: 'RINGING',
        ringingExpiresAt: { gt: new Date() },
        participants: { some: { userId, joinStatus: 'RINGING' } },
      },
      include: {
        participants: { include: { user: true } },
        initiatedBy: true,
      },
      orderBy: { createdAt: 'desc' },
    });
    return session ? this.toCallSessionDto(session) : null;
  }

  async getCallSessionForUser(userId: string, callSessionId: string) {
    const session = await this.loadSession(callSessionId);
    const isParticipant = session.participants.some((p) => p.userId === userId);
    if (!isParticipant) {
      throw new ForbiddenException('Not a participant in this call');
    }
    return this.toCallSessionDto(session);
  }

  private async markMissed(
    session: Awaited<ReturnType<typeof this.loadSession>>,
    reason: string,
    ctx: CallRequestContext,
  ) {
    await this.prisma.callSession.update({
      where: { id: session.id },
      data: { status: 'MISSED', endedAt: new Date(), failureReason: reason },
    });
    await this.audit.append({
      tenantId: session.tenantId,
      callSessionId: session.id,
      agencyId: session.agencyId ?? undefined,
      childId: session.childId ?? undefined,
      actorUserId: session.initiatedByUserId,
      actorRole: session.initiatedBy.role,
      targetUserId: session.participants.find(
        (p) => p.userId !== session.initiatedByUserId,
      )?.userId,
      eventType: 'CALL_MISSED',
      callType: session.callType,
      callStatus: 'MISSED',
      reason,
      ipAddress: ctx.ipAddress,
      userAgent: ctx.userAgent,
      deviceType: ctx.deviceType,
    });
  }

  private async logPermissionDenied(
    caller: { id: string; tenantId: string; role: UserRole },
    recipient: { id: string; role: UserRole },
    callType: CallType,
    childId: string | undefined,
    ctx: CallRequestContext,
    reason: string,
  ) {
    const session = await this.prisma.callSession.create({
      data: {
        tenantId: caller.tenantId,
        childId,
        callType,
        status: 'FAILED',
        initiatedByUserId: caller.id,
        providerName: 'none',
        failureReason: reason,
        endedAt: new Date(),
      },
    });

    await this.audit.append({
      tenantId: caller.tenantId,
      callSessionId: session.id,
      childId,
      actorUserId: caller.id,
      actorRole: caller.role,
      targetUserId: recipient.id,
      targetRole: recipient.role,
      eventType: 'CALL_PERMISSION_DENIED',
      callType,
      callStatus: 'FAILED',
      reason,
      ipAddress: ctx.ipAddress,
      userAgent: ctx.userAgent,
      deviceType: ctx.deviceType,
    });
  }

  private async enforceRateLimit(userId: string) {
    const since = new Date(Date.now() - 60 * 60 * 1000);
    const count = await this.prisma.callSession.count({
      where: { initiatedByUserId: userId, createdAt: { gte: since } },
    });
    if (count >= MAX_CALLS_PER_HOUR) {
      throw new ForbiddenException('Call rate limit exceeded');
    }
  }

  private async requireActiveUser(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user?.isActive) {
      throw new ForbiddenException('User account inactive');
    }
    return user;
  }

  private async loadSession(callSessionId: string) {
    const session = await this.prisma.callSession.findUnique({
      where: { id: callSessionId },
      include: {
        participants: { include: { user: true } },
        initiatedBy: true,
      },
    });
    if (!session) throw new NotFoundException('Call session not found');
    return session;
  }

  private toCallSessionDto(
    session: {
      id: string;
      callType: CallType;
      status: CallSessionStatus;
      childId: string | null;
      agencyId: string | null;
      startedAt: Date | null;
      endedAt: Date | null;
      durationSeconds: number | null;
      providerName: string;
      providerRoomId: string | null;
      createdAt: Date;
      initiatedBy: { id: string; firstName: string; lastName: string; role: UserRole };
      participants: Array<{
        userId: string;
        role: UserRole;
        joinStatus: string;
        user: { firstName: string; lastName: string };
      }>;
    },
    tokenInfo?: { joinUrl?: string; token: string; tokenExpiresAt: Date },
  ) {
    const other = session.participants.find(
      (p) => p.userId !== session.initiatedBy.id,
    );
    return {
      id: session.id,
      callType: session.callType,
      status: session.status,
      childId: session.childId ?? undefined,
      agencyId: session.agencyId ?? undefined,
      initiatedByUserId: session.initiatedBy.id,
      initiatedByName: `${session.initiatedBy.firstName} ${session.initiatedBy.lastName}`,
      initiatedByRole: session.initiatedBy.role,
      recipientUserId: other?.userId,
      recipientName: other
        ? `${other.user.firstName} ${other.user.lastName}`
        : undefined,
      recipientRole: other?.role,
      startedAt: session.startedAt ?? undefined,
      endedAt: session.endedAt ?? undefined,
      durationSeconds: session.durationSeconds ?? undefined,
      providerName: session.providerName,
      createdAt: session.createdAt,
      joinUrl: tokenInfo?.joinUrl,
      token: tokenInfo?.token,
      tokenExpiresAt: tokenInfo?.tokenExpiresAt,
      participants: session.participants.map((p) => ({
        userId: p.userId,
        displayName: `${p.user.firstName} ${p.user.lastName}`,
        role: p.role,
        joinStatus: p.joinStatus,
      })),
    };
  }
}
