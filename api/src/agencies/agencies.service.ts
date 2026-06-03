import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class AgenciesService {
  constructor(private readonly prisma: PrismaService) {}

  async getDashboardForTenant(tenantId: string) {
    const [
      therapistCount,
      activeClients,
      appointmentsToday,
      pendingTherapists,
    ] = await Promise.all([
      this.prisma.therapist.count({ where: { tenantId } }),
      this.prisma.child.count({ where: { tenantId } }),
      this.prisma.appointment.count({
        where: {
          tenantId,
          scheduledStart: {
            gte: new Date(new Date().setHours(0, 0, 0, 0)),
            lt: new Date(new Date().setHours(23, 59, 59, 999)),
          },
        },
      }),
      this.prisma.therapist.count({
        where: { tenantId, isVerified: false },
      }),
    ]);

    return {
      therapistCount,
      activeClients,
      appointmentsToday,
      pendingTherapists,
    };
  }

  async listTherapistsForTenant(tenantId: string) {
    return this.prisma.therapist.findMany({
      where: { tenantId },
      include: { user: true },
      take: 100,
      orderBy: { createdAt: 'desc' },
    });
  }

  async create(data: Record<string, unknown>) {
    void data;
    return { id: 'stub' };
  }

  async findAll() {
    return this.prisma.agency.findMany({ take: 50 });
  }

  async findOne(id: string) {
    const agency = await this.prisma.agency.findUnique({ where: { id } });
    if (!agency) {
      throw new NotFoundException('Agency not found');
    }
    return agency;
  }

  async update(id: string, data: Record<string, unknown>) {
    await this.findOne(id);
    return this.prisma.agency.update({
      where: { id },
      data: data as Parameters<typeof this.prisma.agency.update>[0]['data'],
    });
  }

  async remove(id: string) {
    await this.findOne(id);
    await this.prisma.agency.delete({ where: { id } });
    return { id, deleted: true };
  }
}
