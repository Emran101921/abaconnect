import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { StripeService } from '../payments/stripe.service';

@Injectable()
export class PayoutsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly stripe: StripeService,
  ) {}

  async listForTherapistUser(userId: string) {
    const therapist = await this.prisma.therapist.findUnique({
      where: { userId },
    });
    if (!therapist) return [];
    return this.prisma.payout.findMany({
      where: { therapistId: therapist.id },
      orderBy: { createdAt: 'desc' },
      take: 30,
    });
  }

  async listForTenant(tenantId: string) {
    return this.prisma.payout.findMany({
      where: { tenantId },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
  }

  async createForTherapist(
    tenantId: string,
    data: {
      therapistId: string;
      amount: number;
      periodStart: Date;
      periodEnd: Date;
    },
  ) {
    const therapist = await this.prisma.therapist.findFirst({
      where: { id: data.therapistId, tenantId },
    });
    if (!therapist) {
      throw new NotFoundException('Therapist not found');
    }

    const transfer = await this.stripe.createTransfer(
      Math.round(data.amount * 100),
      { therapistId: therapist.id },
    );

    return this.prisma.payout.create({
      data: {
        tenantId,
        therapistId: therapist.id,
        amount: data.amount,
        periodStart: data.periodStart,
        periodEnd: data.periodEnd,
        status: 'PENDING',
        stripeTransferId: transfer.id,
      },
    });
  }

  async markPaid(payoutId: string) {
    const row = await this.prisma.payout.findUnique({
      where: { id: payoutId },
    });
    if (!row) throw new NotFoundException('Payout not found');
    return this.prisma.payout.update({
      where: { id: payoutId },
      data: { status: 'SUCCEEDED', paidAt: new Date() },
    });
  }

  async create(data: Record<string, unknown>) {
    void data;
    return { id: 'payout' };
  }

  async findAll() {
    return this.prisma.payout.findMany({ take: 20 });
  }

  async findOne(id: string) {
    const row = await this.prisma.payout.findUnique({ where: { id } });
    if (!row) throw new NotFoundException('Payout not found');
    return row;
  }

  async update(id: string, data: Record<string, unknown>) {
    await this.findOne(id);
    return this.prisma.payout.update({
      where: { id },
      data: data as Parameters<typeof this.prisma.payout.update>[0]['data'],
    });
  }

  async remove(id: string) {
    await this.findOne(id);
    await this.prisma.payout.delete({ where: { id } });
    return { id, deleted: true };
  }
}
