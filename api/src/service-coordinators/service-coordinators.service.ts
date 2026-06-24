import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import {
  AgencyRosterMemberRole,
  AgencyRosterStatus,
  ChildScAssignmentStatus,
  EiScreeningStatus,
  Prisma,
} from '../../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { buildCaseloadCharts } from '../common/caseload-charts.util';
import {
  deriveEiScreeningPriority,
  EI_INITIAL_REQUIRED_KEYS,
  EI_ONGOING_REQUIRED_KEYS,
  screeningCompletionPercent,
} from './ei-screening.util';
import { isEiServiceEligible } from './ei-eligibility.util';
import {
  buildEiScreeningPrefill,
  mergePrefillIntoAnswers,
} from './ei-prefill.util';

export interface CreateServiceCoordinatorInput {
  email: string;
  password: string;
  firstName: string;
  lastName: string;
  phone?: string;
  languages?: string[];
  notes?: string;
}

export interface UpdateServiceCoordinatorInput {
  firstName?: string;
  lastName?: string;
  phone?: string;
  languages?: string[];
  notes?: string;
  status?: AgencyRosterStatus;
}

export interface UpsertEiScreeningInput {
  answersJson?: Record<string, unknown>;
  notes?: string;
  followUpRequired?: boolean;
  followUpDueDate?: Date;
  submit?: boolean;
  progressSummary?: string;
  newConcerns?: string;
}

export interface CreateScNoteInput {
  noteType: string;
  noteText: string;
  actionRequired?: boolean;
  actionDueDate?: Date;
}

@Injectable()
export class ServiceCoordinatorsService {
  constructor(private readonly prisma: PrismaService) {}

  async resolveAgencyForCoordinator(userId: string, tenantId: string) {
    const user = await this.prisma.user.findFirst({
      where: { id: userId, tenantId, role: 'SERVICE_COORDINATOR' },
    });
    if (!user?.agencyId) {
      throw new NotFoundException('Service coordinator not found');
    }
    const roster = await this.prisma.agencyRoster.findFirst({
      where: {
        userId,
        agencyId: user.agencyId,
        status: 'ACTIVE',
        removedAt: null,
      },
    });
    if (!roster || !user.isActive) {
      throw new ForbiddenException('Service coordinator access suspended');
    }
    const agency = await this.prisma.agency.findFirst({
      where: { id: user.agencyId, tenantId },
    });
    if (!agency) {
      throw new NotFoundException('Agency not found');
    }
    return { user, agency, roster };
  }

  async assertActiveCoordinatorRoster(
    coordinatorUserId: string,
    agencyId: string,
  ) {
    const roster = await this.prisma.agencyRoster.findFirst({
      where: {
        userId: coordinatorUserId,
        agencyId,
        role: 'SERVICE_COORDINATOR',
        status: 'ACTIVE',
        removedAt: null,
      },
      include: { user: true },
    });
    if (!roster || !roster.user.isActive) {
      throw new BadRequestException(
        'Service coordinator is not active on agency roster',
      );
    }
    return roster;
  }

  async assertChildAssignment(
    childId: string,
    coordinatorUserId: string,
    agencyId: string,
  ) {
    const assignment = await this.prisma.childServiceCoordinatorAssignment.findFirst({
      where: {
        childId,
        serviceCoordinatorId: coordinatorUserId,
        agencyId,
        status: 'ACTIVE',
        removedAt: null,
      },
    });
    if (!assignment) {
      throw new ForbiddenException('Child not assigned to this coordinator');
    }
    return assignment;
  }

