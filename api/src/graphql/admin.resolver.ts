import { Args, ID, Mutation, Query, Resolver } from '@nestjs/graphql';
import { Roles } from '../common/decorators/roles.decorator';
import { AuthUser, CurrentUser } from '../common/decorators/current-user.decorator';
import { AdminService } from '../admin/admin.service';
import { ComplaintsService } from '../complaints/complaints.service';
import {
  AdminDashboardType,
  AdminUserType,
  AuditLogEntryType,
  AdminComplaintType,
  PendingTherapistType,
} from './types/admin.types';

@Resolver()
@Roles('PLATFORM_ADMIN')
export class AdminResolver {
  constructor(
    private readonly adminService: AdminService,
    private readonly complaintsService: ComplaintsService,
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

  @Query(() => [PendingTherapistType], { name: 'pendingTherapistVerifications' })
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
    const c = await this.complaintsService.resolveComplaint(complaintId, resolution);
    return {
      id: c.id,
      status: c.status,
      category: c.category,
      subject: c.subject,
      description: c.description,
      reporterName: `${c.reporter.firstName} ${c.reporter.lastName}`,
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
}
