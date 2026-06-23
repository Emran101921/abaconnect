import { Body, Controller, Get, Param, Post, Query } from '@nestjs/common';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { JobOpportunitiesService } from './job-opportunities.service';
import { toPublicJobOpportunity } from './job-opportunity-privacy.util';

@Controller()
export class JobOpportunitiesController {
  constructor(private readonly jobs: JobOpportunitiesService) {}

  @Get('admin/job-opportunities')
  @Roles('PLATFORM_ADMIN')
  adminList(@CurrentUser() user: AuthUser) {
    return this.jobs.adminListJobOpportunities(user.tenantId ?? '');
  }

  @Get('admin/job-applications')
  @Roles('PLATFORM_ADMIN')
  adminApplications(@CurrentUser() user: AuthUser) {
    return this.jobs.adminListApplications(user.tenantId ?? '');
  }

  @Get('admin/job-marketplace-audit-logs')
  @Roles('PLATFORM_ADMIN')
  adminAuditLogs(@CurrentUser() user: AuthUser) {
    return this.jobs.adminMarketplaceAuditLogs(user.tenantId ?? '');
  }

  @Post('admin/job-opportunities/:id/pause')
  @Roles('PLATFORM_ADMIN')
  adminPause(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body('reason') reason?: string,
  ) {
    return this.jobs.adminPauseJobOpportunity(
      user.id,
      user.tenantId ?? '',
      id,
      reason,
    );
  }

  @Post('admin/job-opportunities/:id/remove')
  @Roles('PLATFORM_ADMIN')
  adminRemove(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body('reason') reason: string,
  ) {
    return this.jobs.adminRemoveJobOpportunity(
      user.id,
      user.tenantId ?? '',
      id,
      reason ?? 'Removed by admin',
    );
  }

  @Get('agency/job-opportunities')
  @Roles('AGENCY_ADMIN')
  agencyList(@CurrentUser() user: AuthUser) {
    return this.jobs
      .listAgencyJobOpportunities(user.id, user.tenantId ?? '')
      .then((rows) => rows.map((row) => toPublicJobOpportunity(row)));
  }

  @Get('agency/job-applications')
  @Roles('AGENCY_ADMIN')
  agencyApplications(
    @CurrentUser() user: AuthUser,
    @Query('jobOpportunityId') jobOpportunityId?: string,
  ) {
    return this.jobs.agencyListApplications(
      user.id,
      user.tenantId ?? '',
      jobOpportunityId,
    );
  }

  @Get('therapist/job-opportunities')
  @Roles('THERAPIST')
  browse(
    @CurrentUser() user: AuthUser,
    @Query('zipCode') zipCode?: string,
    @Query('radiusMiles') radiusMiles?: string,
    @Query('serviceType') serviceType?: string,
    @Query('employmentType') employmentType?: string,
    @Query('locationModality') locationModality?: string,
    @Query('language') language?: string,
    @Query('page') page?: string,
    @Query('pageSize') pageSize?: string,
  ) {
    return this.jobs.browseJobOpportunitiesForTherapist(
      user.id,
      user.tenantId ?? '',
      {
        zipCode,
        radiusMiles: radiusMiles ? Number(radiusMiles) : undefined,
        serviceType,
        employmentType,
        locationModality,
        language,
        page: page ? Number(page) : 1,
        pageSize: pageSize ? Number(pageSize) : 20,
      },
    );
  }
}
