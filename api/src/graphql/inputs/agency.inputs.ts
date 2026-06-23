import { Field, ID, InputType } from '@nestjs/graphql';
import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsDate,
  IsOptional,
  IsString,
  IsUUID,
  MinLength,
} from 'class-validator';
import { AgencyDocumentType } from '../../../generated/prisma/client';

@InputType()
export class UpdateAgencyProfileInput {
  @Field({ nullable: true })
  name?: string;

  @Field({ nullable: true })
  ein?: string;

  @Field({ nullable: true })
  phone?: string;

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
  email?: string;

  @Field({ nullable: true })
  website?: string;
}

@InputType()
export class CreateAgencyStaffInput {
  @Field()
  email!: string;

  @Field()
  password!: string;

  @Field()
  firstName!: string;

  @Field()
  lastName!: string;

  @Field({ nullable: true })
  phone?: string;

  @Field({ nullable: true })
  licenseNumber?: string;

  @Field({ nullable: true })
  licenseState?: string;

  @Field({ nullable: true })
  npi?: string;
}

@InputType()
export class AddAgencyCaseloadChildInput {
  @Field()
  @IsString()
  @MinLength(1)
  firstName!: string;

  @Field()
  @IsString()
  @MinLength(1)
  lastName!: string;

  @Field()
  @Type(() => Date)
  @IsDate()
  dateOfBirth!: Date;

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
export class UpdateAgencyCaseloadChildInput {
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
}

export { AgencyDocumentType };
