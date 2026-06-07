import { Field, ID, InputType } from '@nestjs/graphql';
import { TherapyType } from '../../../generated/prisma/client';

@InputType()
export class TreatmentPlanGoalInput {
  @Field()
  id: string;

  @Field()
  label: string;

  @Field({ nullable: true })
  status?: string;
}

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

  @Field(() => [TreatmentPlanGoalInput], { nullable: true })
  goals?: TreatmentPlanGoalInput[];
}

@InputType()
export class UpdateTreatmentPlanInput {
  @Field(() => ID)
  planId: string;

  @Field({ nullable: true })
  title?: string;

  @Field({ nullable: true })
  isActive?: boolean;

  @Field(() => [TreatmentPlanGoalInput], { nullable: true })
  goals?: TreatmentPlanGoalInput[];
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

@InputType()
export class SubmitSessionFeedbackInput {
  @Field(() => ID)
  sessionId: string;

  @Field()
  feedback: string;
}
