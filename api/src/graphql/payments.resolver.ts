import { ForbiddenException } from '@nestjs/common';
import { Args, ID, Mutation, Query, Resolver } from '@nestjs/graphql';
import { Roles } from '../common/decorators/roles.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { PaymentsService } from '../payments/payments.service';
import { CreatePaymentInput } from './inputs/messaging-payments.input';
import { PaymentIntentResultType, PaymentType } from './types/payments.types';

@Resolver()
@Roles('PARENT')
export class PaymentsResolver {
  constructor(private readonly paymentsService: PaymentsService) {}

  @Query(() => [PaymentType], { name: 'myPayments' })
  async myPayments(@CurrentUser() user: AuthUser): Promise<PaymentType[]> {
    const rows = await this.paymentsService.findByParentUserId(user.id);
    return rows.map((p) => this.mapPayment(p));
  }

  @Mutation(() => PaymentIntentResultType, { name: 'createPayment' })
  async createPayment(
    @CurrentUser() user: AuthUser,
    @Args('input') input: CreatePaymentInput,
  ): Promise<PaymentIntentResultType> {
    const result = await this.paymentsService.createForParentUserId(
      user.id,
      input,
    );
    return {
      payment: this.mapPayment(result.payment),
      clientSecret: result.clientSecret ?? undefined,
      checkoutUrl: result.checkoutUrl ?? undefined,
      stripeConfigured: result.stripeConfigured,
    };
  }

  @Mutation(() => PaymentIntentResultType, { name: 'prepareSessionPayment' })
  async prepareSessionPayment(
    @CurrentUser() user: AuthUser,
    @Args('paymentId', { type: () => ID }) paymentId: string,
  ): Promise<PaymentIntentResultType> {
    const result = await this.paymentsService.prepareCheckoutForParentPayment(
      user.id,
      paymentId,
    );
    return {
      payment: this.mapPayment(result.payment),
      clientSecret: result.clientSecret ?? undefined,
      checkoutUrl: result.checkoutUrl ?? undefined,
      stripeConfigured: result.stripeConfigured,
    };
  }

  @Mutation(() => PaymentType, { name: 'confirmPaymentDemo' })
  async confirmPaymentDemo(
    @CurrentUser() user: AuthUser,
    @Args('paymentId', { type: () => ID }) paymentId: string,
  ): Promise<PaymentType> {
    if (process.env.NODE_ENV === 'production') {
      throw new ForbiddenException('Demo payment confirmation is disabled');
    }
    const p = await this.paymentsService.markPaymentSucceeded(
      paymentId,
      user.id,
    );
    return this.mapPayment(p);
  }

  private mapPayment(p: {
    id: string;
    amount: unknown;
    currency: string;
    status: PaymentType['status'];
    description: string | null;
    paidAt: Date | null;
    createdAt: Date;
  }): PaymentType {
    return {
      id: p.id,
      amount: Number(p.amount),
      currency: p.currency,
      status: p.status,
      description: p.description ?? undefined,
      paidAt: p.paidAt ?? undefined,
      createdAt: p.createdAt,
    };
  }
}
