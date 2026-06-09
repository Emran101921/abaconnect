import { Args, ID, Int, Mutation, Query, Resolver } from '@nestjs/graphql';
import { Roles } from '../common/decorators/roles.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { AdminService } from '../admin/admin.service';
import { AgenciesService } from '../agencies/agencies.service';
import { ComplaintsService } from '../complaints/complaints.service';
import { InsuranceService } from '../insurance/insurance.service';
import { isEipFormFullySigned } from '../sessions/eip-form.util';
import { SessionsService } from '../sessions/sessions.service';
import { ReviewsService } from '../reviews/reviews.service';
import { ScreeningsService } from '../screenings/screenings.service';
import { SaveSoapNoteInput } from './inputs/therapist.inputs';
import {
  SetAgencyBaaInput,
  SetUserActiveInput,
  UpdateInsuranceClaimInput,
} from './inputs/admin.input';
import {
  AdminDashboardType,
  AdminUserType,
  AuditLogEntryType,
  AdminComplaintType,
  AdminInsuranceClaimType,
  AdminReviewType,
  PendingTherapistType,
} from './types/admin.types';
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
} from './types/therapist.types';

@Resolver()
@Roles('PLATFORM_ADMIN')
export class AdminResolver {
  constructor(
    private readonly adminService: AdminService,
    private readonly agenciesService: AgenciesService,
    private readonly complaintsService: ComplaintsService,
    private readonly reviewsService: ReviewsService,
    private readonly insuranceService: InsuranceService,
    private readonly screeningsService: ScreeningsService,
    private readonly sessionsService: SessionsService,
  ) {}

  @Query(() => AdminDashboardType, { name: 'adminDashboard' })
  async adminDashboard(
    @CurrentUser() user: AuthUser,
  ): Promise<AdminDashboardType> {
    const stats = await this.adminService.getDashboard(user.tenantId);
    return {
      userCount: stats.userCount,
      parentCount: stats.parentCount,
      therapistCount: stats.therapistCount,
      appointmentCount: stats.appointmentCount,
      pendingTherapists: stats.pendingTherapists,
      openComplaints: stats.openComplaints,
    };
  }

  @Query(() => [AdminUserType], { name: 'adminUsers' })
  async adminUsers(@CurrentUser() user: AuthUser): Promise<AdminUserType[]> {
    return this.adminService.listUsers(user.tenantId);
  }

  @Query(() => [PendingTherapistType], {
    name: 'pendingTherapistVerifications',
  })
  async pendingTherapistVerifications(
    @CurrentUser() user: AuthUser,
  ): Promise<PendingTherapistType[]> {
    const rows = await this.adminService.listPendingTherapists(user.tenantId);
    return rows.map((t) => ({
      id: t.id,
      isVerified: t.isVerified,
      licenseNumber: t.licenseNumber ?? undefined,
      licenseState: t.licenseState ?? undefined,
      user: {
        firstName: t.user.firstName,
        lastName: t.user.lastName,
        email: t.user.email,
      },
    }));
  }

  @Query(() => [AuditLogEntryType], { name: 'adminRecentAuditLogs' })
  async adminRecentAuditLogs(
    @CurrentUser() user: AuthUser,
  ): Promise<AuditLogEntryType[]> {
    const stats = await this.adminService.getDashboard(user.tenantId);
    return stats.recentAuditLogs.map((log) => ({
      id: log.id,
      action: log.action,
      entityType: log.entityType,
      createdAt: log.createdAt,
      actorEmail: log.actor?.email,
    }));
  }

  @Query(() => [AdminComplaintType], { name: 'adminComplaints' })
  async adminComplaints(
    @CurrentUser() user: AuthUser,
  ): Promise<AdminComplaintType[]> {
    const rows = await this.complaintsService.listForTenant(
      user.tenantId ?? '',
      'OPEN',
    );
    return rows.map((c) => ({
      id: c.id,
      status: c.status,
      category: c.category,
      subject: c.subject,
      description: c.description,
      reporterName: `${c.reporter.firstName} ${c.reporter.lastName}`,
    }));
  }

  @Mutation(() => AdminComplaintType, { name: 'resolveComplaint' })
  async resolveComplaint(
    @CurrentUser() user: AuthUser,
    @Args('complaintId', { type: () => ID }) complaintId: string,
    @Args('resolution') resolution: string,
  ): Promise<AdminComplaintType> {
    const c = await this.complaintsService.resolveComplaint(
      user.tenantId!,
      complaintId,
      resolution,
    );
    return {
      id: c.id,
      status: c.status,
      category: c.category,
      subject: c.subject,
      description: c.description,
      reporterName: `${c.reporter.firstName} ${c.reporter.lastName}`,
    };
  }

