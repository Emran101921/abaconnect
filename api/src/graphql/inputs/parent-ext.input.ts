import { Field, ID, InputType, Int } from '@nestjs/graphql';

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
