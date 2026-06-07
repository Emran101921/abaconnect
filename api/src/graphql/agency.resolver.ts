import { Args, ID, Mutation, Query, Resolver } from '@nestjs/graphql';
import { Roles } from '../common/decorators/roles.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { AgenciesService } from '../agencies/agencies.service';
import { InsuranceService } from '../insurance/insurance.service';
import { ScreeningsService } from '../screenings/screenings.service';
import {
  AgencyAppointmentType,
  AgencyDashboardType,
  AgencyTherapistType,
} from './types/agency.types';
import { AdminInsuranceClaimType } from './types/admin.types';
import {
  AnalyticsScreeningDetailType,
  ClaimsPipelineDashboardType,
  ScreeningFunnelDashboardType,
} from './types/dashboard.types';

@Resolver()
@Roles('AGENCY_ADMIN')
export class AgencyResolver {
  constructor(
    private readonly agenciesService: AgenciesService,
    private readonly insuranceService: InsuranceService,
    private readonly screeningsService: ScreeningsService,
  ) {}

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
    const rows = await this.agenciesService.listTherapistsForTenant(
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

  @Query(() => [AgencyTherapistType], {
    name: 'agencyTherapistsAvailableToInvite',
  })
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

  @Query(() => ClaimsPipelineDashboardType, { name: 'agencyClaimsPipeline' })
  async agencyClaimsPipeline(
    @CurrentUser() user: AuthUser,
  ): Promise<ClaimsPipelineDashboardType> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    const pipeline = await this.insuranceService.getClaimsPipelineForTenant(
      user.tenantId,
    );
    return {
      summary: pipeline.summary,
      recentClaims: pipeline.recentClaims.map((c) => ({
        id: c.id,
        status: c.status,
        payerName: c.payerName,
        billedAmount: Number(c.billedAmount),
        serviceDate: c.serviceDate,
        childName: c.child
          ? `${c.child.firstName} ${c.child.lastName}`
          : undefined,
        claimNumber: c.claimNumber ?? undefined,
      })),
    };
  }

  @Query(() => ScreeningFunnelDashboardType, { name: 'agencyScreeningFunnel' })
  async agencyScreeningFunnel(
    @CurrentUser() user: AuthUser,
  ): Promise<ScreeningFunnelDashboardType> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    const funnel = await this.screeningsService.getScreeningFunnelForTenant(
      user.tenantId,
    );
    return {
      summary: funnel.summary,
      recentScreenings: funnel.recentScreenings.map((r) => ({
        id: r.id,
        completedAt: r.completedAt,
        childName: r.child
          ? `${r.child.firstName} ${r.child.lastName}`
          : undefined,
        templateName: r.template?.name,
        score: r.score != null ? Number(r.score) : undefined,
        riskLevel: r.riskLevel ?? undefined,
      })),
    };
  }

  @Query(() => AdminInsuranceClaimType, { name: 'agencyAnalyticsClaimDetail' })
  async agencyAnalyticsClaimDetail(
    @CurrentUser() user: AuthUser,
    @Args('claimId', { type: () => ID }) claimId: string,
  ): Promise<AdminInsuranceClaimType> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    const row = await this.insuranceService.getClaimForTenant(
      user.tenantId,
      claimId,
    );
    return this.mapInsuranceClaim(row);
  }

  @Query(() => AnalyticsScreeningDetailType, {
    name: 'agencyAnalyticsScreeningDetail',
  })
  async agencyAnalyticsScreeningDetail(
    @CurrentUser() user: AuthUser,
    @Args('screeningId', { type: () => ID }) screeningId: string,
  ): Promise<AnalyticsScreeningDetailType> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    const row = await this.screeningsService.getResponseForTenant(
      user.tenantId,
      screeningId,
    );
    return this.mapScreeningDetail(row);
  }

  private mapScreeningDetail(r: {
    id: string;
    completedAt: Date;
    score?: unknown | null;
    riskLevel?: string | null;
    responses: unknown;
    template?: { name: string } | null;
    child?: { firstName: string; lastName: string } | null;
  }): AnalyticsScreeningDetailType {
    return {
      id: r.id,
      completedAt: r.completedAt,
      childName: r.child
        ? `${r.child.firstName} ${r.child.lastName}`
        : undefined,
      templateName: r.template?.name,
      score: r.score != null ? Number(r.score) : undefined,
      riskLevel: r.riskLevel ?? undefined,
      responsesJson: JSON.stringify(r.responses ?? {}),
    };
  }

  private mapInsuranceClaim(c: {
    id: string;
    status: string;
    payerName: string;
    billedAmount: unknown;
    approvedAmount?: unknown | null;
    serviceDate: Date;
    denialReason?: string | null;
    claimNumber?: string | null;
    sessionId?: string | null;
    metadata?: unknown;
    child?: { firstName: string; lastName: string };
    parent?: { user: { email: string } };
  }): AdminInsuranceClaimType {
    const meta = (c.metadata ?? {}) as Record<string, unknown>;
    const clearinghouse = meta.clearinghouse as { status?: string } | undefined;
    return {
      id: c.id,
      status: c.status,
      payerName: c.payerName,
      billedAmount: Number(c.billedAmount),
      approvedAmount:
        c.approvedAmount != null ? Number(c.approvedAmount) : undefined,
      serviceDate: c.serviceDate,
      childName: c.child
        ? `${c.child.firstName} ${c.child.lastName}`
        : undefined,
      parentEmail: c.parent?.user.email,
      denialReason: c.denialReason ?? undefined,
      claimNumber: c.claimNumber ?? undefined,
      sessionId: c.sessionId ?? undefined,
      ediReady: Boolean(meta.ediReady),
      clearinghouseStatus: clearinghouse?.status,
    };
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
