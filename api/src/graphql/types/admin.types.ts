import { Field, Float, ID, Int, ObjectType } from '@nestjs/graphql';
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

  @Field({ nullable: true })
  onboardingStatus?: string;

  @Field({ nullable: true })
  phiAccessApproved?: boolean;

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
export class AdminReviewType {
  @Field(() => ID)
  id: string;

  @Field(() => Int)
  rating: number;

  @Field({ nullable: true })
  title?: string;

  @Field({ nullable: true })
  comment?: string;

  @Field()
  isPublished: boolean;

  @Field()
  createdAt: Date;

  @Field({ nullable: true })
  therapistName?: string;

  @Field({ nullable: true })
  authorEmail?: string;
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

@ObjectType()
export class AdminInsuranceClaimType {
  @Field(() => ID)
  id: string;

  @Field()
  status: string;

  @Field()
  payerName: string;

  @Field(() => Float)
  billedAmount: number;

  @Field(() => Float, { nullable: true })
  approvedAmount?: number;

  @Field()
  serviceDate: Date;

  @Field({ nullable: true })
  childName?: string;

  @Field({ nullable: true })
  parentEmail?: string;

  @Field({ nullable: true })
  denialReason?: string;

  @Field({ nullable: true })
  claimNumber?: string;

  @Field({ nullable: true })
  sessionId?: string;

  @Field({ nullable: true })
  ediReady?: boolean;

  @Field({ nullable: true })
  clearinghouseStatus?: string;

  @Field({ nullable: true })
  lockedAt?: Date;

  @Field({ nullable: true })
  resubmissionOfId?: string;
}