  @Query(() => [AdminReviewType], { name: 'adminReviews' })
  async adminReviews(
    @CurrentUser() user: AuthUser,
  ): Promise<AdminReviewType[]> {
    const rows = await this.reviewsService.listForAdminModeration(
      user.tenantId,
    );
    return rows.map((r) => ({
      id: r.id,
      rating: r.rating,
      title: r.title ?? undefined,
      comment: r.comment ?? undefined,
      isPublished: r.isPublished,
      createdAt: r.createdAt,
      therapistName: r.therapist?.user
        ? `${r.therapist.user.firstName} ${r.therapist.user.lastName}`
        : undefined,
      authorEmail: r.author?.email,
    }));
  }

  @Mutation(() => AdminReviewType, { name: 'moderateReview' })
  async moderateReview(
    @CurrentUser() user: AuthUser,
    @Args('reviewId', { type: () => ID }) reviewId: string,
    @Args('publish') publish: boolean,
  ): Promise<AdminReviewType> {
    const r = await this.reviewsService.setPublished(
      reviewId,
      publish,
      user.tenantId,
    );
    return {
      id: r.id,
      rating: r.rating,
      title: r.title ?? undefined,
      comment: r.comment ?? undefined,
      isPublished: r.isPublished,
      createdAt: r.createdAt,
      therapistName: r.therapist?.user
        ? `${r.therapist.user.firstName} ${r.therapist.user.lastName}`
        : undefined,
      authorEmail: r.author?.email,
    };
  }

  @Query(() => [AdminInsuranceClaimType], { name: 'adminInsuranceClaims' })
  async adminInsuranceClaims(
    @CurrentUser() user: AuthUser,
  ): Promise<AdminInsuranceClaimType[]> {
    const rows = await this.insuranceService.listClaimsForTenant(
      user.tenantId ?? '',
    );
    return rows.map((c) => this.mapInsuranceClaim(c));
  }

