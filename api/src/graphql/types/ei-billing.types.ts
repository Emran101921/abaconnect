import {
  Field,
  Float,
  ID,
  Int,
  ObjectType,
  registerEnumType,
} from '@nestjs/graphql';

export enum GqlEiBillingQueueStatus {
  DRAFT_INCOMPLETE = 'DRAFT_INCOMPLETE',
  MISSING_INFORMATION = 'MISSING_INFORMATION',
  READY_AGENCY_REVIEW = 'READY_AGENCY_REVIEW',
  READY_BILLING_VALIDATION = 'READY_BILLING_VALIDATION',
  READY_AUTHORIZED_SUBMISSION = 'READY_AUTHORIZED_SUBMISSION',
  SUBMITTED = 'SUBMITTED',
  REJECTED = 'REJECTED',
  DENIED = 'DENIED',
  CORRECTION_NEEDED = 'CORRECTION_NEEDED',
  RESUBMITTED = 'RESUBMITTED',
  PAID = 'PAID',
  ARCHIVED = 'ARCHIVED',
}

export enum GqlEiClearinghouseWorkflow {
  EI_HUB = 'EI_HUB',
  STATE_FISCAL_AGENT = 'STATE_FISCAL_AGENT',
  EMEDNY = 'EMEDNY',
  EDI_837P_EXPORT = 'EDI_837P_EXPORT',
  CSV_EXPORT = 'CSV_EXPORT',
  API_CLEARINGHOUSE = 'API_CLEARINGHOUSE',
}

registerEnumType(GqlEiBillingQueueStatus, { name: 'EiBillingQueueStatus' });
registerEnumType(GqlEiClearinghouseWorkflow, {
  name: 'EiClearinghouseWorkflow',
});

@ObjectType()
export class EiBillingDashboardType {
  @Field(() => Int)
  totalRecords: number;

  @Field(() => Int)
  readyAgencyReview: number;

  @Field(() => Int)
  missingInformation: number;

  @Field(() => Int)
  submitted: number;

  @Field(() => Int)
  paid: number;

  @Field(() => Int)
  denialsAndCorrections: number;
}

@ObjectType()
export class EiValidationIssueType {
  @Field(() => ID)
  id: string;

  @Field()
  code: string;

  @Field()
  severity: string;

  @Field()
  message: string;

  @Field()
  resolved: boolean;
}

@ObjectType()
export class EiAgencyBillingProfileType {
  @Field(() => ID)
  id: string;

  @Field(() => ID)
  agencyId: string;

  @Field()
  legalName: string;

  @Field({ nullable: true })
  npi?: string;

  @Field({ nullable: true })
  medicaidProviderId?: string;

  @Field({ nullable: true })
  ein?: string;

  @Field({ nullable: true })
  etin?: string;

  @Field({ nullable: true })
  eiHubReferenceId?: string;

  @Field()
  eftEnrollmentStatus: string;

  @Field({ nullable: true })
  baaSignedAt?: Date;

  @Field()
  enrollmentComplete: boolean;

  @Field({ nullable: true })
  city?: string;

  @Field({ nullable: true })
  state?: string;
}

@ObjectType()
export class EiProviderEnrollmentType {
  @Field(() => ID)
  id: string;

  @Field(() => ID)
  therapistId: string;

  @Field({ nullable: true })
  therapistName?: string;

  @Field({ nullable: true })
  renderingNpi?: string;

  @Field({ nullable: true })
  discipline?: string;

  @Field({ nullable: true })
  eiCategory?: string;

  @Field()
  medicaidEnrollmentStatus: string;

  @Field()
  credentialStatus: string;

  @Field()
  isActive: boolean;
}

@ObjectType()
export class EiCaseBillingProfileType {
  @Field(() => ID)
  id: string;

  @Field(() => ID)
  childId: string;

  @Field({ nullable: true })
  childDisplayName?: string;

  @Field({ nullable: true })
  eiCaseId?: string;

  @Field({ nullable: true })
  municipality?: string;

  @Field({ nullable: true })
  ifspAuthorizationNumber?: string;

  @Field({ nullable: true })
  serviceType?: string;

  @Field({ nullable: true })
  medicaidCin?: string;

  @Field()
  consentStatus: string;
}

