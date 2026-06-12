import { Field, ID, InputType, Int } from '@nestjs/graphql';
import {
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

@InputType()
export class SendMessageInput {
  @Field(() => ID)
  @IsUUID()
  threadId: string;

  @Field()
  @IsString()
  @MinLength(1)
  @MaxLength(8000)
  body: string;
}

@InputType()
export class OpenPaymentDisputeInput {
  @Field(() => ID)
  @IsUUID()
  paymentId: string;

  @Field()
  @IsString()
  @MinLength(1)
  @MaxLength(2000)
  reason: string;
}

@InputType()
export class CreatePaymentInput {
  @Field(() => Int)
  @IsInt()
  @Min(1)
  amountCents: number;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  description?: string;

  @Field(() => ID, { nullable: true })
  @IsOptional()
  @IsUUID()
  sessionId?: string;
}
