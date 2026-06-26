import {
  Field,
  Float,
  ID,
  Int,
  ObjectType,
  registerEnumType,
} from '@nestjs/graphql';
import {
  ChildServiceNeedStatus,
  JobApplicationStatus,
  JobEmploymentType,
  JobInterviewStatus,
  JobLocationModality,
  JobOpportunityStatus,
  JobServiceType,
} from '../../../generated/prisma/client';
import { JOB_OPPORTUNITY_DISCLAIMER } from '../../job-opportunities/job-opportunity.constants';

registerEnumType(JobServiceType, { name: 'JobServiceType' });
registerEnumType(JobOpportunityStatus, { name: 'JobOpportunityStatus' });
registerEnumType(JobApplicationStatus, { name: 'JobApplicationStatus' });
registerEnumType(JobEmploymentType, { name: 'JobEmploymentType' });
registerEnumType(JobLocationModality, { name: 'JobLocationModality' });
registerEnumType(ChildServiceNeedStatus, { name: 'ChildServiceNeedStatus' });
registerEnumType(JobInterviewStatus, { name: 'JobInterviewStatus' });

@ObjectType()
export class PublicJobOpportunityType {
  @Field(() => ID)
  id: string;

  @Field()
  title: string;

  @Field(() => JobServiceType)
  serviceType: JobServiceType;

  @Field()
  serviceTypeLabel: string;

  @Field(() => JobOpportunityStatus)
  status: JobOpportunityStatus;

  @Field({ nullable: true })
  publicDescription?: string;

  @Field()
  locationAreaLabel: string;

  @Field()
  zipCode: string;

  @Field({ nullable: true })
  borough?: string;

  @Field({ nullable: true })
  county?: string;

  @Field(() => Int, { nullable: true })
  serviceRadiusMiles?: number;

  @Field(() => Float, { nullable: true })
  distanceMiles?: number;

  @Field()
  scheduleJson: string;

  @Field({ nullable: true })
  languageRequirement?: string;

  @Field(() => JobEmploymentType, { nullable: true })
  employmentType?: JobEmploymentType;

  @Field({ nullable: true })
  payRateDisplay?: string;

  @Field(() => JobLocationModality)
  locationModality: JobLocationModality;

  @Field()
  requiredCredentialsJson: string;

  @Field({ nullable: true })
  requiredExperience?: string;

  @Field({ nullable: true })
  preferredStartDate?: Date;

  @Field({ nullable: true })
  publishedAt?: Date;

  @Field({ nullable: true })
  agencyName?: string;

  @Field(() => Int, { nullable: true })
  applicationCount?: number;

  @Field(() => Int, { nullable: true })
  pendingActionCount?: number;

  @Field()
  disclaimer: string;

  @Field()
  createdAt: Date;

  @Field({ nullable: true })
  isSaved?: boolean;

  @Field(() => ID, { nullable: true })
  myApplicationId?: string;

  @Field(() => JobApplicationStatus, { nullable: true })
  myApplicationStatus?: JobApplicationStatus;
}

@ObjectType()
export class ChildServiceNeedType {
  @Field(() => ID)
  id: string;

  @Field(() => JobServiceType)
  serviceType: JobServiceType;

  @Field({ nullable: true })
  internalNotes?: string;

  @Field()
  internalScheduleJson: string;

  @Field(() => ChildServiceNeedStatus)
  status: ChildServiceNeedStatus;

  @Field()
  childDisplayName: string;

  @Field(() => ID, { nullable: true })
  childId?: string;

  @Field({ nullable: true })
  jobOpportunityId?: string;

  @Field({ nullable: true })
  jobOpportunityTitle?: string;

  @Field({ nullable: true })
  jobOpportunityStatus?: string;

  @Field()
  createdAt: Date;
}

@ObjectType()
export class JobApplicationStatusHistoryType {
  @Field(() => JobApplicationStatus, { nullable: true })
  fromStatus?: JobApplicationStatus;

  @Field(() => JobApplicationStatus)
  toStatus: JobApplicationStatus;

  @Field({ nullable: true })
  note?: string;

  @Field()
  changedByName: string;

  @Field()
  createdAt: Date;
}

@ObjectType()
export class JobCredentialDocumentType {
  @Field(() => ID)
  id: string;

  @Field()
  title: string;

  @Field()
  fileName: string;

  @Field()
  type: string;

  @Field()
  uploadedAt: Date;
}

@ObjectType()
export class JobApplicationType {
  @Field(() => ID)
  id: string;

  @Field(() => JobApplicationStatus)
  status: JobApplicationStatus;

  @Field({ nullable: true })
  message?: string;

  @Field()
  therapistName: string;

  @Field({ nullable: true })
  therapistEmail?: string;

