import { Field, Float, ID, Int, ObjectType } from '@nestjs/graphql';
import { TherapyType } from '../../../generated/prisma/client';
import { ChildType, TherapistUserType } from './parent-booking.types';

@ObjectType()
export class TherapistDashboardType {
  @Field(() => Int)
  pendingRequests: number;

  @Field(() => Int)
  appointmentsToday: number;

  @Field(() => Int)
  inProgressSessions: number;

  @Field(() => Int)
  pendingDocumentation: number;
}

@ObjectType()
export class TherapistProfileType {
  @Field(() => ID)
  id: string;

  @Field()
  isVerified: boolean;

  @Field(() => [TherapyType])
  therapyTypes: TherapyType[];

  @Field({ nullable: true })
  bio?: string;

  @Field({ nullable: true })
  licenseNumber?: string;

  @Field({ nullable: true })
  licenseState?: string;

  @Field(() => Int, { nullable: true })
  yearsExperience?: number;

  @Field(() => Float)
  ratingAverage: number;

  @Field(() => Int)
  ratingCount: number;

  @Field(() => TherapistUserType)
  user: TherapistUserType;
}

@ObjectType()
export class TherapistAppointmentType {
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

  @Field(() => ChildType)
  child: ChildType;
}

@ObjectType()
export class SoapNoteType {
  @Field(() => ID)
  id: string;

  @Field({ nullable: true })
  subjective?: string;

  @Field({ nullable: true })
  objective?: string;

  @Field({ nullable: true })
  assessment?: string;

  @Field({ nullable: true })
  plan?: string;
}

@ObjectType()
export class TherapistSessionType {
  @Field(() => ID)
  id: string;

  @Field()
  status: string;

  @Field(() => ChildType)
  child: ChildType;

  @Field(() => SoapNoteType, { nullable: true })
  soapNote?: SoapNoteType;
}
