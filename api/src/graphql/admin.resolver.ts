import { Args, ID, Mutation, Query, Resolver } from '@nestjs/graphql';
import { Roles } from '../common/decorators/roles.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { AdminService } from '../admin/admin.service';
import { ComplaintsService } from '../complaints/complaints.service';
import { InsuranceService } from '../insurance/insurance.service';
import { ReviewsService } from '../reviews/reviews.service';
import {
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

@Resolver()
@Roles('PLATFORM_ADMIN')
export class AdminResolver {
  constructor(
    private readonly adminService: AdminService,
    private readonly complaintsService: ComplaintsService,
    private readonly reviewsService: ReviewsService,
    private readonly insuranceService: InsuranceService,
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
    @Args('complaintId', { type: () => ID }) complaintId: string,
    @Args('resolution') resolution: string,
  ): Promise<AdminComplaintType> {
    const c = await this.complaintsService.resolveComplaint(
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
    @Args('reviewId', { type: () => ID }) reviewId: string,
    @Args('publish') publish: boolean,
  ): Promise<AdminReviewType> {
    const r = await this.reviewsService.setPublished(reviewId, publish);
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
    @Args('therapistId', { type: () => ID }) therapistId: string,
  ): Promise<PendingTherapistType> {
    const t = await this.adminService.verifyTherapist(therapistId);
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
    child?: { firstName: string; lastName: string };
    parent?: { user: { email: string } };
  }): AdminInsuranceClaimType {
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
    };
  }
}