  async createServiceCoordinator(
    agencyId: string,
    tenantId: string,
    adminUserId: string,
    input: CreateServiceCoordinatorInput,
  ) {
    await this.prisma.agency.findFirstOrThrow({
      where: { id: agencyId, tenantId },
    });
    const existing = await this.prisma.user.findUnique({
      where: { tenantId_email: { tenantId, email: input.email.trim() } },
    });
    if (existing) {
      throw new BadRequestException('Email already registered');
    }
    if (input.password.length < 8) {
      throw new BadRequestException('Password must be at least 8 characters');
    }

    const passwordHash = await bcrypt.hash(input.password, 10);

    const result = await this.prisma.$transaction(async (tx) => {
      const user = await tx.user.create({
        data: {
          tenantId,
          email: input.email.trim(),
          passwordHash,
          role: 'SERVICE_COORDINATOR',
          firstName: input.firstName.trim(),
          lastName: input.lastName.trim(),
          phone: input.phone?.trim(),
          agencyId,
          createdById: adminUserId,
          isActive: true,
        },
      });
      const roster = await tx.agencyRoster.create({
        data: {
          agencyId,
          userId: user.id,
          role: AgencyRosterMemberRole.SERVICE_COORDINATOR,
          status: AgencyRosterStatus.ACTIVE,
          languages: input.languages ?? [],
          notes: input.notes?.trim(),
          addedById: adminUserId,
          addedAt: new Date(),
        },
        include: {
          user: true,
          addedBy: true,
        },
      });
      return { user, roster };
    });

    await this.prisma.auditLog.create({
      data: {
        tenantId,
        actorId: adminUserId,
        action: 'USER_INVITED',
        entityType: 'service_coordinator',
        entityId: result.user.id,
        metadata: {
          event: 'service_coordinator_added',
          agencyId,
          email: input.email,
        },
      },
    });

    return result;
  }

  async getAgencyRoster(agencyId: string, tenantId: string) {
    await this.prisma.agency.findFirstOrThrow({
      where: { id: agencyId, tenantId },
    });

    const scMembers = await this.prisma.agencyRoster.findMany({
      where: { agencyId, removedAt: null },
      include: {
        user: true,
        addedBy: true,
      },
      orderBy: { addedAt: 'desc' },
    });

    const assignmentCounts = await this.prisma.childServiceCoordinatorAssignment.groupBy({
      by: ['serviceCoordinatorId'],
      where: { agencyId, status: 'ACTIVE', removedAt: null },
      _count: { _all: true },
    });
    const countMap = new Map(
      assignmentCounts.map((r) => [r.serviceCoordinatorId, r._count._all]),
    );

    return scMembers.map((m) => ({
      ...m,
      caseload: countMap.get(m.userId) ?? 0,
    }));
  }

  async updateServiceCoordinator(
    agencyId: string,
    tenantId: string,
    coordinatorUserId: string,
    adminUserId: string,
    input: UpdateServiceCoordinatorInput,
  ) {
    const roster = await this.prisma.agencyRoster.findFirst({
      where: {
        agencyId,
        userId: coordinatorUserId,
        role: 'SERVICE_COORDINATOR',
        removedAt: null,
      },
      include: { user: true },
    });
    if (!roster) {
      throw new NotFoundException('Service coordinator not on roster');
    }
    await this.prisma.agency.findFirstOrThrow({
      where: { id: agencyId, tenantId },
    });

    const [updatedRoster, updatedUser] = await this.prisma.$transaction([
      this.prisma.agencyRoster.update({
        where: { id: roster.id },
        data: {
          languages: input.languages ?? undefined,
          notes: input.notes?.trim(),
          status: input.status ?? undefined,
        },
        include: { user: true, addedBy: true },
      }),
      this.prisma.user.update({
        where: { id: coordinatorUserId },
        data: {
          firstName: input.firstName?.trim(),
          lastName: input.lastName?.trim(),
          phone: input.phone?.trim(),
          isActive:
            input.status === 'ACTIVE'
              ? true
              : input.status === 'INACTIVE' || input.status === 'SUSPENDED'
                ? false
                : undefined,
        },
      }),
    ]);

    await this.prisma.auditLog.create({
      data: {
        tenantId: roster.user.tenantId,
        actorId: adminUserId,
        action: 'UPDATE',
        entityType: 'service_coordinator',
        entityId: coordinatorUserId,
        metadata: {
          event: 'roster_status_changed',
          agencyId,
          status: input.status,
        },
      },
    });

    return { roster: updatedRoster, user: updatedUser };
  }

