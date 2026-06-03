import { Field, ID, InputType } from '@nestjs/graphql';
import { TherapyType } from '../../../generated/prisma/client';

@InputType()
export class BookAppointmentInput {
  @Field(() => ID)
  childId: string;

  @Field(() => ID)
  therapistId: string;

  @Field(() => TherapyType)
  therapyType: TherapyType;

  @Field()
  scheduledStart: Date;

  @Field()
  scheduledEnd: Date;

  @Field({ nullable: true })
  notes?: string;
}

@InputType()
export class BookRecurringAppointmentsInput extends BookAppointmentInput {
  @Field()
  weeks: number;
}

@InputType()
export class RescheduleAppointmentInput {
  @Field(() => ID)
  appointmentId: string;

  @Field()
  scheduledStart: Date;

  @Field()
  scheduledEnd: Date;
}

@InputType()
export class TherapistDiscoveryInput {
  @Field(() => TherapyType, { nullable: true })
  therapyType?: TherapyType;

  @Field({ nullable: true })
  latitude?: number;

  @Field({ nullable: true })
  longitude?: number;
}
