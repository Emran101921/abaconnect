import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class AdminService {
  constructor(private readonly prisma: PrismaService) {}

  async getDashboard(tenantId?: string) {
    const where = tenantId ? { tenantId } : {};
    const [
      userCount,
      parentCount,
      therapistCount,
      appointmentCount,
      pendingTherapists,
      openComplaints,
      recentAuditLogs,
    ] = await Promise.all([
      this.prisma.user.count({ where }),
      this.prisma.parent.count({ where }),
      this.prisma.therapist.count({ where }),
      this.prisma.appointment.count({ where }),
      this.prisma.therapist.count({
        where: { ...where, phiAccessApproved: false },
      }),
      this.prisma.complaint.count({
        where: { ...where, status: 'OPEN' },
      }),
      this.prisma.auditLog.findMany({
        where: tenantId ? { tenantId } : undefined,
        orderBy: { createdAt: 'desc' },
        take: 10,
        include: { actor: true },
      }),
    ]);

    return {
      userCount,
      parentCount,
      therapistCount,
      appointmentCount,
      pendingTherapists,
      openComplaints,
      recentAuditLogs,
    };
  }

  async listUsers(tenantId?: string, take = 50) {
    return this.prisma.user.findMany({
      where: tenantId ? { tenantId } : undefined,
      take,
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        email: true,
        firstName: true,
        lastName: true,
        role: true,
        isActive: true,
        lastLoginAt: true,
        createdAt: true,
      },
    });
  }

  async listPendingTherapists(tenantId?: string) {
    return this.prisma.therapist.findMany({
      where: {
        ...(tenantId ? { tenantId } : {}),
        phiAccessApproved: false,
      },
      include: { user: true },
      orderBy: { updatedAt: 'desc' },
      take: 50,
    });
  }

  async setUserActive(userId: string, isActive: boolean, tenantId?: string) {
    const user = await this.prisma.user.findFirst({
      where: {
        id: userId,
        ...(tenantId ? { tenantId } : {}),
      },
    });
    if (!user) {
      throw new NotFoundException('User not found');
    }
    if (user.role === 'PLATFORM_ADMIN' && !isActive) {
      throw new BadRequestException('Cannot deactivate platform admin');
    }
    return this.prisma.user.update({
      where: { id: userId },
      data: { isActive },
      select: {
        id: true,
        email: true,
        firstName: true,
        lastName: true,
        role: true,
        isActive: true,
      },
    });
  }

  async verifyTherapist(therapistId: string, tenantId?: string) {
    const therapist = await this.prisma.therapist.findFirst({
      where: {
        id: therapistId,
        ...(tenantId ? { tenantId } : {}),
      },
    });
    if (!therapist) {
      throw new NotFoundException('Therapist not found');
    }
    return this.prisma.therapist.update({
      where: { id: therapistId },
      data: { isVerified: true },
      include: { user: true },
    });
  }

  async create(data: Record<string, unknown>) {
    void data;
    return { id: 'stub' };
  }

  async findAll() {
    return this.getDashboard();
  }

  async findOne(id: string) {
    void id;
    return this.getDashboard();
  }

  async update(id: string, data: Record<string, unknown>) {
    void id;
    void data;
    return { updated: true };
  }

  async remove(id: string) {
    void id;
    return { deleted: true };
  }
}
