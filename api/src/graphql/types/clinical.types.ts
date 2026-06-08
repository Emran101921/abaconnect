import { Field, Float, ID, Int, ObjectType } from '@nestjs/graphql';
import { TherapyType } from '../../../generated/prisma/client';
import { ChildType } from './parent-booking.types';

@ObjectType()
export class TreatmentPlanGoalType {
  @Field()
  id: string;

  @Field()
  label: string;

  @Field({ nullable: true })
  status?: string;
}

@ObjectType()
export class TreatmentPlanType {
  @Field(() => ID)
  id: string;

  @Field()
  title: string;

  @Field(() => TherapyType)
  therapyType: TherapyType;

  @Field()
  startDate: Date;

  @Field()
  isActive: boolean;

  @Field(() => ChildType, { nullable: true })
  child?: ChildType;

  @Field({ nullable: true })
  therapistName?: string;

  @Field(() => [TreatmentPlanGoalType])
  goals: TreatmentPlanGoalType[];

  @Field(() => Int)
  goalsDoneCount: number;

  @Field(() => Int)
  goalsTotalCount: number;
}

@ObjectType()
export class WeeklyProgressWeekType {
  @Field()
  weekLabel: string;

  @Field(() => Int)
  reportCount: number;
}

@ObjectType()
export class ChildProgressSummaryType {
  @Field(() => ID)
  childId: string;

  @Field()
  childName: string;

  @Field(() => Float)
  goalCompletionPercent: number;

  @Field({ nullable: true })
  activePlanTitle?: string;
}

@ObjectType()
export class TherapistWeeklyProgressType {
  @Field(() => [WeeklyProgressWeekType])
  weeks: WeeklyProgressWeekType[];

  @Field(() => [ChildProgressSummaryType])
  children: ChildProgressSummaryType[];
}

@ObjectType()
export class TherapistBadgeType {
  @Field()
  type: string;

  @Field({ nullable: true })
  label?: string;

  @Field()
  awardedAt: Date;
}
