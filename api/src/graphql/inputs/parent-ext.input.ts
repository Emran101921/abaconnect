import { Field, ID, InputType, Int } from '@nestjs/graphql';
import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsDate,
  IsOptional,
  IsString,
  IsUUID,
  MinLength,
} from 'class-validator';

@InputType()
export class UpdateParentProfileInput {
  @Field({ nullable: true })
  addressLine1?: string;

  @Field({ nullable: true })
  addressLine2?: string;

  @Field({ nullable: true })
  city?: string;

  @Field({ nullable: true })
  state?: string;

  @Field({ nullable: true })
  zipCode?: string;

  @Field({ nullable: true })
  emergencyContactName?: string;

  @Field({ nullable: true })
  emergencyContactPhone?: string;

  @Field({ nullable: true })
  insuranceProvider?: string;

  @Field({ nullable: true })
  insuranceMemberId?: string;

  @Field({ nullable: true })
  insuranceGroupNumber?: string;
}

@InputType()
export class UpdateChildInput {
  @Field(() => ID)
  @IsUUID()
  childId!: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  @MinLength(1)
  firstName?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  @MinLength(1)
  lastName?: string;

  @Field({ nullable: true })
  @IsOptional()
  @Type(() => Date)
  @IsDate()
  dateOfBirth?: Date;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  gender?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  primaryLanguage?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  guardianName?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  guardianPhone?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  guardianEmail?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  addressLine1?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  zipCode?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  pediatricianName?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  insuranceType?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsBoolean()
  hadEarlyIntervention?: boolean;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  notes?: string;
}

@InputType()
export class AddChildInput {
  @Field()
  @IsString()
  @MinLength(1)
  firstName: string;

  @Field()
  @IsString()
  @MinLength(1)
  lastName: string;

  @Field()
  @Type(() => Date)
  @IsDate()
  dateOfBirth: Date;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  gender?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  primaryLanguage?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  guardianName?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  guardianPhone?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  guardianEmail?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  addressLine1?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  zipCode?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  pediatricianName?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  insuranceType?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsBoolean()
  hadEarlyIntervention?: boolean;
}

@InputType()
export class SubmitReviewInput {
  @Field(() => ID)
  therapistId: string;

  @Field(() => Int)
  rating: number;

  @Field({ nullable: true })
  title?: string;

  @Field({ nullable: true })
  comment?: string;
}

@InputType()
export class SaveScreeningDraftInput {
  @Field(() => ID)
  templateId: string;

  @Field(() => ID)
  childId: string;

  @Field()
  responsesJson: string;

  @Field(() => ID, { nullable: true })
  draftId?: string;
}

@InputType()
export class SubmitScreeningInput {
  @Field(() => ID)
  @IsUUID()
  templateId: string;

  @Field(() => ID)
  @IsUUID()
  childId: string;

  @Field()
  @IsString()
  responsesJson: string;

  @Field(() => ID, { nullable: true })
  @IsOptional()
  @IsUUID()
  draftId?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsBoolean()
  consentGranted?: boolean;
}
