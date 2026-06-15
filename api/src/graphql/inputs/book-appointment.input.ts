import { Field, ID, InputType, Int } from '@nestjs/graphql';
import { Type } from 'class-transformer';
import {
  IsDate,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Min,
} from 'class-validator';
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
  @IsIn(Object.values(TherapyType))
  therapyType: TherapyType;

  @Field()
  @Type(() => Date)
  @IsDate()
  scheduledStart: Date;

  @Field()
  @Type(() => Date)
  @IsDate()
  scheduledEnd: Date;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  notes?: string;

  @Field(() => LocationType, { nullable: true })
  @IsOptional()
  @IsIn(Object.values(LocationType))
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
  @Type(() => Date)
  @IsDate()
  scheduledStart: Date;

  @Field()
  @Type(() => Date)
  @IsDate()
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
