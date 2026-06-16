import { Args, ID, Mutation, Query, Resolver } from '@nestjs/graphql';
import { Roles } from '../common/decorators/roles.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { AgenciesService } from '../agencies/agencies.service';
import { PrismaService } from '../prisma/prisma.service';
import { ServiceCoordinatorsService } from '../service-coordinators/service-coordinators.service';
import {
  CreateScNoteInput,
  CreateServiceCoordinatorInput,
  UpdateServiceCoordinatorInput,
  UpsertEiScreeningInput,
} from './inputs/service-coordinator.inputs';
import {
  AgencyCaseType,
  AgencyRosterMemberType,
  EiScreeningResultType,
  EiScreeningType,
  ScCaseDetailType,
  ScDashboardType,
  ScFollowUpReminderType,
  ServiceCoordinationNoteType,
} from './types/service-coordinator.types';

function mapEiScreening(
  s: {
    id: string;
    childId: string;
    answersJson: unknown;
    status: EiScreeningType['status'];
    priorityLevel: EiScreeningType['priorityLevel'];
    followUpRequired: boolean;
    followUpDueDate: Date | null;
    notes: string | null;
    progressSummary?: string | null;
    newConcerns?: string | null;
    createdAt: Date;
    updatedAt: Date;
  },
): EiScreeningType {
  return {
    id: s.id,
    childId: s.childId,
    answersJson:
      typeof s.answersJson === 'string'
        ? s.answersJson
        : JSON.stringify(s.answersJson ?? {}),
    status: s.status,
    priorityLevel: s.priorityLevel,
    followUpRequired: s.followUpRequired,
    followUpDueDate: s.followUpDueDate ?? undefined,
    notes: s.notes ?? undefined,
    progressSummary: s.progressSummary ?? undefined,
    newConcerns: s.newConcerns ?? undefined,
    createdAt: s.createdAt,
    updatedAt: s.updatedAt,
  };
}

@Resolver()
export class ServiceCoordinatorResolver {
  constructor(
    private readonly scService: ServiceCoordinatorsService,
    private readonly agenciesService: AgenciesService,
    private readonly prisma: PrismaService,
  ) {}

  @Query(() => ScDashboardType, { name: 'serviceCoordinatorDashboard' })
  @Roles('SERVICE_COORDINATOR')
  async serviceCoordinatorDashboard(
    @CurrentUser() user: AuthUser,
  ): Promise<ScDashboardType> {
    if (!user.tenantId) throw new Error('Tenant required');
    return this.scService.getCoordinatorDashboard(user.id, user.tenantId);
  }

  @Query(() => ScCaseDetailType, { name: 'serviceCoordinatorCase' })
  @Roles('SERVICE_COORDINATOR')
  async serviceCoordinatorCase(
    @CurrentUser() user: AuthUser,
    @Args('childId', { type: () => ID }) childId: string,
  ): Promise<ScCaseDetailType> {
    if (!user.tenantId) throw new Error('Tenant required');
    const detail = await this.scService.getCaseDetail(
      user.id,
      user.tenantId,
      childId,
    );
    const parentUser = detail.child.parent.user;
    return {
      childId: detail.child.id,
      childName: `${detail.child.firstName} ${detail.child.lastName}`,
      dateOfBirth: detail.child.dateOfBirth,
      parentName: `${parentUser.firstName} ${parentUser.lastName}`,
      parentEmail: parentUser.email,
      parentPhone: parentUser.phone ?? undefined,
      guardianPhone: detail.child.guardianPhone ?? undefined,
      initialScreening: detail.initialScreening
        ? mapEiScreening(detail.initialScreening)
        : undefined,
      ongoingScreenings: detail.ongoingScreenings.map(mapEiScreening),
      notes: detail.notes.map((n) => ({
        id: n.id,
        childId: n.childId,
        noteType: n.noteType,
        noteText: n.noteText,
        actionRequired: n.actionRequired,
        actionDueDate: n.actionDueDate ?? undefined,
        createdAt: n.createdAt,
      })),
    };
  }

  @Query(() => [ScFollowUpReminderType], { name: 'serviceCoordinatorFollowUps' })
  @Roles('SERVICE_COORDINATOR')
  async serviceCoordinatorFollowUps(
    @CurrentUser() user: AuthUser,
  ): Promise<ScFollowUpReminderType[]> {
    if (!user.tenantId) throw new Error('Tenant required');
    return this.scService.getFollowUpReminders(user.id, user.tenantId);
  }

  @Mutation(() => EiScreeningResultType, { name: 'upsertInitialEiScreening' })
  @Roles('SERVICE_COORDINATOR')
  async upsertInitialEiScreening(
    @CurrentUser() user: AuthUser,
    @Args('childId', { type: () => ID }) childId: string,
    @Args('input') input: UpsertEiScreeningInput,
  ): Promise<EiScreeningResultType> {
    if (!user.tenantId) throw new Error('Tenant required');
    const result = await this.scService.upsertInitialScreening(
      user.id,
      user.tenantId,
      childId,
      {
        ...input,
        answersJson: input.answersJson
          ? (JSON.parse(input.answersJson) as Record<string, unknown>)
          : undefined,
      },
    );
    return {
      screening: mapEiScreening(result.screening),
      completionPercent: result.completionPercent,
    };
  }

