import { Field, ID, InputType } from '@nestjs/graphql';
import { TherapyType } from '../../../generated/prisma/client';

@InputType()
export class CreateTreatmentPlanInput {
  @Field(() => ID)
  childId: string;

  @Field(() => TherapyType)
  therapyType: TherapyType;

  @Field()
  title: string;

  @Field()
  startDate: Date;
}

@InputType()
export class SaveProgressNoteInput {
  @Field(() => ID)
  sessionId: string;

  @Field()
  summary: string;

  @Field({ nullable: true })
  parentFeedback?: string;
}
