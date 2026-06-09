import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ComplaintsService {
  constructor(private readonly prisma: PrismaService) {}

  async listForTenant(tenantId: string, status?: string) {
    return this.prisma.complaint.findMany({
      where: {
        tenantId,
        ...(status ? { status: status as never } : {}),
      },
      include: {
        reporter: true,
        therapist: { include: { user: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
  }

  async fileComplaint(
    userId: string,
    data: {
      category: string;
      subject: string;
      description: string;
      therapistId?: string;
    },
  ) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');

    const parent = await this.prisma.parent.findUnique({ where: { userId } });

    return this.prisma.complaint.create({
      data: {
        tenantId: user.tenantId,
        reporterId: userId,
        parentId: parent?.id,
        therapistId: data.therapistId,
        category: data.category,
        subject: data.subject,
        description: data.description,
        status: 'OPEN',
      },
      include: { reporter: true },
    });
  }

  async resolveComplaint(
    tenantId: string,
    complaintId: string,
    resolution: string,
  ) {
    const row = await this.prisma.complaint.findFirst({
      where: { id: complaintId, tenantId },
    });
    if (!row) throw new NotFoundException('Complaint not found');
    return this.prisma.complaint.update({
      where: { id: complaintId },
      data: {
        status: 'RESOLVED',
        resolution,
        resolvedAt: new Date(),
      },
      include: { reporter: true },
    });
  }

  async create(data: Record<string, unknown>) {
    void data;
    return { id: 'complaint' };
  }

  async findAll() {
    return this.prisma.complaint.findMany({ take: 20 });
  }

  async findOne(id: string) {
    const row = await this.prisma.complaint.findUnique({ where: { id } });
    if (!row) throw new NotFoundException('Complaint not found');
    return row;
  }

  async update(id: string, data: Record<string, unknown>) {
    await this.findOne(id);
    return this.prisma.complaint.update({
      where: { id },
      data: data as Parameters<typeof this.prisma.complaint.update>[0]['data'],
    });
  }

  async remove(id: string) {
    await this.findOne(id);
    await this.prisma.complaint.delete({ where: { id } });
    return { id, deleted: true };
  }
}
