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
export class SubmitScreeningInput {
  @Field(() => ID)
  templateId: string;

  @Field(() => ID)
  childId: string;

  @Field()
  responsesJson: string;
}
