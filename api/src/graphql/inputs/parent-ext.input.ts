import { Field, ID, InputType, Int } from '@nestjs/graphql';

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
  childId: string;

  @Field({ nullable: true })
  firstName?: string;

  @Field({ nullable: true })
  lastName?: string;

  @Field({ nullable: true })
  dateOfBirth?: Date;

  @Field({ nullable: true })
  gender?: string;

  @Field({ nullable: true })
  primaryLanguage?: string;

  @Field({ nullable: true })
  guardianName?: string;

  @Field({ nullable: true })
  guardianPhone?: string;

  @Field({ nullable: true })
  guardianEmail?: string;

  @Field({ nullable: true })
  addressLine1?: string;

  @Field({ nullable: true })
  zipCode?: string;

  @Field({ nullable: true })
  pediatricianName?: string;

  @Field({ nullable: true })
  insuranceType?: string;

  @Field({ nullable: true })
  hadEarlyIntervention?: boolean;

  @Field({ nullable: true })
  notes?: string;
}

@InputType()
export class AddChildInput {
  @Field()
  firstName: string;

  @Field()
  lastName: string;

  @Field()
  dateOfBirth: Date;

  @Field({ nullable: true })
  gender?: string;

  @Field({ nullable: true })
  primaryLanguage?: string;

  @Field({ nullable: true })
  guardianName?: string;

  @Field({ nullable: true })
  guardianPhone?: string;

  @Field({ nullable: true })
  guardianEmail?: string;

  @Field({ nullable: true })
  addressLine1?: string;

  @Field({ nullable: true })
  zipCode?: string;

  @Field({ nullable: true })
  pediatricianName?: string;

  @Field({ nullable: true })
  insuranceType?: string;

  @Field({ nullable: true })
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
  templateId: string;

  @Field(() => ID)
  childId: string;

  @Field()
  responsesJson: string;

  @Field(() => ID, { nullable: true })
  draftId?: string;

  @Field({ nullable: true })
  consentGranted?: boolean;
}
