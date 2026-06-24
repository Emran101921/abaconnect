import {
  Field,
  Float,
  ID,
  ObjectType,
  registerEnumType,
} from '@nestjs/graphql';
import { LocationType, TherapyType, AppointmentConfirmationStatus } from '../../../generated/prisma/client';

registerEnumType(TherapyType, { name: 'TherapyType' });
registerEnumType(LocationType, { name: 'LocationType' });
registerEnumType(AppointmentConfirmationStatus, {
  name: 'AppointmentConfirmationStatus',
});

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

  @Field({ nullable: true })
  gender?: string;

  @Field({ nullable: true })
  primaryLanguage?: string;

  @Field({ nullable: true })
  guardianName?: string;

  @Field({ nullable: true })
  guardianPhone?: string;

  @Field({ nullable: true })
  guardianEmail?: string;

  @Field({ nullable: true })
  addressLine1?: string;

  @Field({ nullable: true })
  zipCode?: string;

  @Field({ nullable: true })
  pediatricianName?: string;

  @Field({ nullable: true })
  insuranceType?: string;

  @Field({ nullable: true })
  hadEarlyIntervention?: boolean;
}

@ObjectType()
export class TherapistUserType {
  @Field(() => ID, { nullable: true })
  id?: string;

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

  @Field(() => ChildType, { nullable: true })
  child?: ChildType;

  @Field(() => TherapistMatchType, { nullable: true })
  therapist?: TherapistMatchType;

  @Field({ nullable: true })
  childInsuranceType?: string;

  @Field()
  requiresSelfPayBookingPayment: boolean;

  @Field(() => ID, { nullable: true })
  bookingPaymentId?: string;

  @Field({ nullable: true })
  bookingPaymentStatus?: string;
}

@ObjectType()
export class ConfirmAppointmentResultType {
  @Field(() => AppointmentType)
  appointment: AppointmentType;

  @Field()
  requiresPayment: boolean;

  @Field({ nullable: true })
  checkoutUrl?: string;

  @Field({ nullable: true })
  clientSecret?: string;

  @Field()
  stripeConfigured: boolean;

  @Field(() => ID, { nullable: true })
  paymentId?: string;
}
