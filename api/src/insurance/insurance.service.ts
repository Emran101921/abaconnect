import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class InsuranceService {
  constructor(private readonly prisma: PrismaService) {}

  async listClaimsForParentUser(userId: string) {
    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (!parent) return [];
    return this.prisma.insuranceClaim.findMany({
      where: { parentId: parent.id },
      include: { child: true },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
  }

  async submitClaim(
    userId: string,
    data: {
      childId: string;
      payerName: string;
      billedAmount: number;
      serviceDate: Date;
    },
  ) {
    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (!parent) throw new BadRequestException('Parent profile not found');

    const child = await this.prisma.child.findFirst({
      where: { id: data.childId, parentId: parent.id },
    });
    if (!child) throw new NotFoundException('Child not found');

    return this.prisma.insuranceClaim.create({
      data: {
        tenantId: parent.tenantId,
        parentId: parent.id,
        childId: child.id,
        payerName: data.payerName,
        billedAmount: data.billedAmount,
        serviceDate: data.serviceDate,
        status: 'SUBMITTED',
        submittedAt: new Date(),
      },
      include: { child: true },
    });
  }

  async create(data: Record<string, unknown>) {
    void data;
    throw new BadRequestException('Use GraphQL submitInsuranceClaim');
  }

  async findAll() {
    return this.prisma.insuranceClaim.findMany({ take: 20 });
  }

  async findOne(id: string) {
    const row = await this.prisma.insuranceClaim.findUnique({ where: { id } });
    if (!row) throw new NotFoundException('Claim not found');
    return row;
  }

  async update(id: string, data: Record<string, unknown>) {
    await this.findOne(id);
    return this.prisma.insuranceClaim.update({
      where: { id },
      data: data as Parameters<typeof this.prisma.insuranceClaim.update>[0]['data'],
    });
  }

  async remove(id: string) {
    await this.findOne(id);
    await this.prisma.insuranceClaim.delete({ where: { id } });
    return { id, deleted: true };
  }
}
