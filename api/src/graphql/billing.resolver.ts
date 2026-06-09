import { Args, ID, Mutation, Query, Resolver } from '@nestjs/graphql';
import { Roles } from '../common/decorators/roles.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { DisputesService } from '../disputes/disputes.service';
import { PayoutsService } from '../payouts/payouts.service';
import { PaymentsService } from '../payments/payments.service';
import { OpenPaymentDisputeInput } from './inputs/messaging-payments.input';
import { DisputeType, PayoutType } from './types/payments.types';
import { PaymentType } from './types/payments.types';

@Resolver()
export class BillingResolver {
  constructor(
    private readonly payments: PaymentsService,
    private readonly disputes: DisputesService,
    private readonly payouts: PayoutsService,
  ) {}

  @Mutation(() => DisputeType, { name: 'openPaymentDispute' })
  @Roles('PARENT')
  async openPaymentDispute(
    @CurrentUser() user: AuthUser,
    @Args('input') input: OpenPaymentDisputeInput,
  ): Promise<DisputeType> {
    const d = await this.disputes.openForParentUser(user.id, input);
    return {
      id: d.id,
      status: d.status,
      reason: d.reason,
      paymentId: d.paymentId ?? undefined,
    };
  }

  @Query(() => [DisputeType], { name: 'myPaymentDisputes' })
  @Roles('PARENT')
  async myPaymentDisputes(
    @CurrentUser() user: AuthUser,
  ): Promise<DisputeType[]> {
    const rows = await this.disputes.listForParentUser(user.id);
    return rows.map((d) => ({
      id: d.id,
      status: d.status,
      reason: d.reason,
      paymentId: d.paymentId ?? undefined,
      resolution: d.resolution ?? undefined,
    }));
  }

  @Mutation(() => PaymentType, { name: 'syncPaymentStatus' })
  @Roles('PARENT')
  async syncPaymentStatus(
    @CurrentUser() user: AuthUser,
    @Args('paymentId', { type: () => ID }) paymentId: string,
  ): Promise<PaymentType> {
    const p = await this.payments.syncPaymentFromStripe(paymentId, user.id);
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

  @Query(() => [PayoutType], { name: 'myTherapistPayouts' })
  @Roles('THERAPIST')
  async myTherapistPayouts(
    @CurrentUser() user: AuthUser,
  ): Promise<PayoutType[]> {
    const rows = await this.payouts.listForTherapistUser(user.id);
    return rows.map((p) => this.mapPayout(p));
  }

  @Query(() => [DisputeType], { name: 'adminDisputes' })
  @Roles('PLATFORM_ADMIN')
  async adminDisputes(@CurrentUser() user: AuthUser): Promise<DisputeType[]> {
    const rows = await this.disputes.listForTenant(user.tenantId ?? '', 'OPEN');
    return rows.map((d) => ({
      id: d.id,
      status: d.status,
      reason: d.reason,
      paymentId: d.paymentId ?? undefined,
      resolution: d.resolution ?? undefined,
    }));
  }

  @Mutation(() => DisputeType, { name: 'resolvePaymentDispute' })
  @Roles('PLATFORM_ADMIN')
  async resolvePaymentDispute(
    @CurrentUser() user: AuthUser,
    @Args('disputeId', { type: () => ID }) disputeId: string,
    @Args('resolution') resolution: string,
  ): Promise<DisputeType> {
    const d = await this.disputes.resolve(
      user.tenantId!,
      disputeId,
      resolution,
    );
    return {
      id: d.id,
      status: d.status,
      reason: d.reason,
      paymentId: d.paymentId ?? undefined,
      resolution: d.resolution ?? undefined,
    };
  }

  @Query(() => [PayoutType], { name: 'adminPayouts' })
  @Roles('PLATFORM_ADMIN')
  async adminPayouts(@CurrentUser() user: AuthUser): Promise<PayoutType[]> {
    const rows = await this.payouts.listForTenant(user.tenantId ?? '');
    return rows.map((p) => this.mapPayout(p));
  }

  @Mutation(() => PayoutType, { name: 'markPayoutPaid' })
  @Roles('PLATFORM_ADMIN')
  async markPayoutPaid(
    @CurrentUser() user: AuthUser,
    @Args('payoutId', { type: () => ID }) payoutId: string,
  ): Promise<PayoutType> {
    const p = await this.payouts.markPaid(user.tenantId ?? '', payoutId);
    return this.mapPayout(p);
  }

  private mapPayout(p: {
    id: string;
    amount: unknown;
    status: string;
    periodStart: Date;
    periodEnd: Date;
    paidAt: Date | null;
  }): PayoutType {
    return {
      id: p.id,
      amount: Number(p.amount),
      status: p.status,
      periodStart: p.periodStart,
      periodEnd: p.periodEnd,
      paidAt: p.paidAt ?? undefined,
    };
  }
}
