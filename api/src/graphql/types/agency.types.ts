import { Field, Int, ObjectType } from '@nestjs/graphql';
import { TherapistUserType } from './parent-booking.types';

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
