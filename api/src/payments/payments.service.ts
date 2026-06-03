import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { StripeService } from './stripe.service';

@Injectable()
export class PaymentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly stripe: StripeService,
  ) {}

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

    return {
      payment,
      clientSecret:
        'client_secret' in intent
          ? (intent.client_secret as string | null)
          : null,
      stripeConfigured: this.stripe.isConfigured(),
    };
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
}
