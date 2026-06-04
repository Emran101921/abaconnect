import { Field, Int, ObjectType, registerEnumType } from '@nestjs/graphql';
import {
  AppointmentStatus,
  LocationType,
  TherapyType,
} from '../../../generated/prisma/client';
import { TherapistUserType } from './parent-booking.types';

registerEnumType(AppointmentStatus, { name: 'AppointmentStatus' });

@ObjectType()
export class AgencyDashboardType {
  @Field(() => Int)
  therapistCount: number;

  @Field(() => Int)
  activeClients: number;

  @Field(() => Int)
  appointmentsToday: number;

  @Field(() => Int)
  pendingTherapists: number;
}

@ObjectType()
export class AgencyAppointmentType {
  @Field()
  id: string;

  @Field()
  scheduledStart: Date;

  @Field()
  scheduledEnd: Date;

  @Field(() => TherapyType)
  therapyType: TherapyType;

  @Field(() => AppointmentStatus)
  status: AppointmentStatus;

  @Field(() => LocationType)
  locationType: LocationType;

  @Field()
  childName: string;

  @Field()
  therapistName: string;
}

@ObjectType()
export class AgencyTherapistType {
  @Field()
  id: string;

  @Field()
  isVerified: boolean;

  @Field({ nullable: true })
  licenseNumber?: string;

  @Field(() => TherapistUserType, { nullable: true })
  user?: TherapistUserType;
}
