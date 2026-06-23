import { Field, Float, ID, Int, ObjectType } from '@nestjs/graphql';
import {
  AppointmentConfirmationStatus,
  LocationType,
  TherapyType,
} from '../../../generated/prisma/client';
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
export class ProviderOnboardingChecklistType {
  @Field()
  identityComplete: boolean;

  @Field()
  licenseComplete: boolean;

  @Field()
  npiComplete: boolean;

  @Field()
  taxIdComplete: boolean;

  @Field()
  backgroundCheckComplete: boolean;

  @Field()
  hipaaTrainingComplete: boolean;

  @Field()
  confidentialityAgreementComplete: boolean;

  @Field()
  agencyApprovalComplete: boolean;

  @Field()
  isActive: boolean;

  @Field()
  phiAccessApproved: boolean;

  @Field()
  onboardingStatus: string;
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
export class TherapistCaseloadChartType {
  @Field(() => ID)
  childId: string;

  @Field()
  chartNumber: string;

  @Field()
  firstName: string;

  @Field()
  lastName: string;

  @Field()
  dateOfBirth: Date;

  @Field({ nullable: true })
  gender?: string;

  @Field({ nullable: true })
  primaryLanguage?: string;

  @Field({ nullable: true })
  guardianName?: string;

  @Field({ nullable: true })
  pediatricianName?: string;

  @Field({ nullable: true })
  insuranceType?: string;

  @Field()
  parentName: string;

  @Field(() => [TherapyType])
  therapyTypes: TherapyType[];

  @Field(() => Int)
  upcomingAppointments: number;

  @Field(() => Int)
  completedSessions: number;

  @Field(() => Int)
  pendingDocumentation: number;

  @Field({ nullable: true })
  lastVisitAt?: Date;
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

  @Field(() => AppointmentConfirmationStatus)
  confirmationStatus: AppointmentConfirmationStatus;

  @Field({ nullable: true })
  parentConfirmedAt?: Date;

  @Field({ nullable: true })
  therapistConfirmedAt?: Date;

  @Field({ nullable: true })
  rescheduleRequestedBy?: string;

  @Field({ nullable: true })
  proposedScheduledStart?: Date;

  @Field({ nullable: true })
  proposedScheduledEnd?: Date;

  @Field({ nullable: true })
  rescheduleReason?: string;

  @Field(() => ChildType)
  child: ChildType;

  @Field({ nullable: true })
  childInsuranceType?: string;

  @Field()
  requiresSelfPayCollection: boolean;

  @Field()
  hasArrived: boolean;

  @Field()
  canStartSession: boolean;

  @Field({ nullable: true })
  sessionPaymentId?: string;

  @Field({ nullable: true })
  sessionPaymentStatus?: string;

  @Field(() => Float, { nullable: true })
  sessionPaymentAmount?: number;

  @Field(() => ID, { nullable: true })
  parentUserId?: string;

  @Field({ nullable: true })
  parentName?: string;
}

@ObjectType()
export class ServiceLogType {
  @Field(() => ID)
  id: string;

  @Field({ nullable: true })
  therapistSignatureName?: string;

  @Field({ nullable: true })
  therapistSignedAt?: string;

  @Field({ nullable: true })
  parentSignatureName?: string;

  @Field({ nullable: true })
  parentSignatureDate?: string;

  @Field({ nullable: true })
  parentSignedAt?: string;

  @Field()
  childName: string;
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

  @Field()
  eipFormFullySigned: boolean;

  @Field(() => ServiceLogType, { nullable: true })
  serviceLog?: ServiceLogType;
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
  licenseNumber?: string;

  @Field({ nullable: true })
  licenseState?: string;

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

  @Field()
  isFullySigned: boolean;
}

@ObjectType()
export class StaffSessionNoteSummaryType {
  @Field(() => ID)
  sessionId: string;

  @Field()
  childName: string;

  @Field()
  therapistName: string;

  @Field({ nullable: true })
  sessionDate?: string;

  @Field()
  isFullySigned: boolean;

  @Field()
  hasServiceLog: boolean;
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

  @Field(() => ServiceLogType, { nullable: true })
  serviceLog?: ServiceLogType;
}