  @Mutation(() => EiScreeningResultType, { name: 'upsertOngoingEiScreening' })
  @Roles('SERVICE_COORDINATOR')
  async upsertOngoingEiScreening(
    @CurrentUser() user: AuthUser,
    @Args('childId', { type: () => ID }) childId: string,
    @Args('input') input: UpsertEiScreeningInput,
  ): Promise<EiScreeningResultType> {
    if (!user.tenantId) throw new Error('Tenant required');
    const result = await this.scService.upsertOngoingScreening(
      user.id,
      user.tenantId,
      childId,
      {
        ...input,
        answersJson: input.answersJson
          ? (JSON.parse(input.answersJson) as Record<string, unknown>)
          : undefined,
      },
    );
    return {
      screening: mapEiScreening(result.screening),
      completionPercent: result.completionPercent,
    };
  }

  @Mutation(() => ServiceCoordinationNoteType, { name: 'createServiceCoordinationNote' })
  @Roles('SERVICE_COORDINATOR')
  async createServiceCoordinationNote(
    @CurrentUser() user: AuthUser,
    @Args('childId', { type: () => ID }) childId: string,
    @Args('input') input: CreateScNoteInput,
  ): Promise<ServiceCoordinationNoteType> {
    if (!user.tenantId) throw new Error('Tenant required');
    const note = await this.scService.createNote(
      user.id,
      user.tenantId,
      childId,
      input,
    );
    return {
      id: note.id,
      childId: note.childId,
      noteType: note.noteType,
      noteText: note.noteText,
      actionRequired: note.actionRequired,
      actionDueDate: note.actionDueDate ?? undefined,
      createdAt: note.createdAt,
    };
  }

  @Mutation(() => Boolean, { name: 'flagUrgentScCase' })
  @Roles('SERVICE_COORDINATOR')
  async flagUrgentScCase(
    @CurrentUser() user: AuthUser,
    @Args('childId', { type: () => ID }) childId: string,
    @Args('urgent') urgent: boolean,
  ): Promise<boolean> {
    if (!user.tenantId) throw new Error('Tenant required');
    await this.scService.flagUrgentCase(user.id, user.tenantId, childId, urgent);
    return true;
  }

  @Query(() => [AgencyRosterMemberType], { name: 'agencyRosterMembers' })
  @Roles('AGENCY_ADMIN', 'PLATFORM_ADMIN')
  async agencyRosterMembers(
    @CurrentUser() user: AuthUser,
  ): Promise<AgencyRosterMemberType[]> {
    if (!user.tenantId) throw new Error('Tenant required');
    const agency = await this.resolveAgencyForAdminOrPlatform(user);
    const members = await this.scService.getAgencyRoster(
      agency.id,
      user.tenantId!,
    );
    return members.map((m) => ({
      id: m.id,
      userId: m.userId,
      email: m.user.email,
      firstName: m.user.firstName,
      lastName: m.user.lastName,
      phone: m.user.phone ?? undefined,
      role: m.role,
      status: m.status,
      languages: m.languages,
      caseload: m.caseload,
      notes: m.notes ?? undefined,
      addedByName: `${m.addedBy.firstName} ${m.addedBy.lastName}`,
      addedAt: m.addedAt,
      lastLoginAt: m.user.lastLoginAt ?? undefined,
      isActive: m.user.isActive,
    }));
  }

  @Mutation(() => AgencyRosterMemberType, { name: 'createServiceCoordinator' })
  @Roles('AGENCY_ADMIN', 'PLATFORM_ADMIN')
  async createServiceCoordinator(
    @CurrentUser() user: AuthUser,
    @Args('input') input: CreateServiceCoordinatorInput,
  ): Promise<AgencyRosterMemberType> {
    if (!user.tenantId) throw new Error('Tenant required');
    const agency = await this.resolveAgencyForAdminOrPlatform(user);
    const { user: scUser, roster } = await this.scService.createServiceCoordinator(
      agency.id,
      user.tenantId!,
      user.id,
      input,
    );
    return this.mapRosterMember(roster, scUser, 0);
  }

  @Mutation(() => AgencyRosterMemberType, { name: 'updateServiceCoordinator' })
  @Roles('AGENCY_ADMIN', 'PLATFORM_ADMIN')
  async updateServiceCoordinator(
    @CurrentUser() user: AuthUser,
    @Args('coordinatorUserId', { type: () => ID }) coordinatorUserId: string,
    @Args('input') input: UpdateServiceCoordinatorInput,
  ): Promise<AgencyRosterMemberType> {
    if (!user.tenantId) throw new Error('Tenant required');
    const agency = await this.resolveAgencyForAdminOrPlatform(user);
    const { roster, user: scUser } = await this.scService.updateServiceCoordinator(
      agency.id,
      user.tenantId!,
      coordinatorUserId,
      user.id,
      input,
    );
    const caseload = await this.prisma.childServiceCoordinatorAssignment.count({
      where: {
        agencyId: agency.id,
        serviceCoordinatorId: coordinatorUserId,
        status: 'ACTIVE',
      },
    });
    return this.mapRosterMember(roster, scUser, caseload);
  }

