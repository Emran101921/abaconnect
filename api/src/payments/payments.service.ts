import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { StripeService } from './stripe.service';

@Injectable()
export class PaymentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly stripe: StripeService,
  ) {}

  async create(data: {
    parentId: string;
    sessionId?: string;
    amountCents: number;
    tenantId: string;
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
        stripePaymentIntentId: intent.id,
        status: 'PENDING',
      },
    });
  }

  async findAll() {
    return this.prisma.payment.findMany({ orderBy: { createdAt: 'desc' } });
  }

  async findOne(id: string) {
    if (!id) {
      throw new NotFoundException('Resource not found');
    }
    // return this.prisma.payments.findUnique({ where: { id } });
    void this.prisma;
    return { id };
  }

  async update(id: string, data: Record<string, unknown>) {
    // return this.prisma.payments.update({ where: { id }, data });
    void this.prisma;
    return { id, ...data };
  }

  async remove(id: string) {
    // return this.prisma.payments.delete({ where: { id } });
    void this.prisma;
    return { id, deleted: true };
  }
}
