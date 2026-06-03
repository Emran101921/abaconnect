import { Field, ID, InputType, Int } from '@nestjs/graphql';

@InputType()
export class SendMessageInput {
  @Field(() => ID)
  threadId: string;

  @Field()
  body: string;
}

@InputType()
export class OpenPaymentDisputeInput {
  @Field(() => ID)
  paymentId: string;

  @Field()
  reason: string;
}

@InputType()
export class CreatePaymentInput {
  @Field(() => Int)
  amountCents: number;

  @Field({ nullable: true })
  description?: string;

  @Field(() => ID, { nullable: true })
  sessionId?: string;
}