  async removeServiceCoordinatorFromRoster(
    agencyId: string,
    tenantId: string,
    coordinatorUserId: string,
    adminUserId: string,
  ) {
    const roster = await this.prisma.agencyRoster.findFirst({
      where: {
        agencyId,
        userId: coordinatorUserId,
        role: 'SERVICE_COORDINATOR',
        removedAt: null,
      },
      include: { user: true },
    });
    if (!roster) {
      throw new NotFoundException('Service coordinator not on roster');
    }
    await this.prisma.agency.findFirstOrThrow({
      where: { id: agencyId, tenantId },
    });

    await this.prisma.$transaction([
      this.prisma.agencyRoster.update({
        where: { id: roster.id },
        data: {
          status: 'INACTIVE',
          removedAt: new Date(),
        },
      }),
      this.prisma.user.update({
        where: { id: coordinatorUserId },
        data: { isActive: false },
      }),
      this.prisma.childServiceCoordinatorAssignment.updateMany({
        where: {
          agencyId,
          serviceCoordinatorId: coordinatorUserId,
          status: 'ACTIVE',
        },
        data: {
          status: 'REMOVED',
          removedAt: new Date(),
        },
      }),
    ]);

    await this.prisma.auditLog.create({
      data: {
        tenantId: roster.user.tenantId,
        actorId: adminUserId,
        action: 'DELETE',
        entityType: 'service_coordinator',
        entityId: coordinatorUserId,
        metadata: { event: 'service_coordinator_removed', agencyId },
      },
    });

    return { success: true };
  }

  async assignChildToCoordinator(
    agencyId: string,
    tenantId: string,
    childId: string,
    coordinatorUserId: string,
    adminUserId: string,
  ) {
    await this.prisma.agency.findFirstOrThrow({
      where: { id: agencyId, tenantId },
    });
    await this.assertActiveCoordinatorRoster(coordinatorUserId, agencyId);

    const child = await this.prisma.child.findFirst({
      where: { id: childId, tenantId },
    });
    if (!child) {
      throw new NotFoundException('Child not found in tenant');
    }

    const latestScreening = await this.latestEiParentScreening(childId, tenantId);
    const eligibility = isEiServiceEligible({
      dateOfBirth: child.dateOfBirth,
      screening: latestScreening,
    });
    if (!eligibility.eligible) {
      throw new BadRequestException(
        `Child is not eligible for service coordination: ${eligibility.reason}`,
      );
    }

    const existing = await this.prisma.childServiceCoordinatorAssignment.findFirst({
      where: {
        childId,
        serviceCoordinatorId: coordinatorUserId,
        agencyId,
        status: 'ACTIVE',
        removedAt: null,
      },
    });
    if (existing) {
      throw new BadRequestException('Child already assigned to this coordinator');
    }

    const assignment = await this.prisma.childServiceCoordinatorAssignment.create({
      data: {
        childId,
        serviceCoordinatorId: coordinatorUserId,
        agencyId,
        assignedById: adminUserId,
        status: ChildScAssignmentStatus.ACTIVE,
      },
      include: {
        child: { include: { parent: { include: { user: true } } } },
        serviceCoordinator: true,
      },
    });

    await this.prisma.auditLog.create({
      data: {
        tenantId,
        actorId: adminUserId,
        action: 'CREATE',
        entityType: 'child_sc_assignment',
        entityId: assignment.id,
        patientId: childId,
        metadata: {
          event: 'case_assigned',
          agencyId,
          coordinatorUserId,
        },
      },
    });

    return assignment;
  }

  async removeChildAssignment(
    agencyId: string,
    tenantId: string,
    assignmentId: string,
    adminUserId: string,
  ) {
    const assignment = await this.prisma.childServiceCoordinatorAssignment.findFirst({
      where: { id: assignmentId, agencyId },
      include: { child: true },
    });
    if (!assignment) {
      throw new NotFoundException('Assignment not found');
    }
    await this.prisma.agency.findFirstOrThrow({
      where: { id: agencyId, tenantId },
    });

    const updated = await this.prisma.childServiceCoordinatorAssignment.update({
      where: { id: assignmentId },
      data: {
        status: 'REMOVED',
        removedAt: new Date(),
      },
    });

    await this.prisma.auditLog.create({
      data: {
        tenantId,
        actorId: adminUserId,
        action: 'DELETE',
        entityType: 'child_sc_assignment',
        entityId: assignmentId,
        patientId: assignment.childId,
        metadata: { event: 'case_removed', agencyId },
      },
    });

    return updated;
  }

