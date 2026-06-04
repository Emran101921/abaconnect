import { Args, ID, Mutation, Query, Resolver } from '@nestjs/graphql';
import { Roles } from '../common/decorators/roles.decorator';
import { AuthUser, CurrentUser } from '../common/decorators/current-user.decorator';
import { AgenciesService } from '../agencies/agencies.service';
import {
  AgencyAppointmentType,
  AgencyDashboardType,
  AgencyTherapistType,
} from './types/agency.types';

@Resolver()
@Roles('AGENCY_ADMIN')
export class AgencyResolver {
  constructor(private readonly agenciesService: AgenciesService) {}

  @Query(() => AgencyDashboardType, { name: 'agencyDashboard' })
  async agencyDashboard(
    @CurrentUser() user: AuthUser,
  ): Promise<AgencyDashboardType> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    return this.agenciesService.getDashboardForTenant(user.tenantId);
  }

  @Query(() => [AgencyAppointmentType], { name: 'agencyUpcomingAppointments' })
  async agencyUpcomingAppointments(
    @CurrentUser() user: AuthUser,
  ): Promise<AgencyAppointmentType[]> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    const rows = await this.agenciesService.listUpcomingAppointmentsForTenant(
      user.tenantId,
    );
    return rows.map((a) => ({
      id: a.id,
      scheduledStart: a.scheduledStart,
      scheduledEnd: a.scheduledEnd,
      therapyType: a.therapyType,
      status: a.status,
      locationType: a.locationType,
      childName: `${a.child.firstName} ${a.child.lastName}`,
      therapistName: `${a.therapist.user.firstName} ${a.therapist.user.lastName}`,
    }));
  }

  @Query(() => [AgencyTherapistType], { name: 'agencyTherapists' })
  async agencyTherapists(
    @CurrentUser() user: AuthUser,
  ): Promise<AgencyTherapistType[]> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    const rows = await this.agenciesService.listTherapistsForTenant(user.tenantId);
    return rows.map((t) => ({
      id: t.id,
      isVerified: t.isVerified,
      licenseNumber: t.licenseNumber ?? undefined,
      user: t.user
        ? {
            firstName: t.user.firstName,
            lastName: t.user.lastName,
            email: t.user.email,
          }
        : undefined,
    }));
  }

  @Query(() => [AgencyTherapistType], { name: 'agencyTherapistsAvailableToInvite' })
  async agencyTherapistsAvailableToInvite(
    @CurrentUser() user: AuthUser,
  ): Promise<AgencyTherapistType[]> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    const rows = await this.agenciesService.listUnlinkedTherapistsForTenant(
      user.tenantId,
    );
    return rows.map((t) => ({
      id: t.id,
      isVerified: t.isVerified,
      licenseNumber: t.licenseNumber ?? undefined,
      user: t.user
        ? {
            firstName: t.user.firstName,
            lastName: t.user.lastName,
            email: t.user.email,
          }
        : undefined,
    }));
  }

  @Mutation(() => Boolean, { name: 'removeAgencyTherapist' })
  async removeAgencyTherapist(
    @CurrentUser() user: AuthUser,
    @Args('therapistId', { type: () => ID }) therapistId: string,
  ): Promise<boolean> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    await this.agenciesService.removeTherapistFromAgency(
      user.tenantId,
      therapistId,
    );
    return true;
  }

  @Mutation(() => AgencyTherapistType, { name: 'inviteAgencyTherapist' })
  async inviteAgencyTherapist(
    @CurrentUser() user: AuthUser,
    @Args('therapistId', { type: () => ID }) therapistId: string,
  ): Promise<AgencyTherapistType> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    const link = await this.agenciesService.inviteTherapistForTenant(
      user.tenantId,
      therapistId,
    );
    const t = link.therapist;
    return {
      id: t.id,
      isVerified: t.isVerified,
      licenseNumber: t.licenseNumber ?? undefined,
      user: t.user
        ? {
            firstName: t.user.firstName,
            lastName: t.user.lastName,
            email: t.user.email,
          }
        : undefined,
    };
  }
}
