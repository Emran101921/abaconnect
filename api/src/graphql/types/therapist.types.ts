import { Field, Float, ID, Int, ObjectType } from '@nestjs/graphql';
import { LocationType, TherapyType } from '../../../generated/prisma/client';
import { ChildType, TherapistUserType } from './parent-booking.types';
import { DashboardActionItemType } from './dashboard.types';

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

  @Field(() => Int)
  unreadMessages: number;

  @Field(() => [DashboardActionItemType])
  actionItems: DashboardActionItemType[];
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
  npi?: string;

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

  @Field(() => LocationType, { nullable: true })
  locationType?: LocationType;

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

  @Field({ nullable: true })
  eipFormData?: string;
}

@ObjectType()
export class SessionNoteFormContextType {
  @Field(() => ID)
  sessionId: string;

  @Field()
  childName: string;

  @Field({ nullable: true })
  childDob?: string;

  @Field({ nullable: true })
  childSex?: string;

  @Field({ nullable: true })
  eiNumber?: string;

  @Field()
  interventionistName: string;

  @Field({ nullable: true })
  credentials?: string;

  @Field({ nullable: true })
  npi?: string;

  @Field({ nullable: true })
  serviceType?: string;

  @Field({ nullable: true })
  sessionDate?: string;

  @Field({ nullable: true })
  ifspServiceLocation?: string;

  @Field({ nullable: true })
  timeFrom?: string;

  @Field({ nullable: true })
  timeTo?: string;

  @Field({ nullable: true })
  sessionDelivered?: string;

  @Field({ nullable: true })
  icd10Code?: string;

  @Field({ nullable: true })
  existingEipFormData?: string;
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
