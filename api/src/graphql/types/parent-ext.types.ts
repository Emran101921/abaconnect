import { Field, ID, Int, ObjectType } from '@nestjs/graphql';
import { TherapyType } from '../../../generated/prisma/client';
import { TherapistUserType } from './parent-booking.types';

@ObjectType()
export class ParentDashboardType {
  @Field(() => Int)
  childrenCount: number;

  @Field(() => Int)
  upcomingAppointments: number;

  @Field(() => Int)
  appointmentsToday: number;

  @Field(() => Int)
  pendingReviews: number;
}

@ObjectType()
export class ParentProfileType {
  @Field(() => ID)
  id: string;

  @Field({ nullable: true })
  addressLine1?: string;

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

  @Field()
  email: string;

  @Field()
  firstName: string;

  @Field()
  lastName: string;
}

@ObjectType()
export class SessionHistoryType {
  @Field(() => ID)
  id: string;

  @Field()
  status: string;

  @Field()
  childName: string;

  @Field()
  therapistName: string;

  @Field(() => TherapyType)
  therapyType: TherapyType;

  @Field({ nullable: true })
  completedAt?: Date;

  @Field(() => Int, { nullable: true })
  durationMinutes?: number;
}

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
