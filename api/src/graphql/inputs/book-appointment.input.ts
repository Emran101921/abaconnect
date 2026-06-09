import { Field, ID, InputType, Int } from '@nestjs/graphql';
import { IsInt, IsOptional, IsUUID, Min } from 'class-validator';
import { LocationType, TherapyType } from '../../../generated/prisma/client';

@InputType()
export class BookAppointmentInput {
  @Field(() => ID)
  @IsUUID()
  childId: string;

  @Field(() => ID)
  @IsUUID()
  therapistId: string;

  @Field(() => TherapyType)
  therapyType: TherapyType;

  @Field()
  scheduledStart: Date;

  @Field()
  scheduledEnd: Date;

  @Field({ nullable: true })
  notes?: string;

  @Field(() => LocationType, { nullable: true })
  locationType?: LocationType;
}

@InputType()
export class BookRecurringAppointmentsInput extends BookAppointmentInput {
  @Field(() => Int)
  @IsInt()
  @Min(1)
  weeks: number;
}

@InputType()
export class RescheduleAppointmentInput {
  @Field(() => ID)
  @IsUUID()
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

  @Field(() => [TherapyType], { nullable: true })
  therapyTypes?: TherapyType[];

  @Field({ nullable: true })
  @IsOptional()
  latitude?: number;

  @Field({ nullable: true })
  @IsOptional()
  longitude?: number;
}
