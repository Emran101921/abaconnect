import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ParentsService {
  constructor(private readonly prisma: PrismaService) {}

  async create(data: {
    userId: string;
    tenantId: string;
    addressLine1?: string;
    city?: string;
    state?: string;
    zipCode?: string;
  }) {
    return this.prisma.parent.create({
      data,
      include: { user: true, children: true },
    });
  }

  async findAll(tenantId?: string) {
    return this.prisma.parent.findMany({
      where: tenantId ? { tenantId } : undefined,
      include: { user: true, children: true },
    });
  }

  async findOne(id: string) {
    const parent = await this.prisma.parent.findUnique({
      where: { id },
      include: { user: true, children: true },
    });
    if (!parent) {
      throw new NotFoundException('Parent not found');
    }
    return parent;
  }

  async update(id: string, data: Record<string, unknown>) {
    await this.findOne(id);
    return this.prisma.parent.update({
      where: { id },
      data: data as Parameters<typeof this.prisma.parent.update>[0]['data'],
    });
  }

  async remove(id: string) {
    await this.findOne(id);
    await this.prisma.parent.delete({ where: { id } });
    return { id, deleted: true };
  }
}
