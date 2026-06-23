import { Args, ID, Int, Mutation, Query, Resolver } from '@nestjs/graphql';
import { Roles } from '../common/decorators/roles.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { AgenciesService } from '../agencies/agencies.service';
import { InsuranceService } from '../insurance/insurance.service';
import { isEipFormFullySigned } from '../sessions/eip-form.util';
import { SessionsService } from '../sessions/sessions.service';
import { ScreeningsService } from '../screenings/screenings.service';
import { SaveSoapNoteInput } from './inputs/therapist.inputs';
import {
  CreateAgencyStaffInput,
  AddAgencyCaseloadChildInput,
  UpdateAgencyCaseloadChildInput,
  UpdateAgencyProfileInput,
} from './inputs/agency.inputs';
import {
  AgencyAppointmentType,
  AgencyDashboardType,
  AgencyOnboardingStatusType,
  AgencyProfileType,
  AgencyStaffMemberType,
  AgencyTherapistType,
} from './types/agency.types';
import { UpdateInsuranceClaimInput } from './inputs/admin.input';
import { AdminInsuranceClaimType } from './types/admin.types';
import {
  AnalyticsClaimPipelineFilter,
  AnalyticsClaimSummaryType,
  AnalyticsScreeningDetailType,
  AnalyticsScreeningSummaryType,
  ClaimsPipelineDashboardType,
  ScreeningFunnelDashboardType,
} from './types/dashboard.types';
import {
  SessionNoteFormContextType,
  SoapNoteType,
  StaffSessionNoteSummaryType,
  TherapistCaseloadChartType,
} from './types/therapist.types';
import { ChildType } from './types/parent-booking.types';
import { TherapyType } from '../../generated/prisma/client';

@Resolver()
@Roles('AGENCY_ADMIN')
export class AgencyResolver {
  constructor(
    private readonly agenciesService: AgenciesService,
    private readonly insuranceService: InsuranceService,
    private readonly screeningsService: ScreeningsService,
    private readonly sessionsService: SessionsService,
  ) {}

