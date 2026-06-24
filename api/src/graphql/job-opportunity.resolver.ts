import { Args, ID, Mutation, Query, Resolver } from '@nestjs/graphql';
import { Roles } from '../common/decorators/roles.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { JobOpportunitiesService } from '../job-opportunities/job-opportunities.service';
import { toPublicJobOpportunity } from '../job-opportunities/job-opportunity-privacy.util';
import {
  ApplyToJobOpportunityInput,
  AdminJobModerationInput,
  BrowseJobOpportunitiesInput,
  CreateChildServiceNeedInput,
  UpdateJobApplicationStatusInput,
  UpdateJobOpportunityInput,
} from './inputs/job-opportunity.input';
import {
  ChildServiceNeedType,
  JobApplicationType,
  JobMarketplaceAuditLogType,
  JobOpportunityBrowseResultType,
  mapPublicJobType,
  PublicJobOpportunityType,
} from './types/job-opportunity.types';

@Resolver()
export class JobOpportunityResolver {
  constructor(private readonly jobs: JobOpportunitiesService) {}

  @Query(() => [ChildServiceNeedType], { name: 'myChildServiceNeeds' })
  @Roles('AGENCY_ADMIN')
  async myChildServiceNeeds(@CurrentUser() user: AuthUser) {
    const rows = await this.jobs.listChildServiceNeeds(
      user.id,
      user.tenantId ?? '',
    );
    return rows.map((row) => ({
      id: row.id,
      serviceType: row.serviceType,
      internalNotes: row.internalNotes ?? undefined,
      internalScheduleJson: JSON.stringify(row.internalSchedule ?? {}),
      status: row.status,
      childDisplayName: `${row.child.firstName} ${row.child.lastName.charAt(0)}.`,
      jobOpportunityId: row.jobOpportunity?.id,
      jobOpportunityTitle: row.jobOpportunity?.title,
      jobOpportunityStatus: row.jobOpportunity?.status,
      createdAt: row.createdAt,
    }));
  }

  @Query(() => [PublicJobOpportunityType], { name: 'myAgencyJobOpportunities' })
  @Roles('AGENCY_ADMIN')
  async myAgencyJobOpportunities(@CurrentUser() user: AuthUser) {
    const rows = await this.jobs.listAgencyJobOpportunities(
      user.id,
      user.tenantId ?? '',
    );
    return rows.map((row) => mapPublicJobType(toPublicJobOpportunity(row)));
  }

  @Query(() => [JobApplicationType], { name: 'agencyJobApplications' })
  @Roles('AGENCY_ADMIN')
  async agencyJobApplications(
    @CurrentUser() user: AuthUser,
    @Args('jobOpportunityId', { type: () => ID, nullable: true })
    jobOpportunityId?: string,
  ) {
    const rows = await this.jobs.agencyListApplications(
      user.id,
      user.tenantId ?? '',
      jobOpportunityId,
    );
    return rows.map((row) => this.mapApplication(row));
  }

  @Query(() => JobOpportunityBrowseResultType, { name: 'browseJobOpportunities' })
  @Roles('THERAPIST')
  async browseJobOpportunities(
    @CurrentUser() user: AuthUser,
    @Args('input', { nullable: true }) input?: BrowseJobOpportunitiesInput,
  ) {
    const result = await this.jobs.browseJobOpportunitiesForTherapist(
      user.id,
      user.tenantId ?? '',
      input ?? {},
    );
    return {
      ...result,
      items: result.items.map((item) => mapPublicJobType(item)),
    };
  }

  @Query(() => PublicJobOpportunityType, { name: 'jobOpportunity' })
  @Roles('THERAPIST')
  async jobOpportunity(
    @CurrentUser() user: AuthUser,
    @Args('jobOpportunityId', { type: () => ID }) jobOpportunityId: string,
  ) {
    const row = await this.jobs.getPublishedJobOpportunityForTherapist(
      user.id,
      user.tenantId ?? '',
      jobOpportunityId,
    );
    return mapPublicJobType(row);
  }

  @Query(() => [JobApplicationType], { name: 'myJobApplications' })
  @Roles('THERAPIST')
  async myJobApplications(@CurrentUser() user: AuthUser) {
    const rows = await this.jobs.listTherapistApplications(
      user.id,
      user.tenantId ?? '',
    );
    return rows.map((row) => this.mapApplication(row));
  }

  @Query(() => [PublicJobOpportunityType], { name: 'savedJobOpportunities' })
  @Roles('THERAPIST')
  async savedJobOpportunities(@CurrentUser() user: AuthUser) {
    const rows = await this.jobs.listSavedJobOpportunities(
      user.id,
      user.tenantId ?? '',
    );
    return rows.map((row) => mapPublicJobType(toPublicJobOpportunity(row)));
  }

