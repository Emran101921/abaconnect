import { Field, ID, ObjectType } from '@nestjs/graphql';
import { TherapyType } from '../../../generated/prisma/client';
import { ChildType } from './parent-booking.types';

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