  @Field(() => ID)
  jobOpportunityId: string;

  @Field()
  jobTitle: string;

  @Field()
  createdAt: Date;

  @Field()
  updatedAt: Date;

  @Field(() => [JobCredentialDocumentType])
  credentialDocuments: JobCredentialDocumentType[];

  @Field(() => [JobApplicationStatusHistoryType])
  recentStatusHistory: JobApplicationStatusHistoryType[];
}

@ObjectType()
export class AgencyHiringPipelineSummaryType {
  @Field(() => Int)
  newApplicants: number;

  @Field(() => Int)
  credentialReview: number;

  @Field(() => Int)
  credentialsSubmitted: number;

  @Field(() => Int)
  offersPending: number;

  @Field(() => Int)
  readyToHire: number;

  @Field(() => Int)
  totalPendingActions: number;
}

@ObjectType()
export class HiringFirstSessionType {
  @Field(() => ID)
  appointmentId: string;

  @Field(() => ID)
  childId: string;

  @Field(() => ID)
  therapistId: string;

  @Field()
  scheduledStart: Date;

  @Field()
  scheduledEnd: Date;
}

@ObjectType()
export class JobMarketplaceAuditLogType {
  @Field(() => ID)
  id: string;

  @Field()
  eventType: string;

  @Field()
  entityType: string;

  @Field(() => ID)
  entityId: string;

  @Field({ nullable: true })
  actorName?: string;

  @Field()
  metadataJson: string;

  @Field()
  createdAt: Date;
}

@ObjectType()
export class JobOpportunityInviteType {
  @Field(() => ID)
  id: string;

  @Field(() => ID)
  jobOpportunityId: string;

  @Field()
  jobTitle: string;

  @Field()
  agencyName: string;

  @Field()
  invitedAt: Date;
}

@ObjectType()
export class JobInterviewType {
  @Field(() => ID)
  id: string;

  @Field(() => ID)
  applicationId: string;

  @Field(() => ID)
  jobOpportunityId: string;

  @Field()
  jobTitle: string;

  @Field()
  therapistName: string;

  @Field({ nullable: true })
  therapistEmail?: string;

  @Field()
  agencyName: string;

  @Field()
  scheduledAt: Date;

  @Field(() => Int)
  durationMinutes: number;

  @Field(() => JobInterviewStatus)
  status: JobInterviewStatus;

  @Field()
  recordingRequested: boolean;

  @Field()
  agencyRecordingConsent: boolean;

  @Field()
  therapistRecordingConsent: boolean;

  @Field()
  recordingEnabled: boolean;

  @Field({ nullable: true })
  notes?: string;

  @Field(() => ID, { nullable: true })
  callSessionId?: string;
}

@ObjectType()
export class JobInterviewJoinType {
  @Field(() => ID)
  interviewId: string;

  @Field()
  recordingEnabled: boolean;

  @Field()
  jobTitle: string;

  @Field()
  therapistName: string;

  @Field()
  agencyName: string;

  @Field(() => ID)
  callSessionId: string;

  @Field({ nullable: true })
  joinUrl?: string;

  @Field()
  token: string;

  @Field()
  tokenExpiresAt: Date;
}

@ObjectType()
export class JobOpportunityBrowseResultType {
  @Field(() => [PublicJobOpportunityType])
  items: PublicJobOpportunityType[];

  @Field(() => Int)
  page: number;

  @Field(() => Int)
  pageSize: number;

  @Field(() => Int)
  total: number;
}

@ObjectType()
export class HireOnboardingStepType {
  @Field()
  key: string;

  @Field()
  label: string;

  @Field()
  complete: boolean;

  @Field({ nullable: true })
  completedAt?: Date;

  @Field()
  therapistCanComplete: boolean;
}

@ObjectType()
export class HireOnboardingType {
  @Field(() => ID)
  agencyTherapistLinkId: string;

  @Field(() => ID)
  therapistId: string;

  @Field()
  therapistName: string;

  @Field(() => ID)
  agencyId: string;

  @Field()
  agencyName: string;

  @Field(() => [HireOnboardingStepType])
  steps: HireOnboardingStepType[];

  @Field(() => Int)
  completedCount: number;

  @Field(() => Int)
  totalCount: number;

  @Field()
  isComplete: boolean;
}

export function mapPublicJobType(
  row: import('../../job-opportunities/job-opportunity-privacy.util').PublicJobOpportunity,
): PublicJobOpportunityType {
  return {
    ...row,
    scheduleJson: JSON.stringify(row.schedule ?? {}),
    requiredCredentialsJson: JSON.stringify(row.requiredCredentials ?? []),
    disclaimer: JOB_OPPORTUNITY_DISCLAIMER,
  } as PublicJobOpportunityType;
}