  @Query(() => [PublicJobOpportunityType], { name: 'adminJobOpportunities' })
  @Roles('PLATFORM_ADMIN')
  async adminJobOpportunities(@CurrentUser() user: AuthUser) {
    const rows = await this.jobs.adminListJobOpportunities(user.tenantId ?? '');
    return rows.map((row) => mapPublicJobType(toPublicJobOpportunity(row)));
  }

  @Query(() => [JobApplicationType], { name: 'adminJobApplications' })
  @Roles('PLATFORM_ADMIN')
  async adminJobApplications(@CurrentUser() user: AuthUser) {
    const rows = await this.jobs.adminListApplications(user.tenantId ?? '');
    return rows.map((row) => this.mapApplication(row));
  }

  @Query(() => [JobMarketplaceAuditLogType], {
    name: 'adminMarketplaceAuditLogs',
  })
  @Roles('PLATFORM_ADMIN')
  async adminMarketplaceAuditLogs(@CurrentUser() user: AuthUser) {
    const rows = await this.jobs.adminMarketplaceAuditLogs(user.tenantId ?? '');
    return rows.map((row) => ({
      id: row.id,
      eventType: row.eventType,
      entityType: row.entityType,
      entityId: row.entityId,
      actorName: row.actor
        ? `${row.actor.firstName} ${row.actor.lastName}`
        : undefined,
      metadataJson: JSON.stringify(row.metadata ?? {}),
      createdAt: row.createdAt,
    }));
  }

  @Mutation(() => ChildServiceNeedType, { name: 'createChildServiceNeed' })
  @Roles('AGENCY_ADMIN')
  async createChildServiceNeed(
    @CurrentUser() user: AuthUser,
    @Args('input') input: CreateChildServiceNeedInput,
  ) {
    const row = await this.jobs.createChildServiceNeed(
      user.id,
      user.tenantId ?? '',
      {
        childId: input.childId,
        serviceType: input.serviceType,
        internalNotes: input.internalNotes,
        internalSchedule: input.internalScheduleJson
          ? JSON.parse(input.internalScheduleJson)
          : {},
      },
    );
    return {
      id: row.id,
      serviceType: row.serviceType,
      internalNotes: row.internalNotes ?? undefined,
      internalScheduleJson: JSON.stringify(row.internalSchedule ?? {}),
      status: row.status,
      childDisplayName: `${row.child.firstName} ${row.child.lastName.charAt(0)}.`,
      createdAt: row.createdAt,
    };
  }

  @Mutation(() => PublicJobOpportunityType, { name: 'generateJobOpportunity' })
  @Roles('AGENCY_ADMIN')
  async generateJobOpportunity(
    @CurrentUser() user: AuthUser,
    @Args('childServiceNeedId', { type: () => ID }) childServiceNeedId: string,
  ) {
    const row = await this.jobs.generateJobOpportunityFromNeed(
      user.id,
      user.tenantId ?? '',
      childServiceNeedId,
    );
    return mapPublicJobType(toPublicJobOpportunity(row));
  }

  @Mutation(() => PublicJobOpportunityType, { name: 'updateJobOpportunity' })
  @Roles('AGENCY_ADMIN')
  async updateJobOpportunity(
    @CurrentUser() user: AuthUser,
    @Args('input') input: UpdateJobOpportunityInput,
  ) {
    const row = await this.jobs.updateJobOpportunityDraft(
      user.id,
      user.tenantId ?? '',
      input.jobOpportunityId,
      {
        title: input.title,
        publicDescription: input.publicDescription,
        zipCode: input.zipCode,
        borough: input.borough,
        county: input.county,
        serviceRadiusMiles: input.serviceRadiusMiles,
        schedule: input.scheduleJson ? JSON.parse(input.scheduleJson) : undefined,
        languageRequirement: input.languageRequirement,
        employmentType: input.employmentType,
        payRateMin: input.payRateMin,
        payRateMax: input.payRateMax,
        payRateDisplay: input.payRateDisplay,
        locationModality: input.locationModality,
        requiredCredentials: input.requiredCredentialsJson
          ? JSON.parse(input.requiredCredentialsJson)
          : undefined,
        requiredExperience: input.requiredExperience,
      },
    );
    return mapPublicJobType(toPublicJobOpportunity(row));
  }

  @Mutation(() => PublicJobOpportunityType, { name: 'publishJobOpportunity' })
  @Roles('AGENCY_ADMIN')
  async publishJobOpportunity(
    @CurrentUser() user: AuthUser,
    @Args('jobOpportunityId', { type: () => ID }) jobOpportunityId: string,
  ) {
    const row = await this.jobs.publishJobOpportunity(
      user.id,
      user.tenantId ?? '',
      jobOpportunityId,
    );
    return mapPublicJobType(toPublicJobOpportunity(row));
  }

  @Mutation(() => JobApplicationType, { name: 'applyToJobOpportunity' })
  @Roles('THERAPIST')
  async applyToJobOpportunity(
    @CurrentUser() user: AuthUser,
    @Args('input') input: ApplyToJobOpportunityInput,
  ) {
    const row = await this.jobs.applyToJobOpportunity(
      user.id,
      user.tenantId ?? '',
      input.jobOpportunityId,
      input.message,
    );
    return this.mapApplication(row);
  }

