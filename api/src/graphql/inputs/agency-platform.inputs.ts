import { Field, ID, InputType } from '@nestjs/graphql';
import { TherapyType } from '../../../generated/prisma/client';

@InputType()
export class UpsertAgencyBranchInput {
  @Field(() => ID, { nullable: true })
  id?: string;

  @Field()
  name!: string;

  @Field({ nullable: true })
  region?: string;

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
  phone?: string;

  @Field({ nullable: true })
  email?: string;

  @Field({ nullable: true })
  active?: boolean;
}

@InputType()
export class UpsertAgencyDepartmentInput {
  @Field(() => ID, { nullable: true })
  id?: string;

  @Field(() => ID, { nullable: true })
  branchId?: string;

  @Field()
  name!: string;

  @Field({ nullable: true })
  code?: string;

  @Field({ nullable: true })
  active?: boolean;
}

@InputType()
export class UpsertAgencyProgramInput {
  @Field(() => ID, { nullable: true })
  id?: string;

  @Field()
  name!: string;

  @Field({ nullable: true })
  code?: string;

  @Field(() => TherapyType, { nullable: true })
  serviceType?: TherapyType;

  @Field({ nullable: true })
  description?: string;

  @Field({ nullable: true })
  region?: string;

  @Field({ nullable: true })
  active?: boolean;

  @Field({ nullable: true })
  settingsJson?: string;
}

@InputType()
export class UpdateAgencyFeatureModuleInput {
  @Field()
  moduleKey!: string;

  @Field()
  enabled!: boolean;

  @Field({ nullable: true })
  settingsJson?: string;
}

@InputType()
export class UpdateAgencyPlatformSettingsInput {
  @Field()
  settingsJson!: string;
}

@InputType()
export class UpsertAgencyPermissionGrantInput {
  @Field(() => ID, { nullable: true })
  id?: string;

  @Field()
  scopeType!: string;

  @Field(() => ID, { nullable: true })
  scopeId?: string;

  @Field()
  permission!: string;

  @Field({ nullable: true })
  granted?: boolean;
}

@InputType()
export class UpsertAgencyReferralInput {
  @Field(() => ID, { nullable: true })
  id?: string;

  @Field({ nullable: true })
  contactName?: string;

  @Field({ nullable: true })
  contactPhone?: string;

  @Field({ nullable: true })
  contactEmail?: string;

  @Field({ nullable: true })
  childName?: string;

  @Field({ nullable: true })
  sourceName?: string;

  @Field({ nullable: true })
  sourceType?: string;

  @Field({ nullable: true })
  status?: string;

  @Field({ nullable: true })
  notes?: string;
}

@InputType()
export class UpsertProviderPayRateInput {
  @Field(() => ID, { nullable: true })
  id?: string;

  @Field(() => ID)
  therapistId!: string;

  @Field(() => TherapyType, { nullable: true })
  serviceType?: TherapyType;

  @Field()
  rateCents!: number;

  @Field({ nullable: true })
  rateUnit?: string;

  @Field({ nullable: true })
  effectiveFrom?: Date;

  @Field({ nullable: true })
  active?: boolean;
}

@InputType()
export class ConvertAgencyReferralInput {
  @Field(() => ID)
  referralId!: string;

  @Field()
  dateOfBirth!: Date;

  @Field({ nullable: true })
  firstName?: string;

  @Field({ nullable: true })
  lastName?: string;
}