  @Query(() => ClaimsPipelineDashboardType, { name: 'adminClaimsPipeline' })
  async adminClaimsPipeline(
    @CurrentUser() user: AuthUser,
    @Args('fromDate', { nullable: true }) fromDate?: Date,
    @Args('toDate', { nullable: true }) toDate?: Date,
  ): Promise<ClaimsPipelineDashboardType> {
    const pipeline = await this.insuranceService.getClaimsPipelineForTenant(
      user.tenantId ?? '',
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

  @Query(() => ScreeningFunnelDashboardType, { name: 'adminScreeningFunnel' })
  async adminScreeningFunnel(
    @CurrentUser() user: AuthUser,
    @Args('fromDate', { nullable: true }) fromDate?: Date,
    @Args('toDate', { nullable: true }) toDate?: Date,
  ): Promise<ScreeningFunnelDashboardType> {
    const funnel = await this.screeningsService.getScreeningFunnelForTenant(
      user.tenantId ?? '',
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

  @Query(() => [AnalyticsClaimSummaryType], { name: 'adminAnalyticsClaims' })
  async adminAnalyticsClaims(
    @CurrentUser() user: AuthUser,
    @Args('statusFilter', { type: () => AnalyticsClaimPipelineFilter })
    statusFilter: AnalyticsClaimPipelineFilter,
    @Args('limit', { type: () => Int, nullable: true, defaultValue: 50 })
    limit: number,
    @Args('fromDate', { nullable: true }) fromDate?: Date,
    @Args('toDate', { nullable: true }) toDate?: Date,
  ): Promise<AnalyticsClaimSummaryType[]> {
    const rows = await this.insuranceService.listAnalyticsClaimsForTenant(
      user.tenantId ?? '',
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
    name: 'adminAnalyticsScreenings',
  })
  async adminAnalyticsScreenings(
    @CurrentUser() user: AuthUser,
    @Args('limit', { type: () => Int, nullable: true, defaultValue: 50 })
    limit: number,
    @Args('riskLevel', { nullable: true }) riskLevel?: string,
    @Args('fromDate', { nullable: true }) fromDate?: Date,
    @Args('toDate', { nullable: true }) toDate?: Date,
  ): Promise<AnalyticsScreeningSummaryType[]> {
    const rows = await this.screeningsService.listAnalyticsScreeningsForTenant(
      user.tenantId ?? '',
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

  @Query(() => AdminInsuranceClaimType, { name: 'adminAnalyticsClaimDetail' })
  async adminAnalyticsClaimDetail(
    @CurrentUser() user: AuthUser,
    @Args('claimId', { type: () => ID }) claimId: string,
  ): Promise<AdminInsuranceClaimType> {
    const row = await this.insuranceService.getClaimForTenant(
      user.tenantId ?? '',
      claimId,
    );
    return this.mapInsuranceClaim(row);
  }

  @Query(() => AnalyticsScreeningDetailType, {
    name: 'adminAnalyticsScreeningDetail',
  })
  async adminAnalyticsScreeningDetail(
    @CurrentUser() user: AuthUser,
    @Args('screeningId', { type: () => ID }) screeningId: string,
  ): Promise<AnalyticsScreeningDetailType> {
    const row = await this.screeningsService.getResponseForTenant(
      user.tenantId ?? '',
      screeningId,
      user.id,
    );
    return this.screeningsService.buildAnalyticsScreeningDetail(row);
  }

  @Mutation(() => AdminInsuranceClaimType, { name: 'updateInsuranceClaim' })
  async updateInsuranceClaim(
    @CurrentUser() user: AuthUser,
    @Args('input') input: UpdateInsuranceClaimInput,
  ): Promise<AdminInsuranceClaimType> {
    const row = await this.insuranceService.updateClaimStatusForTenant(
      user.tenantId ?? '',
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
    name: 'processClaimRemittance835',
  })
  async processClaimRemittance835(
    @CurrentUser() user: AuthUser,
    @Args('claimId', { type: () => ID }) claimId: string,
  ): Promise<AdminInsuranceClaimType> {
    const row = await this.insuranceService.processRemittance835ForClaim(
      user.tenantId ?? '',
      claimId,
    );
    return this.mapInsuranceClaim(row);
  }

  @Mutation(() => AdminInsuranceClaimType, {
    name: 'submitInsuranceClaimToClearinghouse',
  })
  async submitInsuranceClaimToClearinghouse(
    @CurrentUser() user: AuthUser,
    @Args('claimId', { type: () => String }) claimId: string,
  ): Promise<AdminInsuranceClaimType> {
    const row = await this.insuranceService.submitClaimToClearinghouse(
      claimId,
      user.tenantId ?? '',
    );
    return this.mapInsuranceClaim(row);
  }

  @Mutation(() => AdminUserType, { name: 'setUserActive' })
  async setUserActive(
    @CurrentUser() user: AuthUser,
    @Args('input') input: SetUserActiveInput,
  ): Promise<AdminUserType> {
    const row = await this.adminService.setUserActive(
      input.userId,
      input.isActive,
      user.tenantId,
    );
    return {
      id: row.id,
      email: row.email,
      firstName: row.firstName,
      lastName: row.lastName,
      role: row.role,
      isActive: row.isActive,
    };
  }

  @Mutation(() => PendingTherapistType, { name: 'verifyTherapist' })
  async verifyTherapist(
    @CurrentUser() user: AuthUser,
    @Args('therapistId', { type: () => ID }) therapistId: string,
  ): Promise<PendingTherapistType> {
    const t = await this.adminService.verifyTherapist(
      therapistId,
      user.tenantId,
    );
    return {
      id: t.id,
      isVerified: t.isVerified,
      licenseNumber: t.licenseNumber ?? undefined,
      licenseState: t.licenseState ?? undefined,
      user: {
        firstName: t.user.firstName,
        lastName: t.user.lastName,
        email: t.user.email,
      },
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

  @Query(() => [StaffSessionNoteSummaryType], { name: 'adminSessionNotes' })
  async adminSessionNotes(
    @CurrentUser() user: AuthUser,
  ): Promise<StaffSessionNoteSummaryType[]> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    const rows = await this.sessionsService.listDocumentedSessionsForAdmin(
      user.tenantId,
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
    }));
  }

  @Query(() => SessionNoteFormContextType, {
    name: 'adminSessionNoteFormContext',
  })
  async adminSessionNoteFormContext(
    @CurrentUser() user: AuthUser,
    @Args('sessionId', { type: () => ID }) sessionId: string,
  ): Promise<SessionNoteFormContextType> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    return this.sessionsService.getSessionNoteFormContextForAdmin(
      user.tenantId,
      sessionId,
    );
  }

  @Mutation(() => Boolean, { name: 'setAgencyBaaSigned' })
  async setAgencyBaaSigned(
    @CurrentUser() user: AuthUser,
    @Args('input') input: SetAgencyBaaInput,
  ): Promise<boolean> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    await this.agenciesService.setAgencyBaaSigned(user.tenantId, input.agencyId, {
      baaSignedAt: input.baaSignedAt,
      baaDocumentKey: input.baaDocumentKey,
    });
    return true;
  }

  @Mutation(() => SoapNoteType, { name: 'adminSaveSoapNote' })
  async adminSaveSoapNote(
    @CurrentUser() user: AuthUser,
    @Args('input') input: SaveSoapNoteInput,
  ): Promise<SoapNoteType> {
    if (!user.tenantId) {
      throw new Error('Tenant required');
    }
    const note = await this.sessionsService.saveSoapNoteForAdmin(
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
}
