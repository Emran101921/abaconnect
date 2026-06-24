import { Field, ID, InputType } from '@nestjs/graphql';
import {
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  MinLength,
} from 'class-validator';
import {
  JobApplicationStatus,
  JobEmploymentType,
  JobLocationModality,
  JobServiceType,
} from '../../../generated/prisma/client';

@InputType()
export class CreateChildServiceNeedInput {
  @Field(() => ID)
  @IsUUID()
  childId!: string;

  @Field(() => JobServiceType)
  @IsIn(Object.values(JobServiceType))
  serviceType!: JobServiceType;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  internalNotes?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  internalScheduleJson?: string;
}

@InputType()
export class UpdateJobOpportunityInput {
  @Field(() => ID)
  @IsUUID()
  jobOpportunityId!: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  title?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  publicDescription?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  zipCode?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  borough?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  county?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsNumber()
  serviceRadiusMiles?: number;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  scheduleJson?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  languageRequirement?: string;

  @Field(() => JobEmploymentType, { nullable: true })
  @IsOptional()
  @IsIn(Object.values(JobEmploymentType))
  employmentType?: JobEmploymentType;

  @Field({ nullable: true })
  @IsOptional()
  @IsNumber()
  payRateMin?: number;

  @Field({ nullable: true })
  @IsOptional()
  @IsNumber()
  payRateMax?: number;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  payRateDisplay?: string;

  @Field(() => JobLocationModality, { nullable: true })
  @IsOptional()
  @IsIn(Object.values(JobLocationModality))
  locationModality?: JobLocationModality;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  requiredCredentialsJson?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  requiredExperience?: string;
}

@InputType()
export class BrowseJobOpportunitiesInput {
  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  zipCode?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsNumber()
  radiusMiles?: number;

  @Field(() => JobServiceType, { nullable: true })
  @IsOptional()
  @IsIn(Object.values(JobServiceType))
  serviceType?: JobServiceType;

  @Field(() => JobEmploymentType, { nullable: true })
  @IsOptional()
  @IsIn(Object.values(JobEmploymentType))
  employmentType?: JobEmploymentType;

  @Field(() => JobLocationModality, { nullable: true })
  @IsOptional()
  @IsIn(Object.values(JobLocationModality))
  locationModality?: JobLocationModality;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  language?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsNumber()
  page?: number;

  @Field({ nullable: true })
  @IsOptional()
  @IsNumber()
  pageSize?: number;
}

@InputType()
export class ApplyToJobOpportunityInput {
  @Field(() => ID)
  @IsUUID()
  jobOpportunityId!: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  message?: string;
}

@InputType()
export class UpdateJobApplicationStatusInput {
  @Field(() => ID)
  @IsUUID()
  applicationId!: string;

  @Field(() => JobApplicationStatus)
  @IsIn(Object.values(JobApplicationStatus))
  status!: JobApplicationStatus;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  note?: string;
}

@InputType()
export class AdminJobModerationInput {
  @Field(() => ID)
  @IsUUID()
  jobOpportunityId!: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  @MinLength(3)
  reason?: string;
}
