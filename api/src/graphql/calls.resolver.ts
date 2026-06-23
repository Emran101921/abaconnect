import { Args, ID, Mutation, Query, Resolver } from '@nestjs/graphql';
import { Req } from '@nestjs/common';
import type { Request } from 'express';
import type { UserRole } from '../../generated/prisma/client';
import { Roles } from '../common/decorators/roles.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { CallsService } from '../calls/calls.service';
import {
  AgencyCallAuditFilterInput,
  CallAuditLogType,
  CallHistoryFilterInput,
  CallSessionType,
  InitiateCallInput,
} from './types/calls.types';

function callCtx(req?: Request) {
  return {
    ipAddress: req?.ip,
    userAgent: req?.headers?.['user-agent'] as string | undefined,
    deviceType: req?.headers?.['x-device-type'] as string | undefined,
  };
}

function primaryRole(user: AuthUser): UserRole {
  return (user.roles?.[0] ?? 'PARENT') as UserRole;
}

@Resolver()
export class CallsResolver {
  constructor(private readonly calls: CallsService) {}

  @Mutation(() => CallSessionType, { name: 'initiateCall' })
  @Roles('PARENT', 'THERAPIST', 'SERVICE_COORDINATOR')
  async initiateCall(
    @CurrentUser() user: AuthUser,
    @Args('input') input: InitiateCallInput,
    @Req() req: Request,
  ) {
    return this.calls.initiateCall(
      user.id,
      input.recipientUserId,
      input.callType,
      input.childId,
      callCtx(req),
    );
  }

  @Mutation(() => CallSessionType, { name: 'acceptCall' })
  @Roles('PARENT', 'THERAPIST', 'SERVICE_COORDINATOR')
  async acceptCall(
    @CurrentUser() user: AuthUser,
    @Args('callSessionId', { type: () => ID }) callSessionId: string,
    @Req() req: Request,
  ) {
    return this.calls.acceptCall(user.id, callSessionId, callCtx(req));
  }

  @Mutation(() => CallSessionType, { name: 'declineCall' })
  @Roles('PARENT', 'THERAPIST', 'SERVICE_COORDINATOR')
  async declineCall(
    @CurrentUser() user: AuthUser,
    @Args('callSessionId', { type: () => ID }) callSessionId: string,
    @Args('reason', { nullable: true, type: () => String }) reason: string | undefined,
    @Req() req: Request,
  ) {
    return this.calls.declineCall(user.id, callSessionId, reason, callCtx(req));
  }

  @Mutation(() => CallSessionType, { name: 'cancelCall' })
  @Roles('PARENT', 'THERAPIST', 'SERVICE_COORDINATOR')
  async cancelCall(
    @CurrentUser() user: AuthUser,
    @Args('callSessionId', { type: () => ID }) callSessionId: string,
    @Req() req: Request,
  ) {
    return this.calls.cancelCall(user.id, callSessionId, callCtx(req));
  }

  @Mutation(() => CallSessionType, { name: 'endCall' })
  @Roles('PARENT', 'THERAPIST', 'SERVICE_COORDINATOR')
  async endCall(
    @CurrentUser() user: AuthUser,
    @Args('callSessionId', { type: () => ID }) callSessionId: string,
    @Req() req: Request,
  ) {
    return this.calls.endCall(user.id, callSessionId, callCtx(req));
  }

  @Query(() => [CallSessionType], { name: 'callHistory' })
  @Roles(
    'PARENT',
    'THERAPIST',
    'SERVICE_COORDINATOR',
    'AGENCY_ADMIN',
    'PLATFORM_ADMIN',
  )
  async callHistory(
    @CurrentUser() user: AuthUser,
    @Args('filter', { nullable: true }) filter?: CallHistoryFilterInput,
  ) {
    return this.calls.getCallHistory(user.id, primaryRole(user), {
      childId: filter?.childId,
      userId: filter?.userId,
      status: filter?.status,
      callType: filter?.callType,
      from: filter?.from,
      to: filter?.to,
      limit: filter?.limit,
    });
  }

  @Query(() => [CallAuditLogType], { name: 'agencyCallAuditLogs' })
  @Roles('AGENCY_ADMIN')
  async agencyCallAuditLogs(
    @CurrentUser() user: AuthUser,
    @Args('filter', { nullable: true }) filter?: AgencyCallAuditFilterInput,
  ) {
    const logs = await this.calls.getAgencyAuditLogs(user.id, {
      childId: filter?.childId,
      userId: filter?.userId,
      role: filter?.role as never,
      status: filter?.status,
      callType: filter?.callType,
      from: filter?.from,
      to: filter?.to,
      limit: filter?.limit,
    });
    return logs.map((l) => ({
      id: l.id,
      callSessionId: l.callSessionId,
      agencyId: l.agencyId ?? undefined,
      childId: l.childId ?? undefined,
      actorUserId: l.actorUserId,
      actorRole: l.actorRole,
      targetUserId: l.targetUserId ?? undefined,
      targetRole: l.targetRole ?? undefined,
      eventType: l.eventType,
      callType: l.callType ?? undefined,
      callStatus: l.callStatus ?? undefined,
      reason: l.reason ?? undefined,
      createdAt: l.createdAt,
    }));
  }

  @Query(() => CallSessionType, { name: 'incomingRingingCall', nullable: true })
  @Roles('PARENT', 'THERAPIST', 'SERVICE_COORDINATOR')
  async incomingRingingCall(@CurrentUser() user: AuthUser) {
    return this.calls.getIncomingRingingCall(user.id);
  }

  @Query(() => CallSessionType, { name: 'callSession', nullable: true })
  @Roles('PARENT', 'THERAPIST', 'SERVICE_COORDINATOR', 'AGENCY_ADMIN')
  async callSession(
    @CurrentUser() user: AuthUser,
    @Args('callSessionId', { type: () => ID }) callSessionId: string,
  ) {
    return this.calls.getCallSessionForUser(user.id, callSessionId);
  }
}
