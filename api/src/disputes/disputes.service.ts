import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class DisputesService {
  constructor(private readonly prisma: PrismaService) {}

  async openForParentUser(
    userId: string,
    data: { paymentId: string; reason: string },
  ) {
    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (!parent) {
      throw new BadRequestException('Parent profile not found');
    }

    const payment = await this.prisma.payment.findFirst({
      where: { id: data.paymentId, parentId: parent.id },
    });
    if (!payment) {
      throw new NotFoundException('Payment not found');
    }

    const existing = await this.prisma.dispute.findFirst({
      where: { paymentId: payment.id, status: 'OPEN' },
    });
    if (existing) {
      throw new BadRequestException(
        'A dispute is already open for this payment',
      );
    }

    return this.prisma.dispute.create({
      data: {
        tenantId: parent.tenantId,
        paymentId: payment.id,
        parentId: parent.id,
        openerId: userId,
        reason: data.reason,
        amount: payment.amount,
        status: 'OPEN',
      },
    });
  }

  async listForTenant(tenantId: string, status?: string) {
    return this.prisma.dispute.findMany({
      where: {
        tenantId,
        ...(status ? { status: status as never } : {}),
      },
      include: {
        opener: true,
        payment: true,
      },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
  }

  async listForParentUser(userId: string) {
    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (!parent) return [];
    return this.prisma.dispute.findMany({
      where: { parentId: parent.id },
      include: { payment: true },
      orderBy: { createdAt: 'desc' },
      take: 20,
    });
  }

  async resolve(tenantId: string, disputeId: string, resolution: string) {
    const row = await this.prisma.dispute.findFirst({
      where: { id: disputeId, tenantId },
    });
    if (!row) throw new NotFoundException('Dispute not found');
    return this.prisma.dispute.update({
      where: { id: disputeId },
      data: {
        status: 'RESOLVED',
        resolution,
        resolvedAt: new Date(),
      },
      include: { opener: true, payment: true },
    });
  }

  async create(data: Record<string, unknown>) {
    void data;
    return { id: 'dispute' };
  }

  async findAll() {
    return this.prisma.dispute.findMany({ take: 20 });
  }

  async findOne(id: string) {
    const row = await this.prisma.dispute.findUnique({ where: { id } });
    if (!row) throw new NotFoundException('Dispute not found');
    return row;
  }

  async update(id: string, data: Record<string, unknown>) {
    await this.findOne(id);
    return this.prisma.dispute.update({
      where: { id },
      data: data as Parameters<typeof this.prisma.dispute.update>[0]['data'],
    });
  }

  async remove(id: string) {
    await this.findOne(id);
    await this.prisma.dispute.delete({ where: { id } });
    return { id, deleted: true };
  }
}
