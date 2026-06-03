import {
  BadRequestException,
  Controller,
  Headers,
  Post,
  RawBodyRequest,
  Req,
} from '@nestjs/common';
import { Request } from 'express';
import { Public } from '../common/decorators/public.decorator';
import { PaymentsService } from './payments.service';
import { StripeService } from './stripe.service';

@Controller('webhooks')
export class StripeWebhooksController {
  constructor(
    private readonly paymentsService: PaymentsService,
    private readonly stripeService: StripeService,
  ) {}

  @Public()
  @Post('stripe')
  async handleStripe(
    @Req() req: RawBodyRequest<Request>,
    @Headers('stripe-signature') signature?: string,
  ) {
    const secret = process.env.STRIPE_WEBHOOK_SECRET;
    if (!secret) {
      return { received: true, processed: false, reason: 'webhook_secret_not_set' };
    }
    if (!signature) {
      throw new BadRequestException('Missing stripe-signature header');
    }
    const raw = req.rawBody;
    if (!raw) {
      throw new BadRequestException('Raw body required for Stripe webhooks');
    }

    const event = this.stripeService.constructWebhookEvent(
      Buffer.isBuffer(raw) ? raw : Buffer.from(raw),
      signature,
      secret,
    );

    await this.paymentsService.handleStripeWebhookEvent(event);
    return { received: true, type: event.type };
  }
}
