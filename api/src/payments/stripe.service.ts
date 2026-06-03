import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Stripe from 'stripe';

@Injectable()
export class StripeService {
  // Stripe constructor instance (SDK types export as value + namespace)
  private stripe: InstanceType<typeof Stripe> | null = null;

  constructor(private config: ConfigService) {
    const key = this.config.get<string>('STRIPE_SECRET_KEY');
    if (key?.startsWith('sk_')) {
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

  async createCheckoutSession(
    amountCents: number,
    metadata: Record<string, string>,
    successUrl: string,
    cancelUrl: string,
  ) {
    if (!this.stripe) {
      return { url: null, id: `cs_stub_${Date.now()}` };
    }
    const session = await this.stripe.checkout.sessions.create({
      mode: 'payment',
      success_url: successUrl,
      cancel_url: cancelUrl,
      line_items: [
        {
          quantity: 1,
          price_data: {
            currency: 'usd',
            unit_amount: amountCents,
            product_data: {
              name: metadata.description ?? 'ABAConnect session payment',
            },
          },
        },
      ],
      metadata,
    });
    return { url: session.url, id: session.id };
  }

  async createTransfer(amountCents: number, metadata: Record<string, string>) {
    if (!this.stripe) {
      return { id: `tr_stub_${Date.now()}` };
    }
    const dest = metadata.destinationAccountId;
    if (!dest?.startsWith('acct_')) {
      return { id: `tr_stub_${Date.now()}` };
    }
    return this.stripe.transfers.create({
      amount: amountCents,
      currency: 'usd',
      destination: dest,
      metadata,
    });
  }

  async retrievePaymentIntent(paymentIntentId: string) {
    if (!this.stripe) {
      return { status: 'succeeded' };
    }
    return this.stripe.paymentIntents.retrieve(paymentIntentId);
  }

  constructWebhookEvent(payload: Buffer, signature: string, secret: string) {
    if (!this.stripe) {
      return { type: 'stub', data: { object: {} } };
    }
    return this.stripe.webhooks.constructEvent(payload, signature, secret);
  }
}
