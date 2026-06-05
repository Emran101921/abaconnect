import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ParentsService {
  constructor(private readonly prisma: PrismaService) {}

  async getDashboardForUserId(userId: string) {
    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (!parent) {
      throw new NotFoundException('Parent profile not found');
    }

    const start = new Date();
    start.setHours(0, 0, 0, 0);
    const end = new Date(start);
    end.setHours(23, 59, 59, 999);

    const [childrenCount, upcomingAppointments, appointmentsToday] =
      await Promise.all([
        this.prisma.child.count({ where: { parentId: parent.id } }),
        this.prisma.appointment.count({
          where: {
            parentId: parent.id,
            scheduledStart: { gte: new Date() },
            status: { notIn: ['CANCELLED', 'COMPLETED', 'NO_SHOW'] },
          },
        }),
        this.prisma.appointment.count({
          where: {
            parentId: parent.id,
            scheduledStart: { gte: start, lte: end },
            status: { notIn: ['CANCELLED', 'NO_SHOW'] },
          },
        }),
      ]);

    return {
      childrenCount,
      upcomingAppointments,
      appointmentsToday,
    };
  }

  async findProfileByUserId(userId: string) {
    const parent = await this.prisma.parent.findUnique({
      where: { userId },
      include: { user: true },
    });
    if (!parent) {
      throw new NotFoundException('Parent profile not found');
    }
    return parent;
  }

  async updateProfileByUserId(
    userId: string,
    data: {
      addressLine1?: string;
      addressLine2?: string;
      city?: string;
      state?: string;
      zipCode?: string;
      emergencyContactName?: string;
      emergencyContactPhone?: string;
      insuranceProvider?: string;
      insuranceMemberId?: string;
      insuranceGroupNumber?: string;
    },
  ) {
    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (!parent) {
      throw new BadRequestException('Parent profile not found');
    }
    return this.prisma.parent.update({
      where: { id: parent.id },
      data,
      include: { user: true },
    });
  }

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
