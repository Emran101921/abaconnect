import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import {
  computeSessionFeeCents,
  isSelfPayInsuranceType,
} from './self-pay.util';
import { StripeService } from './stripe.service';

@Injectable()
export class PaymentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly stripe: StripeService,
    private readonly notifications: NotificationsService,
  ) {}

  getConfig() {
    return { stripeConfigured: this.stripe.isConfigured() };
  }

  async prepareCheckoutForParentPayment(userId: string, paymentId: string) {
    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (!parent) {
      throw new BadRequestException('Parent profile not found');
    }
    const payment = await this.prisma.payment.findFirst({
      where: { id: paymentId, parentId: parent.id },
    });
    if (!payment) {
      throw new NotFoundException('Payment not found');
    }
    if (payment.status === 'SUCCEEDED') {
      return {
        payment,
        clientSecret: null,
        checkoutUrl: null,
        stripeConfigured: this.stripe.isConfigured(),
      };
    }

    const amountCents = Math.round(Number(payment.amount) * 100);
    let checkoutUrl: string | null = null;
    if (this.stripe.isConfigured()) {
      const appUrl = process.env.APP_URL ?? 'http://localhost:3000';
      const session = await this.stripe.createCheckoutSession(
        amountCents,
        {
          paymentId: payment.id,
          parentId: parent.id,
          description: payment.description ?? 'BloomOra payment',
        },
        `${appUrl}/api/v1/payments/success?paymentId=${payment.id}`,
        `${appUrl}/api/v1/payments/cancel`,
      );
      checkoutUrl = session.url;
    }

    let clientSecret: string | null = null;
    if (payment.stripePaymentIntentId) {
      const intent = await this.stripe.retrievePaymentIntent(
        payment.stripePaymentIntentId,
      );
      if ('client_secret' in intent) {
        clientSecret = intent.client_secret ?? null;
      }
    }

    return {
      payment,
      clientSecret,
      checkoutUrl,
      stripeConfigured: this.stripe.isConfigured(),
    };
  }

  async requestSessionChargeForTherapist(
    therapistUserId: string,
    appointmentId: string,
  ) {
    const therapist = await this.prisma.therapist.findUnique({
      where: { userId: therapistUserId },
    });
    if (!therapist) {
      throw new NotFoundException('Therapist profile not found');
    }

    const appointment = await this.prisma.appointment.findFirst({
      where: { id: appointmentId, therapistId: therapist.id },
      include: {
        child: true,
        parent: { include: { user: true } },
        session: { include: { payment: true } },
      },
    });
    if (!appointment) {
      throw new NotFoundException('Appointment not found');
    }
    if (!isSelfPayInsuranceType(appointment.child.insuranceType)) {
      throw new BadRequestException(
        'Session charges only apply to self-pay families',
      );
    }
    if (!['CHECKED_IN', 'IN_PROGRESS'].includes(appointment.status)) {
      throw new BadRequestException(
        'Record arrival before requesting session payment',
      );
    }

    const hourlyRate = therapist.hourlyRate
      ? Number(therapist.hourlyRate)
      : 120;
    const amountCents = computeSessionFeeCents(
      appointment.scheduledStart,
      appointment.scheduledEnd,
      hourlyRate,
    );
    const childName = `${appointment.child.firstName} ${appointment.child.lastName}`;
    const description = `${appointment.therapyType} session — ${childName}`;

    let session = appointment.session;
    if (!session) {
      session = await this.prisma.session.create({
        data: {
          appointmentId: appointment.id,
          tenantId: appointment.tenantId,
          childId: appointment.childId,
          therapistId: therapist.id,
          status: 'SCHEDULED',
        },
        include: { payment: true },
      });
    }

    if (session.payment?.status === 'SUCCEEDED') {
      return {
        payment: session.payment,
        clientSecret: null,
        checkoutUrl: null,
        stripeConfigured: this.stripe.isConfigured(),
        alreadyPaid: true,
      };
    }

    if (session.payment?.status === 'PENDING') {
      const checkout = await this.prepareCheckoutForParentPayment(
        appointment.parent.userId,
        session.payment.id,
      );
      return { ...checkout, alreadyPaid: false };
    }

    const payment = await this.create({
      parentId: appointment.parentId,
      tenantId: appointment.tenantId,
      sessionId: session.id,
      amountCents,
      description,
    });

    await this.notifications.createForUser(appointment.parent.userId, {
      title: 'Session payment due',
      body: `Your therapist has arrived. Complete payment to begin ${childName}'s session.`,
      data: {
        type: 'SESSION_PAYMENT_DUE',
        paymentId: payment.id,
        appointmentId: appointment.id,
        sessionId: session.id,
      },
    });

    const checkout = await this.prepareCheckoutForParentPayment(
      appointment.parent.userId,
      payment.id,
    );
    return { ...checkout, alreadyPaid: false };
  }

  async findByParentUserId(userId: string) {
    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (!parent) {
      return [];
    }
    return this.prisma.payment.findMany({
      where: { parentId: parent.id },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
  }

  async createForParentUserId(
    userId: string,
    input: {
      amountCents: number;
      description?: string;
      sessionId?: string;
    },
  ) {
    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (!parent) {
      throw new BadRequestException('Parent profile not found');
    }
    if (input.amountCents < 100) {
      throw new BadRequestException('Minimum payment is $1.00');
    }

    const payment = await this.create({
      parentId: parent.id,
      tenantId: parent.tenantId,
      sessionId: input.sessionId,
      amountCents: input.amountCents,
      description: input.description,
    });

    const intent = await this.stripe.createPaymentIntent(input.amountCents, {
      parentId: parent.id,
      paymentId: payment.id,
    });

    let checkoutUrl: string | null = null;
    if (this.stripe.isConfigured()) {
      const appUrl = process.env.APP_URL ?? 'http://localhost:3000';
      const session = await this.stripe.createCheckoutSession(
        input.amountCents,
        {
          paymentId: payment.id,
          parentId: parent.id,
          description: input.description ?? 'BloomOra payment',
        },
        `${appUrl}/api/v1/payments/success?paymentId=${payment.id}`,
        `${appUrl}/api/v1/payments/cancel`,
      );
      checkoutUrl = session.url;
    }

    return {
      payment,
      clientSecret:
        'client_secret' in intent
          ? (intent.client_secret as string | null)
          : null,
      checkoutUrl,
      stripeConfigured: this.stripe.isConfigured(),
    };
  }

  async syncPaymentFromStripe(paymentId: string, userId: string) {
    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (!parent) {
      throw new BadRequestException('Parent profile not found');
    }
    const payment = await this.prisma.payment.findFirst({
      where: { id: paymentId, parentId: parent.id },
    });
    if (!payment) {
      throw new NotFoundException('Payment not found');
    }
    if (!payment.stripePaymentIntentId) {
      return payment;
    }
    const intent = await this.stripe.retrievePaymentIntent(
      payment.stripePaymentIntentId,
    );
    if (intent.status === 'succeeded') {
      return this.prisma.payment.update({
        where: { id: paymentId },
        data: { status: 'SUCCEEDED', paidAt: new Date() },
      });
    }
    return payment;
  }

  async markPaymentSucceeded(paymentId: string, userId: string) {
    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (!parent) {
      throw new BadRequestException('Parent profile not found');
    }
    const payment = await this.prisma.payment.findFirst({
      where: { id: paymentId, parentId: parent.id },
    });
    if (!payment) {
      throw new NotFoundException('Payment not found');
    }
    if (payment.status === 'SUCCEEDED') {
      return payment;
    }
    return this.prisma.payment.update({
      where: { id: paymentId },
      data: { status: 'SUCCEEDED', paidAt: new Date() },
    });
  }

  async create(data: {
    parentId: string;
    sessionId?: string;
    amountCents: number;
    tenantId: string;
    description?: string;
  }) {
    const intent = await this.stripe.createPaymentIntent(data.amountCents, {
      parentId: data.parentId,
      sessionId: data.sessionId ?? '',
    });
    return this.prisma.payment.create({
      data: {
        parentId: data.parentId,
        sessionId: data.sessionId,
        tenantId: data.tenantId,
        amount: data.amountCents / 100,
        description: data.description,
        stripePaymentIntentId: intent.id,
        status: 'PENDING',
      },
    });
  }

  async findAll() {
    return this.prisma.payment.findMany({ orderBy: { createdAt: 'desc' } });
  }

  async findOne(id: string) {
    const payment = await this.prisma.payment.findUnique({ where: { id } });
    if (!payment) {
      throw new NotFoundException('Payment not found');
    }
    return payment;
  }

  async update(id: string, data: Record<string, unknown>) {
    await this.findOne(id);
    return this.prisma.payment.update({
      where: { id },
      data: data as Parameters<typeof this.prisma.payment.update>[0]['data'],
    });
  }

  async remove(id: string) {
    await this.findOne(id);
    await this.prisma.payment.delete({ where: { id } });
    return { id, deleted: true };
  }

  async handleStripeWebhookEvent(event: {
    type: string;
    data: { object: unknown };
  }) {
    const object = (event.data?.object ?? {}) as Record<string, unknown>;
    const metadata = (object.metadata ?? {}) as Record<string, string>;
    const paymentId = metadata.paymentId;

    if (event.type === 'checkout.session.completed') {
      const intentId = object.payment_intent as string | undefined;
      if (paymentId) {
        await this.markPaymentSucceededFromWebhook(paymentId, intentId);
      }
      return;
    }

    if (
      event.type === 'payment_intent.succeeded' ||
      event.type === 'payment_intent.payment_failed'
    ) {
      const intentId = object.id as string | undefined;
      const idFromMeta = paymentId ?? metadata.paymentId;
      if (idFromMeta) {
        if (event.type === 'payment_intent.succeeded') {
          await this.markPaymentSucceededFromWebhook(idFromMeta, intentId);
        } else {
          await this.prisma.payment.updateMany({
            where: { id: idFromMeta },
            data: { status: 'FAILED' },
          });
        }
        return;
      }
      if (intentId) {
        const payment = await this.prisma.payment.findFirst({
          where: { stripePaymentIntentId: intentId },
        });
        if (payment) {
          if (event.type === 'payment_intent.succeeded') {
            await this.markPaymentSucceededFromWebhook(payment.id, intentId);
          } else {
            await this.prisma.payment.update({
              where: { id: payment.id },
              data: { status: 'FAILED' },
            });
          }
        }
      }
    }
  }

  private async markPaymentSucceededFromWebhook(
    paymentId: string,
    stripePaymentIntentId?: string,
  ) {
    const payment = await this.prisma.payment.findUnique({
      where: { id: paymentId },
    });
    if (!payment || payment.status === 'SUCCEEDED') {
      return payment;
    }
    return this.prisma.payment.update({
      where: { id: paymentId },
      data: {
        status: 'SUCCEEDED',
        paidAt: new Date(),
        ...(stripePaymentIntentId ? { stripePaymentIntentId } : {}),
      },
    });
  }
}