  async getCoordinatorDashboard(
    coordinatorUserId: string,
    tenantId: string,
  ) {
    const { agency } = await this.resolveAgencyForCoordinator(
      coordinatorUserId,
      tenantId,
    );

    const assignments = await this.prisma.childServiceCoordinatorAssignment.findMany({
      where: {
        serviceCoordinatorId: coordinatorUserId,
        agencyId: agency.id,
        status: 'ACTIVE',
        removedAt: null,
      },
      include: {
        child: {
          include: {
            parent: { include: { user: true } },
          },
        },
      },
      orderBy: { assignedAt: 'desc' },
    });

    const childIds = assignments.map((a) => a.childId);
    const now = new Date();
    const urgentCount = assignments.filter((a) => a.isUrgent).length;

    const initialScreenings = childIds.length
      ? await this.prisma.eiInitialScreening.findMany({
          where: { childId: { in: childIds }, agencyId: agency.id },
          orderBy: { updatedAt: 'desc' },
        })
      : [];

    const ongoingScreenings = childIds.length
      ? await this.prisma.eiOngoingScreening.findMany({
          where: { childId: { in: childIds }, agencyId: agency.id },
          orderBy: { updatedAt: 'desc' },
        })
      : [];

    const followUpsDue = [
      ...initialScreenings.filter(
        (s) =>
          s.followUpRequired &&
          s.followUpDueDate &&
          s.followUpDueDate <= now,
      ),
      ...ongoingScreenings.filter(
        (s) =>
          s.followUpRequired &&
          s.followUpDueDate &&
          s.followUpDueDate <= now,
      ),
    ].length;

    const screeningsDue = childIds.filter(
      (id) => !initialScreenings.some((s) => s.childId === id && s.status === 'SUBMITTED'),
    ).length;

    return {
      totalCases: assignments.length,
      urgentCases: urgentCount,
      screeningsDue,
      followUpsDue,
      evaluationsPending: 0,
      ifspReviewsDue: 0,
      cases: assignments.map((a) => this.mapCaseSummary(a, initialScreenings, ongoingScreenings)),
    };
  }

  private mapCaseSummary(
    assignment: {
      id: string;
      isUrgent: boolean;
      child: {
        id: string;
        firstName: string;
        lastName: string;
        dateOfBirth: Date;
        parent: {
          user: { firstName: string; lastName: string };
        };
      };
    },
    initialScreenings: Array<{
      childId: string;
      status: EiScreeningStatus;
      followUpDueDate: Date | null;
      priorityLevel: string;
    }>,
    ongoingScreenings: Array<{
      childId: string;
      followUpDueDate: Date | null;
      priorityLevel: string;
    }>,
  ) {
    const initial = initialScreenings.find((s) => s.childId === assignment.child.id);
    const ongoing = ongoingScreenings.find((s) => s.childId === assignment.child.id);
    const followUpDate =
      ongoing?.followUpDueDate ?? initial?.followUpDueDate ?? null;

    return {
      assignmentId: assignment.id,
      childId: assignment.child.id,
      childName: `${assignment.child.firstName} ${assignment.child.lastName}`,
      dateOfBirth: assignment.child.dateOfBirth,
      parentName: `${assignment.child.parent.user.firstName} ${assignment.child.parent.user.lastName}`,
      caseStatus: 'ACTIVE',
      screeningStatus: initial?.status ?? 'NOT_STARTED',
      evaluationStatus: 'PENDING',
      ifspStatus: 'IN_PROGRESS',
      nextFollowUpDate: followUpDate ?? undefined,
      isUrgent: assignment.isUrgent,
      priorityLevel: (ongoing?.priorityLevel ??
        initial?.priorityLevel ??
        'LOW') as 'LOW' | 'MEDIUM' | 'HIGH',
      assignedProviders: [],
    };
  }

