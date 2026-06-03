import { Field, Float, ID, ObjectType, registerEnumType } from '@nestjs/graphql';
import { TherapyType } from '../../../generated/prisma/client';

registerEnumType(TherapyType, { name: 'TherapyType' });

@ObjectType()
export class ChildType {
  @Field(() => ID)
  id: string;

  @Field()
  firstName: string;

  @Field()
  lastName: string;

  @Field()
  dateOfBirth: Date;
}

@ObjectType()
export class TherapistUserType {
  @Field()
  firstName: string;

  @Field()
  lastName: string;

  @Field()
  email: string;
}

@ObjectType()
export class TherapistMatchType {
  @Field(() => ID)
  id: string;

  @Field(() => Float)
  ratingAverage: number;

  @Field(() => Float, { nullable: true })
  matchScore?: number;

  @Field(() => TherapistUserType, { nullable: true })
  user?: TherapistUserType;
}

@ObjectType()
export class AppointmentType {
  @Field(() => ID)
  id: string;

  @Field()
  status: string;

  @Field(() => TherapyType)
  therapyType: TherapyType;

  @Field()
  scheduledStart: Date;

  @Field()
  scheduledEnd: Date;

  @Field(() => ChildType, { nullable: true })
  child?: ChildType;

  @Field(() => TherapistMatchType, { nullable: true })
  therapist?: TherapistMatchType;
}
