import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Stripe from 'stripe';

@Injectable()
export class StripeService {
  // Stripe constructor instance (SDK types export as value + namespace)
  private stripe: InstanceType<typeof Stripe> | null = null;

  constructor(private config: ConfigService) {
    const key = this.config.get<string>('STRIPE_SECRET_KEY');
    if (key) {
      this.stripe = new Stripe(key);
    }
  }

  isConfigured(): boolean {
    return this.stripe !== null;
  }

  async createPaymentIntent(
    amountCents: number,
    metadata: Record<string, string>,
  ) {
    if (!this.stripe) {
      return { id: `pi_stub_${Date.now()}`, client_secret: 'stub_secret' };
    }
    return this.stripe.paymentIntents.create({
      amount: amountCents,
      currency: 'usd',
      metadata,
      automatic_payment_methods: { enabled: true },
    });
  }

  async createConnectAccount(email: string) {
    if (!this.stripe) {
      return { id: `acct_stub_${Date.now()}` };
    }
    return this.stripe.accounts.create({
      type: 'express',
      email,
      capabilities: {
        card_payments: { requested: true },
        transfers: { requested: true },
      },
    });
  }
}