@ObjectType()
export class EiBillingRecordType {
  @Field(() => ID)
  id: string;

  @Field(() => ID)
  agencyId: string;

  @Field(() => ID)
  childId: string;

  @Field(() => ID, { nullable: true })
  sessionId?: string;

  @Field(() => GqlEiBillingQueueStatus)
  queueStatus: GqlEiBillingQueueStatus;

  @Field(() => Float)
  units: number;

  @Field()
  serviceDate: Date;

  @Field({ nullable: true })
  childDisplayName?: string;

  @Field({ nullable: true })
  therapistName?: string;

  @Field({ nullable: true })
  lockedAt?: Date;

  @Field({ nullable: true })
  submittedAt?: Date;

  @Field({ nullable: true })
  externalReferenceId?: string;

  @Field(() => [EiValidationIssueType], { nullable: true })
  validationIssues?: EiValidationIssueType[];

  @Field(() => [EiDenialType], { nullable: true })
  denials?: EiDenialType[];

  @Field(() => [EiPaymentPostingType], { nullable: true })
  payments?: EiPaymentPostingType[];
}

@ObjectType()
export class EiClearinghouseConfigType {
  @Field(() => ID)
  id: string;

  @Field()
  name: string;

  @Field(() => GqlEiClearinghouseWorkflow)
  workflow: GqlEiClearinghouseWorkflow;

  @Field()
  testMode: boolean;

  @Field()
  isActive: boolean;

  @Field({ nullable: true })
  tradingPartnerId?: string;

  @Field({ nullable: true })
  baaSignedAt?: Date;

  @Field({ nullable: true })
  lastConnectionTestAt?: Date;

  @Field({ nullable: true })
  lastConnectionTestResult?: string;
}

@ObjectType()
export class EiBillingReportRowType {
  @Field()
  status: string;

  @Field(() => Int)
  count: number;

  @Field(() => Float, { nullable: true })
  billedTotal?: number;

  @Field(() => Float, { nullable: true })
  allowedTotal?: number;
}

@ObjectType()
export class EiBillingAuditLogType {
  @Field(() => ID)
  id: string;

  @Field()
  action: string;

  @Field()
  entityType: string;

  @Field({ nullable: true })
  entityId?: string;

  @Field({ nullable: true })
  actorName?: string;

  @Field()
  metadataJson: string;

  @Field()
  createdAt: Date;
}

@ObjectType()
export class EiBillingExportResultType {
  @Field()
  artifactType: string;

  @Field()
  payload: string;

  @Field()
  fileName: string;
}

@ObjectType()
export class EiBillingSubmitResultType {
  @Field()
  accepted: boolean;

  @Field()
  externalReferenceId: string;

  @Field()
  message: string;

  @Field(() => EiBillingRecordType)
  record: EiBillingRecordType;
}

@ObjectType()
export class EiClearinghouseTestResultType {
  @Field()
  success: boolean;

  @Field()
  message: string;

  @Field(() => EiClearinghouseConfigType)
  config: EiClearinghouseConfigType;
}

@ObjectType()
export class EiDenialListItemType {
  @Field(() => ID)
  id: string;

  @Field()
  code: string;

  @Field()
  reason: string;

  @Field({ nullable: true })
  payerName?: string;

  @Field()
  correctionStatus: string;

  @Field({ nullable: true })
  receivedAt?: Date;

  @Field(() => ID)
  recordId: string;

  @Field({ nullable: true })
  childDisplayName?: string;

  @Field({ nullable: true })
  therapistName?: string;

  @Field()
  recordQueueStatus: string;
}

@ObjectType()
export class EiDenialType {
  @Field(() => ID)
  id: string;

  @Field()
  code: string;

  @Field()
  reason: string;

  @Field()
  correctionStatus: string;

  @Field({ nullable: true })
  payerName?: string;

  @Field({ nullable: true })
  receivedAt?: Date;
}

@ObjectType()
export class EiPaymentPostingType {
  @Field(() => ID)
  id: string;

  @Field(() => Float)
  paidAmount: number;

  @Field()
  reconciliationStatus: string;

  @Field()
  postedAt: Date;

  @Field(() => Float, { nullable: true })
  allowedAmount?: number;

  @Field({ nullable: true })
  eftReference?: string;
}