  async getCaseDetail(
    coordinatorUserId: string,
    tenantId: string,
    childId: string,
  ) {
    const { agency } = await this.resolveAgencyForCoordinator(
      coordinatorUserId,
      tenantId,
    );
    await this.assertChildAssignment(childId, coordinatorUserId, agency.id);

    const child = await this.prisma.child.findFirstOrThrow({
      where: { id: childId, tenantId },
      include: {
        parent: { include: { user: true } },
      },
    });

    const initialScreening = await this.prisma.eiInitialScreening.findFirst({
      where: { childId, agencyId: agency.id },
      orderBy: { updatedAt: 'desc' },
    });
    const ongoingScreenings = await this.prisma.eiOngoingScreening.findMany({
      where: { childId, agencyId: agency.id },
      orderBy: { createdAt: 'desc' },
      take: 5,
    });
    const notes = await this.prisma.serviceCoordinationNote.findMany({
      where: { childId, agencyId: agency.id },
      orderBy: { createdAt: 'desc' },
      take: 20,
    });

    const latestParentScreening = await this.latestEiParentScreening(
      childId,
      tenantId,
    );
    const screeningPrefill = buildEiScreeningPrefill(
      child,
      child.parent.user,
      latestParentScreening ?? undefined,
    );

    return {
      child,
      initialScreening,
      ongoingScreenings,
      notes,
      screeningPrefill,
    };
  }

  async upsertInitialScreening(
    coordinatorUserId: string,
    tenantId: string,
    childId: string,
    input: UpsertEiScreeningInput,
  ) {
    const { agency } = await this.resolveAgencyForCoordinator(
      coordinatorUserId,
      tenantId,
    );
    await this.assertChildAssignment(childId, coordinatorUserId, agency.id);

    const child = await this.prisma.child.findFirstOrThrow({
      where: { id: childId, tenantId },
      include: { parent: { include: { user: true } } },
    });

    const latestParentScreening = await this.latestEiParentScreening(
      childId,
      tenantId,
    );
    const answers = mergePrefillIntoAnswers(
      buildEiScreeningPrefill(
        child,
        child.parent.user,
        latestParentScreening ?? undefined,
      ),
      (input.answersJson ?? {}) as Record<string, unknown>,
    );
    const priority = deriveEiScreeningPriority(answers);
    const completion = screeningCompletionPercent(answers, EI_INITIAL_REQUIRED_KEYS);
    const status: EiScreeningStatus =
      input.submit && completion >= 80 ? 'SUBMITTED' : input.submit ? 'DRAFT' : 'DRAFT';

    if (input.submit && completion < 80) {
      throw new BadRequestException(
        'Complete required fields before submitting initial screening',
      );
    }

    const existing = await this.prisma.eiInitialScreening.findFirst({
      where: { childId, agencyId: agency.id, serviceCoordinatorId: coordinatorUserId },
      orderBy: { updatedAt: 'desc' },
    });

    const data: Prisma.EiInitialScreeningUncheckedCreateInput = {
      childId,
      parentId: child.parentId,
      agencyId: agency.id,
      serviceCoordinatorId: coordinatorUserId,
      answersJson: answers as Prisma.InputJsonValue,
      priorityLevel: priority,
      followUpRequired: input.followUpRequired ?? false,
      followUpDueDate: input.followUpDueDate,
      notes: input.notes?.trim(),
      status,
    };

    const screening = existing
      ? await this.prisma.eiInitialScreening.update({
          where: { id: existing.id },
          data,
        })
      : await this.prisma.eiInitialScreening.create({ data });

    await this.prisma.auditLog.create({
      data: {
        tenantId,
        actorId: coordinatorUserId,
        action: existing ? 'UPDATE' : 'CREATE',
        entityType: 'ei_initial_screening',
        entityId: screening.id,
        patientId: childId,
        metadata: { event: 'screening_saved', status },
      },
    });

    return { screening, completionPercent: completion };
  }

  async upsertOngoingScreening(
    coordinatorUserId: string,
    tenantId: string,
    childId: string,
    input: UpsertEiScreeningInput,
  ) {
    const { agency } = await this.resolveAgencyForCoordinator(
      coordinatorUserId,
      tenantId,
    );
    await this.assertChildAssignment(childId, coordinatorUserId, agency.id);

    const child = await this.prisma.child.findFirstOrThrow({
      where: { id: childId, tenantId },
    });

    const answers = (input.answersJson ?? {}) as Record<string, unknown>;
    const priority = deriveEiScreeningPriority(answers);
    const completion = screeningCompletionPercent(answers, EI_ONGOING_REQUIRED_KEYS);
    const status: EiScreeningStatus = input.submit ? 'SUBMITTED' : 'DRAFT';

    if (input.submit && completion < 80) {
      throw new BadRequestException(
        'Complete required fields before submitting ongoing screening',
      );
    }

    const screening = await this.prisma.eiOngoingScreening.create({
      data: {
        childId,
        parentId: child.parentId,
        agencyId: agency.id,
        serviceCoordinatorId: coordinatorUserId,
        answersJson: answers as Prisma.InputJsonValue,
        progressSummary: input.progressSummary?.trim(),
        newConcerns: input.newConcerns?.trim(),
        priorityLevel: priority,
        followUpRequired: input.followUpRequired ?? false,
        followUpDueDate: input.followUpDueDate,
        notes: input.notes?.trim(),
        status,
      },
    });

    await this.prisma.auditLog.create({
      data: {
        tenantId,
        actorId: coordinatorUserId,
        action: 'CREATE',
        entityType: 'ei_ongoing_screening',
        entityId: screening.id,
        patientId: childId,
        metadata: { event: 'ongoing_screening_saved', status },
      },
    });

    return { screening, completionPercent: completion };
  }

