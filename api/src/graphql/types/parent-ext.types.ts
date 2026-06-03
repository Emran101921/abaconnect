import { Field, Float, ID, Int, ObjectType } from '@nestjs/graphql';
import { TherapyType } from '../../../generated/prisma/client';
import { TherapistUserType } from './parent-booking.types';

@ObjectType()
export class ReviewType {
  @Field(() => ID)
  id: string;

  @Field(() => Int)
  rating: number;

  @Field({ nullable: true })
  title?: string;

  @Field({ nullable: true })
  comment?: string;

  @Field()
  createdAt: Date;

  @Field(() => TherapistUserType, { nullable: true })
  therapistUser?: TherapistUserType;
}

@ObjectType()
export class ScreeningTemplateType {
  @Field(() => ID)
  id: string;

  @Field()
  name: string;

  @Field(() => TherapyType)
  therapyType: TherapyType;

  @Field()
  version: string;

  @Field({ nullable: true })
  questionsJson?: string;
}

@ObjectType()
export class ScreeningResponseType {
  @Field(() => ID)
  id: string;

  @Field()
  completedAt: Date;

  @Field(() => ScreeningTemplateType, { nullable: true })
  template?: ScreeningTemplateType;
}
