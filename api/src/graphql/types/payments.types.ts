import {
  Field,
  Float,
  ID,
  ObjectType,
  registerEnumType,
} from '@nestjs/graphql';
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
export class PaymentsConfigType {
  @Field()
  stripeConfigured: boolean;
}

@ObjectType()
export class PaymentIntentResultType {
  @Field(() => PaymentType)
  payment: PaymentType;

  @Field({ nullable: true })
  clientSecret?: string;

  @Field({ nullable: true })
  checkoutUrl?: string;

  @Field()
  stripeConfigured: boolean;

  @Field({ nullable: true })
  alreadyPaid?: boolean;
}

@ObjectType()
export class DisputeType {
  @Field(() => ID)
  id: string;

  @Field()
  status: string;

  @Field()
  reason: string;

  @Field({ nullable: true })
  paymentId?: string;

  @Field({ nullable: true })
  resolution?: string;
}

@ObjectType()
export class PayoutType {
  @Field(() => ID)
  id: string;

  @Field(() => Float)
  amount: number;

  @Field()
  status: string;

  @Field()
  periodStart: Date;

  @Field()
  periodEnd: Date;

  @Field({ nullable: true })
  paidAt?: Date;
}