  async createNote(
    coordinatorUserId: string,
    tenantId: string,
    childId: string,
    input: CreateScNoteInput,
  ) {
    const { agency } = await this.resolveAgencyForCoordinator(
      coordinatorUserId,
      tenantId,
    );
    await this.assertChildAssignment(childId, coordinatorUserId, agency.id);

    const child = await this.prisma.child.findFirstOrThrow({
      where: { id: childId, tenantId },
    });

    const note = await this.prisma.serviceCoordinationNote.create({
      data: {
        childId,
        parentId: child.parentId,
        agencyId: agency.id,
        serviceCoordinatorId: coordinatorUserId,
        noteType: input.noteType.trim(),
        noteText: input.noteText.trim(),
        actionRequired: input.actionRequired ?? false,
        actionDueDate: input.actionDueDate,
      },
    });

    await this.prisma.auditLog.create({
      data: {
        tenantId,
        actorId: coordinatorUserId,
        action: 'NOTE_CREATED',
        entityType: 'service_coordination_note',
        entityId: note.id,
        patientId: childId,
        metadata: { event: 'note_created' },
      },
    });

    return note;
  }

  async flagUrgentCase(
    coordinatorUserId: string,
    tenantId: string,
    childId: string,
    urgent: boolean,
  ) {
    const { agency } = await this.resolveAgencyForCoordinator(
      coordinatorUserId,
      tenantId,
    );
    const assignment = await this.assertChildAssignment(
      childId,
      coordinatorUserId,
      agency.id,
    );

    const updated = await this.prisma.childServiceCoordinatorAssignment.update({
      where: { id: assignment.id },
      data: { isUrgent: urgent },
    });

    await this.prisma.auditLog.create({
      data: {
        tenantId,
        actorId: coordinatorUserId,
        action: 'UPDATE',
        entityType: 'child_sc_assignment',
        entityId: assignment.id,
        patientId: childId,
        metadata: { event: 'urgent_case_flagged', urgent },
      },
    });

    return updated;
  }

  async getFollowUpReminders(coordinatorUserId: string, tenantId: string) {
    const { agency } = await this.resolveAgencyForCoordinator(
      coordinatorUserId,
      tenantId,
    );
    const now = new Date();

    const assignments = await this.prisma.childServiceCoordinatorAssignment.findMany({
      where: {
        serviceCoordinatorId: coordinatorUserId,
        agencyId: agency.id,
        status: 'ACTIVE',
      },
      select: { childId: true },
    });
    const childIds = assignments.map((a) => a.childId);
    if (childIds.length === 0) return [];

    const [initial, ongoing, notes] = await Promise.all([
      this.prisma.eiInitialScreening.findMany({
        where: {
          childId: { in: childIds },
          agencyId: agency.id,
          followUpRequired: true,
          followUpDueDate: { not: null },
        },
        include: { child: true },
      }),
      this.prisma.eiOngoingScreening.findMany({
        where: {
          childId: { in: childIds },
          agencyId: agency.id,
          followUpRequired: true,
          followUpDueDate: { not: null },
        },
        include: { child: true },
      }),
      this.prisma.serviceCoordinationNote.findMany({
        where: {
          childId: { in: childIds },
          agencyId: agency.id,
          actionRequired: true,
          actionDueDate: { not: null },
        },
        include: { child: true },
      }),
    ]);

    const reminders = [
      ...initial.map((s) => ({
        type: 'INITIAL_SCREENING_FOLLOW_UP',
        childId: s.childId,
        childName: `${s.child.firstName} ${s.child.lastName}`,
        dueDate: s.followUpDueDate!,
        overdue: s.followUpDueDate! <= now,
      })),
      ...ongoing.map((s) => ({
        type: 'ONGOING_SCREENING_FOLLOW_UP',
        childId: s.childId,
        childName: `${s.child.firstName} ${s.child.lastName}`,
        dueDate: s.followUpDueDate!,
        overdue: s.followUpDueDate! <= now,
      })),
      ...notes.map((n) => ({
        type: 'ACTION_ITEM',
        childId: n.childId,
        childName: `${n.child.firstName} ${n.child.lastName}`,
        dueDate: n.actionDueDate!,
        overdue: n.actionDueDate! <= now,
      })),
    ];

    return reminders.sort(
      (a, b) => a.dueDate.getTime() - b.dueDate.getTime(),
    );
  }

