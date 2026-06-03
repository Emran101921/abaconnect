import { Module } from '@nestjs/common';
import { PaymentsController } from './payments.controller';
import { PaymentsService } from './payments.service';
import { StripeWebhooksController } from './stripe-webhooks.controller';
import { StripeService } from './stripe.service';

@Module({
  controllers: [PaymentsController, StripeWebhooksController],
  providers: [PaymentsService, StripeService],
  exports: [PaymentsService, StripeService],
})
export class PaymentsModule {}
