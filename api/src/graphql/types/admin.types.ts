import { Field, ID, Int, ObjectType } from '@nestjs/graphql';
import { TherapistUserType } from './parent-booking.types';

@ObjectType()
export class AdminDashboardType {
  @Field(() => Int)
  userCount: number;

  @Field(() => Int)
  parentCount: number;

  @Field(() => Int)
  therapistCount: number;

  @Field(() => Int)
  appointmentCount: number;

  @Field(() => Int)
  pendingTherapists: number;

  @Field(() => Int)
  openComplaints: number;
}

@ObjectType()
export class AdminUserType {
  @Field(() => ID)
  id: string;

  @Field()
  email: string;

  @Field()
  firstName: string;

  @Field()
  lastName: string;

  @Field()
  role: string;

  @Field()
  isActive: boolean;
}

@ObjectType()
export class PendingTherapistType {
  @Field(() => ID)
  id: string;

  @Field()
  isVerified: boolean;

  @Field({ nullable: true })
  licenseNumber?: string;

  @Field({ nullable: true })
  licenseState?: string;

  @Field(() => TherapistUserType)
  user: TherapistUserType;
}

@ObjectType()
export class AdminComplaintType {
  @Field(() => ID)
  id: string;

  @Field()
  status: string;

  @Field()
  category: string;

  @Field()
  subject: string;

  @Field()
  description: string;

  @Field({ nullable: true })
  reporterName?: string;
}

@ObjectType()
export class AuditLogEntryType {
  @Field(() => ID)
  id: string;

  @Field()
  action: string;

  @Field()
  entityType: string;

  @Field()
  createdAt: Date;

  @Field({ nullable: true })
  actorEmail?: string;
}
