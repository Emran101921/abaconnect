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
  ApproveJobApplicationCredentialsInput,
  BrowseJobOpportunitiesInput,
  CreateChildServiceNeedInput,
  JobInterviewConsentInput,
  RequestJobApplicationDocumentsInput,
  RespondToJobOfferInput,
  RescheduleJobInterviewInput,
  ScheduleFirstSessionFromHireInput,
  ScheduleJobInterviewInput,
  SendJobOfferInput,
  UpdateHireOnboardingStepInput,
  UpdateJobApplicationStatusInput,
  UpdateJobInterviewNotesInput,
  UpdateJobOpportunityInput,
} from './inputs/job-opportunity.input';
import {
  ChildServiceNeedType,
  AgencyHiringPipelineSummaryType,
  HiringFirstSessionType,
  HireOnboardingType,
  JobApplicationType,
  JobInterviewJoinType,
  JobInterviewType,
  JobMarketplaceAuditLogType,
  JobOpportunityBrowseResultType,
  JobOpportunityInviteType,
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
      childId: row.child.id,
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
    const pendingByJob = await this.jobs.agencyPendingActionsByJob(
      user.id,
      user.tenantId ?? '',
    );
    return rows.map((row) => ({
      ...mapPublicJobType(toPublicJobOpportunity(row)),
      pendingActionCount: pendingByJob[row.id] ?? 0,
    }));
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

  @Query(() => AgencyHiringPipelineSummaryType, {
    name: 'agencyHiringPipelineSummary',
  })
  @Roles('AGENCY_ADMIN')
  async agencyHiringPipelineSummary(@CurrentUser() user: AuthUser) {
    return this.jobs.agencyHiringPipelineSummary(user.id, user.tenantId ?? '');
  }

  @Query(() => [HireOnboardingType], { name: 'agencyHireOnboardings' })
  @Roles('AGENCY_ADMIN')
  async agencyHireOnboardings(@CurrentUser() user: AuthUser) {
    return this.jobs.listAgencyHireOnboardings(user.id, user.tenantId ?? '');
  }

  @Query(() => [HireOnboardingType], { name: 'myHireOnboardings' })
  @Roles('THERAPIST')
  async myHireOnboardings(@CurrentUser() user: AuthUser) {
    return this.jobs.listMyHireOnboardings(user.id, user.tenantId ?? '');
  }

  @Query(() => JobOpportunityBrowseResultType, {
    name: 'browseJobOpportunities',
  })
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

  @Query(() => [JobOpportunityInviteType], { name: 'myJobOpportunityInvites' })
  @Roles('THERAPIST')
  async myJobOpportunityInvites(@CurrentUser() user: AuthUser) {
    return this.jobs.listJobInvitesForTherapist(user.id, user.tenantId ?? '');
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
        schedule: input.scheduleJson
          ? JSON.parse(input.scheduleJson)
          : undefined,
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

  @Mutation(() => JobOpportunityInviteType, { name: 'inviteTherapistToApply' })
  @Roles('AGENCY_ADMIN')
  async inviteTherapistToApply(
    @CurrentUser() user: AuthUser,
    @Args('jobOpportunityId', { type: () => ID }) jobOpportunityId: string,
    @Args('therapistId', { type: () => ID }) therapistId: string,
  ) {
    const invite = await this.jobs.inviteTherapistToApply(
      user.id,
      user.tenantId ?? '',
      jobOpportunityId,
      therapistId,
    );
    return {
      id: invite.id,
      jobOpportunityId: invite.jobOpportunityId,
      jobTitle: invite.jobOpportunity.title,
      agencyName: invite.jobOpportunity.agency.name,
      invitedAt: invite.createdAt,
    };
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

  @Mutation(() => JobApplicationType, {
    name: 'requestJobApplicationDocuments',
  })
  @Roles('AGENCY_ADMIN')
  async requestJobApplicationDocuments(
    @CurrentUser() user: AuthUser,
    @Args('input') input: RequestJobApplicationDocumentsInput,
  ) {
    const row = await this.jobs.requestDocuments(
      user.id,
      user.tenantId ?? '',
      input.applicationId,
      input.note,
    );
    return this.mapApplication(row);
  }

  @Mutation(() => JobInterviewType, { name: 'updateJobInterviewNotes' })
  @Roles('AGENCY_ADMIN')
  async updateJobInterviewNotes(
    @CurrentUser() user: AuthUser,
    @Args('input') input: UpdateJobInterviewNotesInput,
  ) {
    const row = await this.jobs.updateJobInterviewNotes(
      user.id,
      user.tenantId ?? '',
      input.interviewId,
      input.notes,
    );
    return this.mapInterview(row);
  }

  @Mutation(() => JobApplicationType, { name: 'sendJobOffer' })
  @Roles('AGENCY_ADMIN')
  async sendJobOffer(
    @CurrentUser() user: AuthUser,
    @Args('input') input: SendJobOfferInput,
  ) {
    const row = await this.jobs.sendJobOffer(
      user.id,
      user.tenantId ?? '',
      input,
    );
    return this.mapApplication(row);
  }

  @Mutation(() => JobApplicationType, {
    name: 'approveJobApplicationCredentials',
  })
  @Roles('AGENCY_ADMIN')
  async approveJobApplicationCredentials(
    @CurrentUser() user: AuthUser,
    @Args('input') input: ApproveJobApplicationCredentialsInput,
  ) {
    const row = await this.jobs.approveApplicationCredentials(
      user.id,
      user.tenantId ?? '',
      input.applicationId,
      input.note,
    );
    return this.mapApplication(row);
  }

  @Mutation(() => JobApplicationType, {
    name: 'refreshJobApplicationCredentials',
  })
  @Roles('THERAPIST')
  async refreshJobApplicationCredentials(
    @CurrentUser() user: AuthUser,
    @Args('applicationId', { type: () => ID }) applicationId: string,
  ) {
    const row = await this.jobs.refreshJobApplicationCredentials(
      user.id,
      user.tenantId ?? '',
      applicationId,
    );
    return this.mapApplication(row);
  }

  @Mutation(() => JobApplicationType, { name: 'respondToJobOffer' })
  @Roles('THERAPIST')
  async respondToJobOffer(
    @CurrentUser() user: AuthUser,
    @Args('input') input: RespondToJobOfferInput,
  ) {
    const row = await this.jobs.respondToJobOffer(
      user.id,
      user.tenantId ?? '',
      input.applicationId,
      input.accept,
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

  @Mutation(() => Boolean, {
    name: 'addTherapistToAgencyRosterFromApplication',
  })
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

  @Mutation(() => HiringFirstSessionType, {
    name: 'scheduleFirstSessionFromHire',
  })
  @Roles('AGENCY_ADMIN')
  async scheduleFirstSessionFromHire(
    @CurrentUser() user: AuthUser,
    @Args('input') input: ScheduleFirstSessionFromHireInput,
  ) {
    return this.jobs.scheduleFirstSessionFromHire(
      user.id,
      user.tenantId ?? '',
      input,
    );
  }

  @Mutation(() => HireOnboardingType, { name: 'updateHireOnboardingStep' })
  @Roles('AGENCY_ADMIN', 'THERAPIST')
  async updateHireOnboardingStep(
    @CurrentUser() user: AuthUser,
    @Args('input') input: UpdateHireOnboardingStepInput,
  ) {
    const role = user.roles?.includes('AGENCY_ADMIN')
      ? 'AGENCY_ADMIN'
      : 'THERAPIST';
    return this.jobs.updateHireOnboardingStep(
      user.id,
      user.tenantId ?? '',
      input,
      role,
    );
  }

  @Mutation(() => PublicJobOpportunityType, {
    name: 'adminPauseJobOpportunity',
  })
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

  @Mutation(() => PublicJobOpportunityType, {
    name: 'adminRemoveJobOpportunity',
  })
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

  @Query(() => [JobInterviewType], { name: 'agencyJobInterviews' })
  @Roles('AGENCY_ADMIN')
  async agencyJobInterviews(
    @CurrentUser() user: AuthUser,
    @Args('from', { nullable: true }) from?: Date,
    @Args('to', { nullable: true }) to?: Date,
  ) {
    const rows = await this.jobs.listAgencyJobInterviews(
      user.id,
      user.tenantId ?? '',
      from,
      to,
    );
    return rows.map((row) => this.mapInterview(row));
  }

  @Query(() => JobInterviewType, {
    name: 'jobInterviewForApplication',
    nullable: true,
  })
  @Roles('AGENCY_ADMIN')
  async jobInterviewForApplication(
    @CurrentUser() user: AuthUser,
    @Args('applicationId', { type: () => ID }) applicationId: string,
  ) {
    const row = await this.jobs.getJobInterviewForApplication(
      user.id,
      user.tenantId ?? '',
      applicationId,
    );
    return row ? this.mapInterview(row) : null;
  }

  @Query(() => [JobInterviewType], { name: 'myJobInterviews' })
  @Roles('THERAPIST')
  async myJobInterviews(@CurrentUser() user: AuthUser) {
    const rows = await this.jobs.listTherapistJobInterviews(
      user.id,
      user.tenantId ?? '',
    );
    return rows.map((row) => this.mapInterview(row));
  }

  @Mutation(() => JobInterviewType, { name: 'scheduleJobInterview' })
  @Roles('AGENCY_ADMIN')
  async scheduleJobInterview(
    @CurrentUser() user: AuthUser,
    @Args('input') input: ScheduleJobInterviewInput,
  ) {
    const row = await this.jobs.scheduleJobInterview(
      user.id,
      user.tenantId ?? '',
      input,
    );
    return this.mapInterview(row);
  }

  @Mutation(() => JobInterviewType, {
    name: 'grantJobInterviewRecordingConsent',
  })
  @Roles('AGENCY_ADMIN', 'THERAPIST')
  async grantJobInterviewRecordingConsent(
    @CurrentUser() user: AuthUser,
    @Args('input') input: JobInterviewConsentInput,
  ) {
    const row = await this.jobs.grantJobInterviewRecordingConsent(
      user.id,
      user.tenantId ?? '',
      input.interviewId,
      input.consent,
    );
    return this.mapInterview(row);
  }

  @Mutation(() => JobInterviewType, { name: 'cancelJobInterview' })
  @Roles('AGENCY_ADMIN')
  async cancelJobInterview(
    @CurrentUser() user: AuthUser,
    @Args('interviewId', { type: () => ID }) interviewId: string,
    @Args('reason', { nullable: true }) reason?: string,
  ) {
    const row = await this.jobs.cancelJobInterview(
      user.id,
      user.tenantId ?? '',
      interviewId,
      reason,
    );
    return this.mapInterview(row);
  }

  @Mutation(() => JobInterviewType, { name: 'rescheduleJobInterview' })
  @Roles('AGENCY_ADMIN')
  async rescheduleJobInterview(
    @CurrentUser() user: AuthUser,
    @Args('input') input: RescheduleJobInterviewInput,
  ) {
    const row = await this.jobs.rescheduleJobInterview(
      user.id,
      user.tenantId ?? '',
      input,
    );
    return this.mapInterview(row);
  }

  @Mutation(() => JobInterviewType, { name: 'completeJobInterviewManually' })
  @Roles('AGENCY_ADMIN')
  async completeJobInterviewManually(
    @CurrentUser() user: AuthUser,
    @Args('interviewId', { type: () => ID }) interviewId: string,
    @Args('note', { nullable: true }) note?: string,
  ) {
    const row = await this.jobs.completeJobInterviewManually(
      user.id,
      user.tenantId ?? '',
      interviewId,
      note,
    );
    return this.mapInterview(row);
  }

  @Mutation(() => JobInterviewJoinType, { name: 'joinJobInterview' })
  @Roles('AGENCY_ADMIN', 'THERAPIST')
  async joinJobInterview(
    @CurrentUser() user: AuthUser,
    @Args('interviewId', { type: () => ID }) interviewId: string,
  ) {
    const row = await this.jobs.joinJobInterview(
      user.id,
      user.tenantId ?? '',
      interviewId,
      {},
    );
    return {
      interviewId: row.interviewId,
      recordingEnabled: row.recordingEnabled,
      jobTitle: row.jobTitle,
      therapistName: row.therapistName,
      agencyName: row.agencyName,
      callSessionId: row.id,
      joinUrl: row.joinUrl,
      token: row.token!,
      tokenExpiresAt: row.tokenExpiresAt!,
    };
  }

  private mapInterview(row: {
    id: string;
    applicationId: string;
    scheduledAt: Date;
    durationMinutes: number;
    status: string;
    recordingRequested: boolean;
    agencyRecordingConsent: boolean;
    therapistRecordingConsent: boolean;
    notes?: string | null;
    callSession?: { id: string } | null;
    application: {
      jobOpportunity: { id: string; title: string };
      therapist?: {
        user?: { firstName: string; lastName: string; email?: string };
      };
    };
    agency: { name: string };
  }): JobInterviewType {
    const therapist = row.application.therapist?.user;
    const recordingEnabled =
      row.recordingRequested &&
      row.agencyRecordingConsent &&
      row.therapistRecordingConsent;
    return {
      id: row.id,
      applicationId: row.applicationId,
      jobOpportunityId: row.application.jobOpportunity.id,
      jobTitle: row.application.jobOpportunity.title,
      therapistName: therapist
        ? `${therapist.firstName} ${therapist.lastName}`
        : 'Therapist',
      therapistEmail: therapist?.email,
      agencyName: row.agency.name,
      scheduledAt: row.scheduledAt,
      durationMinutes: row.durationMinutes,
      status: row.status as never,
      recordingRequested: row.recordingRequested,
      agencyRecordingConsent: row.agencyRecordingConsent,
      therapistRecordingConsent: row.therapistRecordingConsent,
      recordingEnabled,
      notes: row.notes ?? undefined,
      callSessionId: row.callSession?.id,
    };
  }

  private mapApplication(row: {
    id: string;
    status: string;
    message?: string | null;
    credentialSnapshot?: unknown;
    createdAt: Date;
    updatedAt: Date;
    therapist?: {
      user?: { firstName: string; lastName: string; email: string };
    };
    jobOpportunity?: { id: string; title: string };
    statusHistory?: Array<{
      fromStatus: string | null;
      toStatus: string;
      note?: string | null;
      createdAt: Date;
      changedBy?: { firstName: string; lastName: string };
    }>;
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
      credentialDocuments: this.jobs.parseCredentialDocuments(
        row.credentialSnapshot,
      ),
      recentStatusHistory: (row.statusHistory ?? []).map((entry) => ({
        fromStatus: entry.fromStatus as never,
        toStatus: entry.toStatus as never,
        note: entry.note ?? undefined,
        changedByName: entry.changedBy
          ? `${entry.changedBy.firstName} ${entry.changedBy.lastName}`.trim()
          : 'System',
        createdAt: entry.createdAt,
      })),
    };
  }
}
