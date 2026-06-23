import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import type { UserRole } from '../../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';

export interface CallPermissionContext {
  agencyId?: string;
  childId?: string;
}

@Injectable()
export class CallsPermissionsService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * HIPAA/compliance: enforce minimum-necessary contact graph before any call session.
   */
  async assertCanCall(
    callerUserId: string,
    recipientUserId: string,
    childId?: string,
  ): Promise<CallPermissionContext> {
    if (callerUserId === recipientUserId) {
      throw new ForbiddenException('Cannot call yourself');
    }

    const [caller, recipient] = await Promise.all([
      this.prisma.user.findUnique({ where: { id: callerUserId } }),
      this.prisma.user.findUnique({ where: { id: recipientUserId } }),
    ]);

    if (!caller?.isActive || !recipient?.isActive) {
      throw new ForbiddenException('User account inactive or suspended');
    }
    if (caller.tenantId !== recipient.tenantId) {
      throw new ForbiddenException('Cross-tenant calls are not permitted');
    }

    // Platform admin: system settings only — no PHI calls.
    if (caller.role === 'PLATFORM_ADMIN') {
      throw new ForbiddenException(
        'Administrators cannot initiate clinical calls',
      );
    }

    // Agency admin: audit visibility only unless explicitly invited (not implemented).
    if (caller.role === 'AGENCY_ADMIN') {
      throw new ForbiddenException(
        'Agency administrators cannot join private clinical calls',
      );
    }

    if (recipient.role === 'PLATFORM_ADMIN') {
      throw new ForbiddenException('Cannot call platform administrators');
    }

    const agencyId = await this.resolveAgencyForCall(caller, recipient, childId);
    if (agencyId) {
      const agency = await this.prisma.agency.findUnique({
        where: { id: agencyId },
      });
      if (!agency?.callingEnabled) {
        throw new ForbiddenException('Calling is disabled for this agency');
      }
    }

    const allowed = await this.isPairAuthorized(
      caller.id,
      caller.role,
      recipient.id,
      recipient.role,
      childId,
    );
    if (!allowed) {
      throw new ForbiddenException('Not authorized to call this user');
    }

    return { agencyId, childId };
  }

  private async resolveAgencyForCall(
    caller: { id: string; role: UserRole; agencyId: string | null },
    recipient: { id: string; role: UserRole; agencyId: string | null },
    childId?: string,
  ): Promise<string | undefined> {
    if (childId) {
      const assignment = await this.prisma.childServiceCoordinatorAssignment.findFirst({
        where: { childId, status: 'ACTIVE', removedAt: null },
      });
      if (assignment?.agencyId) return assignment.agencyId;
      const apt = await this.prisma.appointment.findFirst({
        where: { childId, status: { notIn: ['CANCELLED'] } },
        orderBy: { scheduledStart: 'desc' },
      });
      if (apt?.agencyId) return apt.agencyId;
    }
    return caller.agencyId ?? recipient.agencyId ?? undefined;
  }

  private async isPairAuthorized(
    callerId: string,
    callerRole: UserRole,
    recipientId: string,
    recipientRole: UserRole,
    childId?: string,
  ): Promise<boolean> {
    if (callerRole === 'PARENT') {
      return this.parentCanCall(callerId, recipientId, recipientRole, childId);
    }
    if (callerRole === 'THERAPIST') {
      return this.therapistCanCall(
        callerId,
        recipientId,
        recipientRole,
        childId,
      );
    }
    if (callerRole === 'SERVICE_COORDINATOR') {
      return this.scCanCall(callerId, recipientId, childId);
    }
    return false;
  }

  private async parentCanCall(
    parentUserId: string,
    recipientId: string,
    recipientRole: UserRole,
    childId?: string,
  ): Promise<boolean> {
    const parent = await this.prisma.parent.findFirst({
      where: { userId: parentUserId },
      include: { children: true },
    });
    if (!parent) return false;

    const childIds = childId
      ? parent.children.filter((c) => c.id === childId).map((c) => c.id)
      : parent.children.map((c) => c.id);
    if (childIds.length === 0) return false;

    if (recipientRole === 'THERAPIST') {
      const apt = await this.prisma.appointment.findFirst({
        where: {
          childId: { in: childIds },
          therapist: { userId: recipientId },
          status: { notIn: ['CANCELLED'] },
        },
      });
      return !!apt;
    }

    if (recipientRole === 'SERVICE_COORDINATOR') {
      const sc = await this.prisma.childServiceCoordinatorAssignment.findFirst({
        where: {
          childId: { in: childIds },
          serviceCoordinatorId: recipientId,
          status: 'ACTIVE',
          removedAt: null,
        },
      });
      return !!sc;
    }

    return false;
  }

  private async therapistCanCall(
    therapistUserId: string,
    recipientId: string,
    recipientRole: UserRole,
    childId?: string,
  ): Promise<boolean> {
    const therapist = await this.prisma.therapist.findFirst({
      where: { userId: therapistUserId },
    });
    if (!therapist) return false;

    const aptWhere: {
      therapistId: string;
      status: { not: 'CANCELLED' };
      childId?: string;
    } = {
      therapistId: therapist.id,
      status: { not: 'CANCELLED' },
      ...(childId ? { childId } : {}),
    };

    if (recipientRole === 'PARENT') {
      const apt = await this.prisma.appointment.findFirst({
        where: { ...aptWhere, parent: { userId: recipientId } },
      });
      return !!apt;
    }

    if (recipientRole === 'SERVICE_COORDINATOR') {
      const appointments = await this.prisma.appointment.findMany({
        where: aptWhere,
        select: { childId: true },
        take: 100,
      });
      const childIds = [...new Set(appointments.map((a) => a.childId))];
      if (childIds.length === 0) return false;
      const sc = await this.prisma.childServiceCoordinatorAssignment.findFirst({
        where: {
          childId: { in: childIds },
          serviceCoordinatorId: recipientId,
          status: 'ACTIVE',
          removedAt: null,
        },
      });
      return !!sc;
    }

    return false;
  }

  private async scCanCall(
    coordinatorUserId: string,
    recipientId: string,
    childId?: string,
  ): Promise<boolean> {
    const coordinator = await this.prisma.user.findFirst({
      where: { id: coordinatorUserId, role: 'SERVICE_COORDINATOR' },
    });
    if (!coordinator?.agencyId || !coordinator.isActive) return false;

    const roster = await this.prisma.agencyRoster.findFirst({
      where: {
        userId: coordinatorUserId,
        agencyId: coordinator.agencyId,
        role: 'SERVICE_COORDINATOR',
        status: 'ACTIVE',
        removedAt: null,
      },
    });
    if (!roster) return false;

    const assignments = await this.prisma.childServiceCoordinatorAssignment.findMany({
      where: {
        serviceCoordinatorId: coordinatorUserId,
        agencyId: coordinator.agencyId,
        status: 'ACTIVE',
        removedAt: null,
        ...(childId ? { childId } : {}),
      },
      include: {
        child: {
          include: {
            parent: { include: { user: true } },
            appointments: {
              where: { status: { notIn: ['CANCELLED'] } },
              include: { therapist: { include: { user: true } } },
              take: 50,
            },
          },
        },
      },
    });

    for (const assignment of assignments) {
      if (assignment.child.parent.user.id === recipientId) return true;
      for (const apt of assignment.child.appointments) {
        if (apt.therapist.user.id === recipientId) return true;
      }
    }

    // Agency roster staff on same agency for assigned cases.
    const agencyStaff = await this.prisma.agencyRoster.findFirst({
      where: {
        userId: recipientId,
        agencyId: coordinator.agencyId,
        status: 'ACTIVE',
        removedAt: null,
      },
    });
    return !!agencyStaff && assignments.length > 0;
  }

  async assertCanViewCallHistory(
    userId: string,
    role: UserRole,
    filters: {
      childId?: string;
      userId?: string;
      agencyId?: string;
    },
  ) {
    if (role === 'PLATFORM_ADMIN') {
      // Platform admin: no child-scoped PHI in call history.
      if (filters.childId) {
        throw new ForbiddenException('Child-scoped call history restricted');
      }
      return;
    }

    if (role === 'AGENCY_ADMIN') {
      const admin = await this.prisma.user.findUnique({ where: { id: userId } });
      if (!admin?.agencyId) {
        throw new ForbiddenException('Agency context required');
      }
      if (filters.agencyId && filters.agencyId !== admin.agencyId) {
        throw new ForbiddenException('Cross-agency audit access denied');
      }
      return;
    }

    if (role === 'SERVICE_COORDINATOR' && filters.childId) {
      const ok = await this.prisma.childServiceCoordinatorAssignment.findFirst({
        where: {
          childId: filters.childId,
          serviceCoordinatorId: userId,
          status: 'ACTIVE',
          removedAt: null,
        },
      });
      if (!ok) throw new ForbiddenException('Not assigned to this case');
      return;
    }

    if (role === 'PARENT' && filters.childId) {
      const parent = await this.prisma.parent.findFirst({
        where: { userId, children: { some: { id: filters.childId } } },
      });
      if (!parent) throw new ForbiddenException('Not authorized for this child');
      return;
    }

    if (role === 'THERAPIST') {
      return;
    }

    if (!filters.childId && !filters.userId) {
      throw new NotFoundException('Filter required');
    }
  }
}