  @Query(() => AgencyDashboardType, { name: 'agencyDashboard' })
  async agencyDashboard(
    @CurrentUser() user: AuthUser,
  ): Promise<AgencyDashboardType> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    const agency = await this.agenciesService.resolveAgencyForAdmin(
      user.id,
      user.tenantId,
    );
    return this.agenciesService.getDashboardForAgency(agency.id, user.tenantId);
  }

  @Query(() => [TherapistCaseloadChartType], { name: 'agencyCaseloadCharts' })
  async agencyCaseloadCharts(
    @CurrentUser() user: AuthUser,
  ): Promise<TherapistCaseloadChartType[]> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    const agency = await this.agenciesService.resolveAgencyForAdmin(
      user.id,
      user.tenantId,
    );
    const rows = await this.agenciesService.findCaseloadChartsForAgency(
      agency.id,
      user.tenantId,
    );
    return rows.map((row) => ({
      ...row,
      therapyTypes: row.therapyTypes as TherapyType[],
    }));
  }

  @Query(() => AgencyProfileType, { name: 'agencyProfile' })
  async agencyProfile(@CurrentUser() user: AuthUser): Promise<AgencyProfileType> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    const agency = await this.agenciesService.resolveAgencyForAdmin(
      user.id,
      user.tenantId,
    );
    const profile = await this.agenciesService.getAgencyProfile(
      agency.id,
      user.tenantId,
    );
    return this.mapAgencyProfile(profile);
  }

  @Query(() => [ChildType], { name: 'agencyManagedCaseloadChildren' })
  async agencyManagedCaseloadChildren(
    @CurrentUser() user: AuthUser,
  ): Promise<ChildType[]> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    const agency = await this.agenciesService.resolveAgencyForAdmin(
      user.id,
      user.tenantId,
    );
    const children = await this.agenciesService.listManagedCaseloadChildren(
      agency.id,
      user.tenantId,
    );
    return children.map((child) => this.mapChild(child));
  }

  @Query(() => ChildType, { name: 'agencyManagedCaseloadChild' })
  async agencyManagedCaseloadChild(
    @CurrentUser() user: AuthUser,
    @Args('childId', { type: () => ID }) childId: string,
  ): Promise<ChildType> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    const agency = await this.agenciesService.resolveAgencyForAdmin(
      user.id,
      user.tenantId,
    );
    const child = await this.agenciesService.getManagedCaseloadChild(
      agency.id,
      user.tenantId,
      childId,
    );
    return this.mapChild(child);
  }

  @Mutation(() => ChildType, { name: 'addAgencyCaseloadChild' })
  async addAgencyCaseloadChild(
    @CurrentUser() user: AuthUser,
    @Args('input') input: AddAgencyCaseloadChildInput,
  ): Promise<ChildType> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    const agency = await this.agenciesService.resolveAgencyForAdmin(
      user.id,
      user.tenantId,
    );
    const child = await this.agenciesService.addCaseloadChild(
      agency.id,
      user.tenantId,
      user.id,
      input,
    );
    return this.mapChild(child);
  }

  @Mutation(() => ChildType, { name: 'updateAgencyCaseloadChild' })
  async updateAgencyCaseloadChild(
    @CurrentUser() user: AuthUser,
    @Args('input') input: UpdateAgencyCaseloadChildInput,
  ): Promise<ChildType> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    const agency = await this.agenciesService.resolveAgencyForAdmin(
      user.id,
      user.tenantId,
    );
    const child = await this.agenciesService.updateCaseloadChild(
      agency.id,
      user.tenantId,
      input,
    );
    return this.mapChild(child);
  }

  @Query(() => AgencyOnboardingStatusType, { name: 'agencyOnboardingStatus' })
  async agencyOnboardingStatus(
    @CurrentUser() user: AuthUser,
  ): Promise<AgencyOnboardingStatusType> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    const agency = await this.agenciesService.resolveAgencyForAdmin(
      user.id,
      user.tenantId,
    );
    return this.agenciesService.getAgencyOnboardingStatus(
      agency.id,
      user.tenantId,
    );
  }

  @Mutation(() => AgencyProfileType, { name: 'updateAgencyProfile' })
  async updateAgencyProfile(
    @CurrentUser() user: AuthUser,
    @Args('input') input: UpdateAgencyProfileInput,
  ): Promise<AgencyProfileType> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    const agency = await this.agenciesService.resolveAgencyForAdmin(
      user.id,
      user.tenantId,
    );
    const updated = await this.agenciesService.updateAgencyProfile(
      agency.id,
      user.tenantId,
      input,
    );
    const profile = await this.agenciesService.getAgencyProfile(
      updated.id,
      user.tenantId,
    );
    return this.mapAgencyProfile(profile);
  }

  @Mutation(() => AgencyOnboardingStatusType, {
    name: 'completeAgencyOnboarding',
  })
  async completeAgencyOnboarding(
    @CurrentUser() user: AuthUser,
  ): Promise<AgencyOnboardingStatusType> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    const agency = await this.agenciesService.resolveAgencyForAdmin(
      user.id,
      user.tenantId,
    );
    await this.agenciesService.completeAgencyOnboarding(
      agency.id,
      user.tenantId,
    );
    return this.agenciesService.getAgencyOnboardingStatus(
      agency.id,
      user.tenantId,
    );
  }

  @Mutation(() => AgencyStaffMemberType, { name: 'createAgencyStaff' })
  async createAgencyStaff(
    @CurrentUser() user: AuthUser,
    @Args('input') input: CreateAgencyStaffInput,
  ): Promise<AgencyStaffMemberType> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    const agency = await this.agenciesService.resolveAgencyForAdmin(
      user.id,
      user.tenantId,
    );
    const { user: staffUser, therapist } =
      await this.agenciesService.createAgencyStaff(
        agency.id,
        user.tenantId,
        user.id,
        input,
      );
    return {
      id: staffUser.id,
      email: staffUser.email,
      firstName: staffUser.firstName,
      lastName: staffUser.lastName,
      therapistId: therapist.id,
      rosterStatus: 'PENDING',
      onboardingStatus: therapist.onboardingStatus,
    };
  }

  @Mutation(() => AgencyTherapistType, { name: 'approveAgencyStaff' })
  async approveAgencyStaff(
    @CurrentUser() user: AuthUser,
    @Args('therapistId', { type: () => ID }) therapistId: string,
  ): Promise<AgencyTherapistType> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    const agency = await this.agenciesService.resolveAgencyForAdmin(
      user.id,
      user.tenantId,
    );
    const link = await this.agenciesService.approveAgencyStaff(
      agency.id,
      user.tenantId,
      therapistId,
      user.id,
    );
    const t = link.therapist;
    return {
      id: t.id,
      isVerified: t.isVerified,
      licenseNumber: t.licenseNumber ?? undefined,
      rosterStatus: link.status,
      onboardingStatus: t.onboardingStatus,
      user: t.user
        ? {
            firstName: t.user.firstName,
            lastName: t.user.lastName,
            email: t.user.email,
          }
        : undefined,
    };
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
    const agency = await this.agenciesService.resolveAgencyForAdmin(
      user.id,
      user.tenantId,
    );
    const rows = await this.agenciesService.listTherapistsForAgency(agency.id);
    return rows.map((t) => this.mapAgencyTherapist(t));
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
    const agency = await this.agenciesService.resolveAgencyForAdmin(
      user.id,
      user.tenantId,
    );
    const rows = await this.agenciesService.listUnlinkedTherapistsForAgency(
      agency.id,
      user.tenantId,
    );
    return rows.map((t) => this.mapAgencyTherapist(t));
  }

  @Mutation(() => Boolean, { name: 'removeAgencyTherapist' })
  async removeAgencyTherapist(
    @CurrentUser() user: AuthUser,
    @Args('therapistId', { type: () => ID }) therapistId: string,
  ): Promise<boolean> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    const agency = await this.agenciesService.resolveAgencyForAdmin(
      user.id,
      user.tenantId,
    );
    await this.agenciesService.removeTherapistFromAgency(
      user.tenantId,
      therapistId,
      agency.id,
    );
    return true;
  }

  @Query(() => ClaimsPipelineDashboardType, { name: 'agencyClaimsPipeline' })
  async agencyClaimsPipeline(
    @CurrentUser() user: AuthUser,
    @Args('fromDate', { nullable: true }) fromDate?: Date,
    @Args('toDate', { nullable: true }) toDate?: Date,
  ): Promise<ClaimsPipelineDashboardType> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    const pipeline = await this.insuranceService.getClaimsPipelineForTenant(
      user.tenantId,
      { fromDate, toDate },
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
    @Args('fromDate', { nullable: true }) fromDate?: Date,
    @Args('toDate', { nullable: true }) toDate?: Date,
  ): Promise<ScreeningFunnelDashboardType> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    const funnel = await this.screeningsService.getScreeningFunnelForTenant(
      user.tenantId,
      { fromDate, toDate },
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
        recommendationsJson: JSON.stringify(r.recommendations ?? []),
      })),
    };
  }

  @Query(() => [AnalyticsClaimSummaryType], { name: 'agencyAnalyticsClaims' })
  async agencyAnalyticsClaims(
    @CurrentUser() user: AuthUser,
    @Args('statusFilter', { type: () => AnalyticsClaimPipelineFilter })
    statusFilter: AnalyticsClaimPipelineFilter,
    @Args('limit', { type: () => Int, nullable: true, defaultValue: 50 })
    limit: number,
    @Args('fromDate', { nullable: true }) fromDate?: Date,
    @Args('toDate', { nullable: true }) toDate?: Date,
  ): Promise<AnalyticsClaimSummaryType[]> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    const rows = await this.insuranceService.listAnalyticsClaimsForTenant(
      user.tenantId,
      statusFilter,
      limit,
      { fromDate, toDate },
    );
    return rows.map((c) => ({
      id: c.id,
      status: c.status,
      payerName: c.payerName,
      billedAmount: Number(c.billedAmount),
      serviceDate: c.serviceDate,
      childName: c.child
        ? `${c.child.firstName} ${c.child.lastName}`
        : undefined,
      claimNumber: c.claimNumber ?? undefined,
    }));
  }

  @Query(() => [AnalyticsScreeningSummaryType], {
    name: 'agencyAnalyticsScreenings',
  })
  async agencyAnalyticsScreenings(
    @CurrentUser() user: AuthUser,
    @Args('limit', { type: () => Int, nullable: true, defaultValue: 50 })
    limit: number,
    @Args('riskLevel', { nullable: true }) riskLevel?: string,
    @Args('fromDate', { nullable: true }) fromDate?: Date,
    @Args('toDate', { nullable: true }) toDate?: Date,
  ): Promise<AnalyticsScreeningSummaryType[]> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    const rows = await this.screeningsService.listAnalyticsScreeningsForTenant(
      user.tenantId,
      riskLevel,
      limit,
      { fromDate, toDate },
      user.id,
    );
    return rows.map((r) => ({
      id: r.id,
      completedAt: r.completedAt,
      childName: r.child
        ? `${r.child.firstName} ${r.child.lastName}`
        : undefined,
      templateName: r.template?.name,
      score: r.score != null ? Number(r.score) : undefined,
      riskLevel: r.riskLevel ?? undefined,
      recommendationsJson: JSON.stringify(r.recommendations ?? []),
    }));
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
      user.id,
    );
    return this.screeningsService.buildAnalyticsScreeningDetail(row);
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

  @Mutation(() => AdminInsuranceClaimType, {
    name: 'agencyUpdateInsuranceClaim',
  })
  async agencyUpdateInsuranceClaim(
    @CurrentUser() user: AuthUser,
    @Args('input') input: UpdateInsuranceClaimInput,
  ): Promise<AdminInsuranceClaimType> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    const row = await this.insuranceService.updateClaimStatusForTenant(
      user.tenantId,
      input.claimId,
      input.status,
      {
        denialReason: input.denialReason,
        approvedAmount: input.approvedAmount,
      },
    );
    return this.mapInsuranceClaim(row);
  }

  @Mutation(() => AdminInsuranceClaimType, {
    name: 'agencyProcessClaimRemittance835',
  })
  async agencyProcessClaimRemittance835(
    @CurrentUser() user: AuthUser,
    @Args('claimId', { type: () => ID }) claimId: string,
  ): Promise<AdminInsuranceClaimType> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    const row = await this.insuranceService.processRemittance835ForClaim(
      user.tenantId,
      claimId,
    );
    return this.mapInsuranceClaim(row);
  }

  @Mutation(() => AgencyTherapistType, { name: 'inviteAgencyTherapist' })
  async inviteAgencyTherapist(
    @CurrentUser() user: AuthUser,
    @Args('therapistId', { type: () => ID }) therapistId: string,
  ): Promise<AgencyTherapistType> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    const agency = await this.agenciesService.resolveAgencyForAdmin(
      user.id,
      user.tenantId,
    );
    const link = await this.agenciesService.inviteTherapistForAgency(
      agency.id,
      user.tenantId,
      therapistId,
    );
    return this.mapAgencyTherapist({
      ...link.therapist,
      rosterStatus: link.status,
    });
  }

  @Query(() => [StaffSessionNoteSummaryType], { name: 'agencySessionNotes' })
  async agencySessionNotes(
    @CurrentUser() user: AuthUser,
  ): Promise<StaffSessionNoteSummaryType[]> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    const rows = await this.sessionsService.listDocumentedSessionsForAgency(
      user.tenantId,
      user.id,
    );
    return rows.map((s) => ({
      sessionId: s.id,
      childName: `${s.child.firstName} ${s.child.lastName}`,
      therapistName: `${s.therapist.user.firstName} ${s.therapist.user.lastName}`,
      sessionDate: s.appointment.scheduledStart.toISOString().slice(0, 10),
      isFullySigned:
        s.soapNote?.signedAt != null ||
        isEipFormFullySigned(
          s.soapNote?.eipFormData as Record<string, unknown> | null,
        ),
      hasServiceLog: s.serviceLog != null,
    }));
  }

  @Query(() => SessionNoteFormContextType, {
    name: 'agencySessionNoteFormContext',
  })
  async agencySessionNoteFormContext(
    @CurrentUser() user: AuthUser,
    @Args('sessionId', { type: () => ID }) sessionId: string,
  ): Promise<SessionNoteFormContextType> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    return this.sessionsService.getSessionNoteFormContextForAgency(
      user.tenantId,
      sessionId,
      user.id,
    );
  }

  @Mutation(() => SoapNoteType, { name: 'agencySaveSoapNote' })
  async agencySaveSoapNote(
    @CurrentUser() user: AuthUser,
    @Args('input') input: SaveSoapNoteInput,
  ): Promise<SoapNoteType> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    const note = await this.sessionsService.saveSoapNoteForAgency(
      user.tenantId,
      user.id,
      input,
    );
    return {
      id: note.id,
      subjective: note.subjective ?? undefined,
      objective: note.objective ?? undefined,
      assessment: note.assessment ?? undefined,
      plan: note.plan ?? undefined,
      eipFormData:
        note.eipFormData != null ? JSON.stringify(note.eipFormData) : undefined,
      eipFormFullySigned:
        note.signedAt != null ||
        isEipFormFullySigned(
          note.eipFormData as Record<string, unknown> | null,
        ),
    };
  }

  private mapAgencyTherapist(t: {
    id: string;
    isVerified: boolean;
    licenseNumber?: string | null;
    onboardingStatus?: string;
    rosterStatus?: string;
    user?: { firstName: string; lastName: string; email: string } | null;
  }): AgencyTherapistType {
    return {
      id: t.id,
      isVerified: t.isVerified,
      licenseNumber: t.licenseNumber ?? undefined,
      rosterStatus: t.rosterStatus as AgencyTherapistType['rosterStatus'],
      onboardingStatus:
        t.onboardingStatus as AgencyTherapistType['onboardingStatus'],
      user: t.user
        ? {
            firstName: t.user.firstName,
            lastName: t.user.lastName,
            email: t.user.email,
          }
        : undefined,
    };
  }

  private mapChild(child: {
    id: string;
    firstName: string;
    lastName: string;
    dateOfBirth: Date;
    gender?: string | null;
    primaryLanguage?: string | null;
    guardianName?: string | null;
    guardianPhone?: string | null;
    guardianEmail?: string | null;
    addressLine1?: string | null;
    zipCode?: string | null;
    pediatricianName?: string | null;
    insuranceType?: string | null;
    hadEarlyIntervention?: boolean | null;
  }): ChildType {
    return {
      id: child.id,
      firstName: child.firstName,
      lastName: child.lastName,
      dateOfBirth: child.dateOfBirth,
      gender: child.gender ?? undefined,
      primaryLanguage: child.primaryLanguage ?? undefined,
      guardianName: child.guardianName ?? undefined,
      guardianPhone: child.guardianPhone ?? undefined,
      guardianEmail: child.guardianEmail ?? undefined,
      addressLine1: child.addressLine1 ?? undefined,
      zipCode: child.zipCode ?? undefined,
      pediatricianName: child.pediatricianName ?? undefined,
      insuranceType: child.insuranceType ?? undefined,
      hadEarlyIntervention: child.hadEarlyIntervention ?? undefined,
    };
  }

  private mapAgencyProfile(agency: {
    id: string;
    name: string;
    ein?: string | null;
    phone?: string | null;
    addressLine1?: string | null;
    addressLine2?: string | null;
    city?: string | null;
    state?: string | null;
    zipCode?: string | null;
    email?: string | null;
    website?: string | null;
    onboardingComplete: boolean;
    documents: Array<{
      id: string;
      type: string;
      title: string;
      fileName: string;
      mimeType: string;
      uploadedAt: Date;
    }>;
  }): AgencyProfileType {
    return {
      id: agency.id,
      name: agency.name,
      ein: agency.ein ?? undefined,
      phone: agency.phone ?? undefined,
      addressLine1: agency.addressLine1 ?? undefined,
      addressLine2: agency.addressLine2 ?? undefined,
      city: agency.city ?? undefined,
      state: agency.state ?? undefined,
      zipCode: agency.zipCode ?? undefined,
      email: agency.email ?? undefined,
      website: agency.website ?? undefined,
      onboardingComplete: agency.onboardingComplete,
      documents: agency.documents.map((d) => ({
        id: d.id,
        type: d.type as AgencyProfileType['documents'][0]['type'],
        title: d.title,
        fileName: d.fileName,
        mimeType: d.mimeType,
        uploadedAt: d.uploadedAt,
      })),
    };
  }
}