  async getAgencyCases(agencyId: string, tenantId: string) {
    await this.prisma.agency.findFirstOrThrow({
      where: { id: agencyId, tenantId },
    });

    const children = await this.prisma.child.findMany({
      where: { tenantId },
      include: {
        parent: { include: { user: true } },
        scAssignments: {
          where: { agencyId, status: 'ACTIVE', removedAt: null },
          include: {
            serviceCoordinator: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
      take: 200,
    });

    const childIds = children.map((c) => c.id);
    const screenings = childIds.length
      ? await this.prisma.screeningResponse.findMany({
          where: {
            childId: { in: childIds },
            tenantId,
            isDraft: false,
            template: { therapyType: 'EARLY_INTERVENTION' },
          },
          include: { template: true },
          orderBy: { completedAt: 'desc' },
        })
      : [];

    const screeningByChild = new Map<string, (typeof screenings)[number]>();
    for (const row of screenings) {
      if (!screeningByChild.has(row.childId)) {
        screeningByChild.set(row.childId, row);
      }
    }

    return children
      .map((child) => {
        const screening = screeningByChild.get(child.id) ?? null;
        const eligibility = isEiServiceEligible({
          dateOfBirth: child.dateOfBirth,
          screening,
        });
        return {
          child,
          screening,
          eiEligible: eligibility.eligible,
          eligibilityReason: eligibility.reason,
        };
      })
      .filter(
        (row) =>
          row.eiEligible || row.child.scAssignments.some((a) => a.status === 'ACTIVE'),
      );
  }

  private async latestEiParentScreening(childId: string, tenantId: string) {
    return this.prisma.screeningResponse.findFirst({
      where: {
        childId,
        tenantId,
        isDraft: false,
        template: { therapyType: 'EARLY_INTERVENTION' },
      },
      include: { template: true },
      orderBy: { completedAt: 'desc' },
    });
  }

  async findCaseloadChartsByCoordinatorUserId(
    coordinatorUserId: string,
    tenantId: string,
  ) {
    const { agency } = await this.resolveAgencyForCoordinator(
      coordinatorUserId,
      tenantId,
    );

    const assignments = await this.prisma.childServiceCoordinatorAssignment.findMany({
      where: {
        serviceCoordinatorId: coordinatorUserId,
        agencyId: agency.id,
        status: 'ACTIVE',
        removedAt: null,
      },
      include: {
        child: { include: { parent: { include: { user: true } } } },
      },
    });

    const childIds = assignments.map((a) => a.childId);
    if (childIds.length === 0) return [];

    const [appointments, sessions] = await Promise.all([
      this.prisma.appointment.findMany({
        where: {
          tenantId,
          childId: { in: childIds },
          status: { notIn: ['CANCELLED', 'NO_SHOW'] },
        },
        include: {
          child: { include: { parent: { include: { user: true } } } },
        },
        orderBy: { scheduledStart: 'desc' },
      }),
      this.prisma.session.findMany({
        where: { tenantId, childId: { in: childIds } },
        orderBy: { checkOutAt: 'desc' },
      }),
    ]);

    const seeds = assignments.map((assignment) => ({
      child: assignment.child,
      parentName: `${assignment.child.parent.user.firstName} ${assignment.child.parent.user.lastName}`,
    }));

    return buildCaseloadCharts(appointments, sessions, seeds);
  }
}
