import { Field, Float, ID, ObjectType, registerEnumType } from '@nestjs/graphql';
import { PaymentStatus } from '../../../generated/prisma/client';

registerEnumType(PaymentStatus, { name: 'PaymentStatus' });

@ObjectType()
export class PaymentType {
  @Field(() => ID)
  id: string;

  @Field(() => Float)
  amount: number;

  @Field()
  currency: string;

  @Field(() => PaymentStatus)
  status: PaymentStatus;

  @Field({ nullable: true })
  description?: string;

  @Field({ nullable: true })
  paidAt?: Date;

  @Field()
  createdAt: Date;
}

@ObjectType()
export class PaymentIntentResultType {
  @Field(() => PaymentType)
  payment: PaymentType;

  @Field({ nullable: true })
  clientSecret?: string;

  @Field()
  stripeConfigured: boolean;
}
