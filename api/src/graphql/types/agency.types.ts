import { Field, Int, ObjectType, registerEnumType } from '@nestjs/graphql';
import {
  AgencyDocumentType,
  AgencyTherapistStatus,
  AppointmentStatus,
  LocationType,
  ProviderOnboardingStatus,
  TherapyType,
} from '../../../generated/prisma/client';
import { TherapistUserType } from './parent-booking.types';
import { DashboardActionItemType } from './dashboard.types';

registerEnumType(AppointmentStatus, { name: 'AppointmentStatus' });
registerEnumType(AgencyDocumentType, { name: 'AgencyDocumentType' });
registerEnumType(AgencyTherapistStatus, { name: 'AgencyTherapistStatus' });
registerEnumType(ProviderOnboardingStatus, {
  name: 'ProviderOnboardingStatus',
});

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

  @Field(() => Int)
  missingEvvCount: number;

  @Field(() => Int)
  draftClaimsCount: number;

  @Field(() => Int)
  cancellationsToday: number;

  @Field(() => [DashboardActionItemType])
  actionItems: DashboardActionItemType[];
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

  @Field(() => AgencyTherapistStatus, { nullable: true })
  rosterStatus?: AgencyTherapistStatus;

  @Field(() => ProviderOnboardingStatus, { nullable: true })
  onboardingStatus?: ProviderOnboardingStatus;

  @Field(() => TherapistUserType, { nullable: true })
  user?: TherapistUserType;
}

@ObjectType()
export class AgencyDocumentRecordType {
  @Field()
  id: string;

  @Field(() => AgencyDocumentType)
  type: AgencyDocumentType;

  @Field()
  title: string;

  @Field()
  fileName: string;

  @Field()
  mimeType: string;

  @Field()
  uploadedAt: Date;
}

@ObjectType()
export class AgencyProfileType {
  @Field()
  id: string;

  @Field()
  name: string;

  @Field({ nullable: true })
  ein?: string;

  @Field({ nullable: true })
  phone?: string;

  @Field({ nullable: true })
  addressLine1?: string;

  @Field({ nullable: true })
  addressLine2?: string;

  @Field({ nullable: true })
  city?: string;

  @Field({ nullable: true })
  state?: string;

  @Field({ nullable: true })
  zipCode?: string;

  @Field({ nullable: true })
  email?: string;

  @Field({ nullable: true })
  website?: string;

  @Field()
  onboardingComplete: boolean;

  @Field(() => [AgencyDocumentRecordType])
  documents: AgencyDocumentRecordType[];
}

@ObjectType()
export class AgencyOnboardingStatusType {
  @Field()
  profileComplete: boolean;

  @Field()
  documentsComplete: boolean;

  @Field()
  onboardingComplete: boolean;

  @Field(() => [AgencyDocumentType])
  missingDocuments: AgencyDocumentType[];

  @Field()
  canComplete: boolean;

  @Field(() => [AgencyDocumentType])
  uploadedDocumentTypes: AgencyDocumentType[];
}

@ObjectType()
export class AgencyStaffMemberType {
  @Field()
  id: string;

  @Field()
  email: string;

  @Field()
  firstName: string;

  @Field()
  lastName: string;

  @Field({ nullable: true })
  therapistId?: string;

  @Field(() => AgencyTherapistStatus, { nullable: true })
  rosterStatus?: AgencyTherapistStatus;

  @Field(() => ProviderOnboardingStatus, { nullable: true })
  onboardingStatus?: ProviderOnboardingStatus;
}