  @Mutation(() => JobApplicationType, { name: 'withdrawJobApplication' })
  @Roles('THERAPIST')
  async withdrawJobApplication(
    @CurrentUser() user: AuthUser,
    @Args('applicationId', { type: () => ID }) applicationId: string,
  ) {
    const row = await this.jobs.withdrawApplication(
      user.id,
      user.tenantId ?? '',
      applicationId,
    );
    return this.mapApplication(row);
  }

  @Mutation(() => PublicJobOpportunityType, { name: 'saveJobOpportunity' })
  @Roles('THERAPIST')
  async saveJobOpportunity(
    @CurrentUser() user: AuthUser,
    @Args('jobOpportunityId', { type: () => ID }) jobOpportunityId: string,
  ) {
    const row = await this.jobs.saveJobOpportunity(
      user.id,
      user.tenantId ?? '',
      jobOpportunityId,
    );
    return mapPublicJobType(row);
  }

  @Mutation(() => Boolean, { name: 'unsaveJobOpportunity' })
  @Roles('THERAPIST')
  async unsaveJobOpportunity(
    @CurrentUser() user: AuthUser,
    @Args('jobOpportunityId', { type: () => ID }) jobOpportunityId: string,
  ) {
    return this.jobs.unsaveJobOpportunity(
      user.id,
      user.tenantId ?? '',
      jobOpportunityId,
    );
  }

  @Mutation(() => JobApplicationType, { name: 'updateJobApplicationStatus' })
  @Roles('AGENCY_ADMIN')
  async updateJobApplicationStatus(
    @CurrentUser() user: AuthUser,
    @Args('input') input: UpdateJobApplicationStatusInput,
  ) {
    const row = await this.jobs.updateApplicationStatus(
      user.id,
      user.tenantId ?? '',
      input.applicationId,
      input.status,
      input.note,
    );
    return this.mapApplication(row);
  }

  @Mutation(() => JobApplicationType, { name: 'markTherapistHiredContracted' })
  @Roles('AGENCY_ADMIN')
  async markTherapistHiredContracted(
    @CurrentUser() user: AuthUser,
    @Args('applicationId', { type: () => ID }) applicationId: string,
    @Args('note', { nullable: true }) note?: string,
  ) {
    const row = await this.jobs.markHiredContracted(
      user.id,
      user.tenantId ?? '',
      applicationId,
      note,
    );
    return this.mapApplication(row);
  }

  @Mutation(() => Boolean, { name: 'addTherapistToAgencyRosterFromApplication' })
  @Roles('AGENCY_ADMIN')
  async addTherapistToAgencyRosterFromApplication(
    @CurrentUser() user: AuthUser,
    @Args('applicationId', { type: () => ID }) applicationId: string,
  ) {
    await this.jobs.addTherapistToAgencyRosterFromApplication(
      user.id,
      user.tenantId ?? '',
      applicationId,
    );
    return true;
  }

  @Mutation(() => PublicJobOpportunityType, { name: 'adminPauseJobOpportunity' })
  @Roles('PLATFORM_ADMIN')
  async adminPauseJobOpportunity(
    @CurrentUser() user: AuthUser,
    @Args('input') input: AdminJobModerationInput,
  ) {
    const row = await this.jobs.adminPauseJobOpportunity(
      user.id,
      user.tenantId ?? '',
      input.jobOpportunityId,
      input.reason,
    );
    return mapPublicJobType(toPublicJobOpportunity(row));
  }

  @Mutation(() => PublicJobOpportunityType, { name: 'adminRemoveJobOpportunity' })
  @Roles('PLATFORM_ADMIN')
  async adminRemoveJobOpportunity(
    @CurrentUser() user: AuthUser,
    @Args('input') input: AdminJobModerationInput,
  ) {
    const row = await this.jobs.adminRemoveJobOpportunity(
      user.id,
      user.tenantId ?? '',
      input.jobOpportunityId,
      input.reason ?? 'Removed by admin',
    );
    return mapPublicJobType(toPublicJobOpportunity(row));
  }

  private mapApplication(row: {
    id: string;
    status: string;
    message?: string | null;
    createdAt: Date;
    updatedAt: Date;
    therapist?: { user?: { firstName: string; lastName: string; email: string } };
    jobOpportunity?: { id: string; title: string };
  }): JobApplicationType {
    return {
      id: row.id,
      status: row.status as never,
      message: row.message ?? undefined,
      therapistName: row.therapist?.user
        ? `${row.therapist.user.firstName} ${row.therapist.user.lastName}`
        : 'Therapist',
      therapistEmail: row.therapist?.user?.email,
      jobOpportunityId: row.jobOpportunity?.id ?? '',
      jobTitle: row.jobOpportunity?.title ?? '',
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    };
  }
}