  @Mutation(() => Boolean, { name: 'removeServiceCoordinatorFromRoster' })
  @Roles('AGENCY_ADMIN', 'PLATFORM_ADMIN')
  async removeServiceCoordinatorFromRoster(
    @CurrentUser() user: AuthUser,
    @Args('coordinatorUserId', { type: () => ID }) coordinatorUserId: string,
  ): Promise<boolean> {
    if (!user.tenantId) throw new Error('Tenant required');
    const agency = await this.resolveAgencyForAdminOrPlatform(user);
    await this.scService.removeServiceCoordinatorFromRoster(
      agency.id,
      user.tenantId!,
      coordinatorUserId,
      user.id,
    );
    return true;
  }

  @Mutation(() => Boolean, { name: 'assignChildToServiceCoordinator' })
  @Roles('AGENCY_ADMIN', 'PLATFORM_ADMIN')
  async assignChildToServiceCoordinator(
    @CurrentUser() user: AuthUser,
    @Args('childId', { type: () => ID }) childId: string,
    @Args('coordinatorUserId', { type: () => ID }) coordinatorUserId: string,
  ): Promise<boolean> {
    if (!user.tenantId) throw new Error('Tenant required');
    const agency = await this.resolveAgencyForAdminOrPlatform(user);
    await this.scService.assignChildToCoordinator(
      agency.id,
      user.tenantId!,
      childId,
      coordinatorUserId,
      user.id,
    );
    return true;
  }

  @Mutation(() => Boolean, { name: 'removeChildScAssignment' })
  @Roles('AGENCY_ADMIN', 'PLATFORM_ADMIN')
  async removeChildScAssignment(
    @CurrentUser() user: AuthUser,
    @Args('assignmentId', { type: () => ID }) assignmentId: string,
  ): Promise<boolean> {
    if (!user.tenantId) throw new Error('Tenant required');
    const agency = await this.resolveAgencyForAdminOrPlatform(user);
    await this.scService.removeChildAssignment(
      agency.id,
      user.tenantId!,
      assignmentId,
      user.id,
    );
    return true;
  }

  @Query(() => [AgencyCaseType], { name: 'agencyCases' })
  @Roles('AGENCY_ADMIN', 'PLATFORM_ADMIN')
  async agencyCases(@CurrentUser() user: AuthUser): Promise<AgencyCaseType[]> {
    if (!user.tenantId) throw new Error('Tenant required');
    const agency = await this.resolveAgencyForAdminOrPlatform(user);
    const children = await this.scService.getAgencyCases(
      agency.id,
      user.tenantId!,
    );
    return children.map((c) => {
      const assignment = c.scAssignments[0];
      return {
        childId: c.id,
        childName: `${c.firstName} ${c.lastName}`,
        parentName: `${c.parent.user.firstName} ${c.parent.user.lastName}`,
        assignedCoordinatorId: assignment?.serviceCoordinatorId,
        assignedCoordinatorName: assignment
          ? `${assignment.serviceCoordinator.firstName} ${assignment.serviceCoordinator.lastName}`
          : undefined,
        assignmentId: assignment?.id,
      };
    });
  }

  private async resolveAgencyForAdminOrPlatform(user: AuthUser) {
    if (user.roles?.includes('PLATFORM_ADMIN')) {
      const agency = await this.prisma.agency.findFirst({
        where: { tenantId: user.tenantId! },
        orderBy: { createdAt: 'asc' },
      });
      if (!agency) throw new Error('Agency not found');
      return agency;
    }
    return this.agenciesService.resolveAgencyForAdmin(
      user.id,
      user.tenantId!,
    );
  }

  private mapRosterMember(
    roster: {
      id: string;
      userId: string;
      role: AgencyRosterMemberType['role'];
      status: AgencyRosterMemberType['status'];
      languages: string[];
      notes: string | null;
      addedAt: Date;
      addedBy: { firstName: string; lastName: string };
    },
    scUser: {
      id: string;
      email: string;
      firstName: string;
      lastName: string;
      phone: string | null;
      lastLoginAt: Date | null;
      isActive: boolean;
    },
    caseload: number,
  ): AgencyRosterMemberType {
    return {
      id: roster.id,
      userId: scUser.id,
      email: scUser.email,
      firstName: scUser.firstName,
      lastName: scUser.lastName,
      phone: scUser.phone ?? undefined,
      role: roster.role,
      status: roster.status,
      languages: roster.languages,
      caseload,
      notes: roster.notes ?? undefined,
      addedByName: `${roster.addedBy.firstName} ${roster.addedBy.lastName}`,
      addedAt: roster.addedAt,
      lastLoginAt: scUser.lastLoginAt ?? undefined,
      isActive: scUser.isActive,
    };
  }
}
