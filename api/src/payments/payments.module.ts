import { Module, forwardRef } from '@nestjs/common';
import { NotificationsModule } from '../notifications/notifications.module';
import { AppointmentsModule } from '../appointments/appointments.module';
import { PaymentsController } from './payments.controller';
import { PaymentsService } from './payments.service';
import { StripeWebhooksController } from './stripe-webhooks.controller';
import { StripeService } from './stripe.service';

@Module({
  imports: [NotificationsModule, forwardRef(() => AppointmentsModule)],
  controllers: [PaymentsController, StripeWebhooksController],
  providers: [PaymentsService, StripeService],
  exports: [PaymentsService, StripeService],
})
export class PaymentsModule {}
