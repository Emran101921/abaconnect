import { Field, Float, ID, InputType, Int } from '@nestjs/graphql';
import {
  IsBoolean,
  IsDateString,
  IsEnum,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
} from 'class-validator';
import {
  GqlEiBillingQueueStatus,
  GqlEiClearinghouseWorkflow,
} from '../types/ei-billing.types';

@InputType()
export class EiBillingQueueFilterInput {
  @Field(() => ID, { nullable: true })
  @IsOptional()
  @IsUUID()
  agencyId?: string;

  @Field(() => GqlEiBillingQueueStatus, { nullable: true })
  @IsOptional()
  @IsEnum(GqlEiBillingQueueStatus)
  status?: GqlEiBillingQueueStatus;

  @Field(() => ID, { nullable: true })
  @IsOptional()
  @IsUUID()
  childId?: string;

  @Field(() => Int, { nullable: true })
  @IsOptional()
  take?: number;
}

@InputType()
export class UpsertEiAgencyBillingProfileInput {
  @Field(() => ID, { nullable: true })
  @IsOptional()
  @IsUUID()
  agencyId?: string;

  @Field()
  @IsString()
  legalName: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  npi?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  medicaidProviderId?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  ein?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  etin?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  eiHubReferenceId?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsBoolean()
  enrollmentComplete?: boolean;

  @Field({ nullable: true })
  @IsOptional()
  @IsDateString()
  baaSignedAt?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  city?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  state?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  zipCode?: string;
}

@InputType()
export class UpsertEiProviderEnrollmentInput {
  @Field(() => ID, { nullable: true })
  @IsOptional()
  @IsUUID()
  agencyId?: string;

  @Field(() => ID)
  @IsUUID()
  therapistId: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  renderingNpi?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  discipline?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  eiCategory?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  medicaidEnrollmentStatus?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  credentialStatus?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsDateString()
  licenseExpiry?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}

@InputType()
export class UpsertEiCaseBillingProfileInput {
  @Field(() => ID, { nullable: true })
  @IsOptional()
  @IsUUID()
  agencyId?: string;

  @Field(() => ID)
  @IsUUID()
  childId: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  eiCaseId?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  municipality?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  ifspAuthorizationNumber?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  serviceType?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  medicaidCin?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  consentStatus?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsDateString()
  authorizationStartDate?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsDateString()
  authorizationEndDate?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  placeOfService?: string;
}

@InputType()
export class TransitionEiBillingQueueInput {
  @Field(() => ID)
  @IsUUID()
  recordId: string;

  @Field(() => GqlEiBillingQueueStatus)
  @IsEnum(GqlEiBillingQueueStatus)
  targetStatus: GqlEiBillingQueueStatus;
}

@InputType()
export class ExportEiBillingRecordInput {
  @Field(() => ID)
  @IsUUID()
  recordId: string;

  @Field(() => GqlEiClearinghouseWorkflow)
  @IsEnum(GqlEiClearinghouseWorkflow)
  workflow: GqlEiClearinghouseWorkflow;

  @Field()
  @IsBoolean()
  authorizedConfirm: boolean;
}

@InputType()
export class SubmitEiBillingRecordInput {
  @Field(() => ID)
  @IsUUID()
  recordId: string;

  @Field(() => GqlEiClearinghouseWorkflow)
  @IsEnum(GqlEiClearinghouseWorkflow)
  workflow: GqlEiClearinghouseWorkflow;

  @Field()
  @IsBoolean()
  authorizedConfirm: boolean;
}

@InputType()
export class RecordEiDenialInput {
  @Field(() => ID)
  @IsUUID()
  recordId: string;

  @Field()
  @IsString()
  code: string;

  @Field()
  @IsString()
  reason: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  payerName?: string;
}

@InputType()
export class ImportEiEraStubInput {
  @Field(() => ID)
  @IsUUID()
  recordId: string;

  @Field()
  @IsString()
  eraJson: string;
}

@InputType()
export class RecordEiPaymentInput {
  @Field(() => ID)
  @IsUUID()
  recordId: string;

  @Field(() => Float)
  @IsNumber()
  paidAmount: number;

  @Field(() => Float, { nullable: true })
  @IsOptional()
  @IsNumber()
  allowedAmount?: number;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  eftReference?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  eraPlaceholder?: string;
}

@InputType()
export class UpsertEiClearinghouseConfigInput {
  @Field(() => ID, { nullable: true })
  @IsOptional()
  @IsUUID()
  id?: string;

  @Field(() => ID, { nullable: true })
  @IsOptional()
  @IsUUID()
  agencyId?: string;

  @Field()
  @IsString()
  name: string;

  @Field(() => GqlEiClearinghouseWorkflow)
  @IsEnum(GqlEiClearinghouseWorkflow)
  workflow: GqlEiClearinghouseWorkflow;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  tradingPartnerId?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsBoolean()
  testMode?: boolean;

  @Field({ nullable: true })
  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @Field({ nullable: true })
  @IsOptional()
  @IsDateString()
  baaSignedAt?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  credentialsRef?: string;
}
