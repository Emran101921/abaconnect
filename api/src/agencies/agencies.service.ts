import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class AgenciesService {
  constructor(private readonly prisma: PrismaService) {}

  async getDashboardForTenant(tenantId: string) {
    const start = new Date();
    start.setHours(0, 0, 0, 0);
    const end = new Date(start);
    end.setHours(23, 59, 59, 999);
    const evvSince = new Date();
    evvSince.setDate(evvSince.getDate() - 14);

    const [
      therapistCount,
      activeClients,
      appointmentsToday,
      pendingTherapists,
      missingEvvCount,
      draftClaimsCount,
      cancellationsToday,
      pendingTherapistRows,
      draftClaims,
    ] = await Promise.all([
      this.prisma.therapist.count({ where: { tenantId } }),
      this.prisma.child.count({ where: { tenantId } }),
      this.prisma.appointment.count({
        where: {
          tenantId,
          scheduledStart: { gte: start, lte: end },
        },
      }),
      this.prisma.therapist.count({
        where: { tenantId, isVerified: false },
      }),
      this.prisma.session.count({
        where: {
          tenantId,
          status: 'COMPLETED',
          evvVerified: false,
          checkOutAt: { gte: evvSince },
        },
      }),
      this.prisma.insuranceClaim.count({
        where: { tenantId, status: 'DRAFT' },
      }),
      this.prisma.appointment.count({
        where: {
          tenantId,
          status: 'CANCELLED',
          updatedAt: { gte: start, lte: end },
        },
      }),
      this.prisma.therapist.findMany({
        where: { tenantId, isVerified: false },
        take: 3,
        include: { user: true },
      }),
      this.prisma.insuranceClaim.findMany({
        where: { tenantId, status: 'DRAFT' },
        take: 3,
        include: { child: true },
      }),
    ]);

    const actionItems = [];
    if (pendingTherapists > 0) {
      actionItems.push({
        id: 'pending-therapists',
        title: 'Therapists awaiting verification',
        subtitle: `${pendingTherapists} pending`,
        actionType: 'VERIFICATION',
        priority: 0,
      });
    }
    if (missingEvvCount > 0) {
      actionItems.push({
        id: 'missing-evv',
        title: 'Sessions missing EVV',
        subtitle: `${missingEvvCount} in last 14 days`,
        actionType: 'EVV',
        priority: 1,
      });
    }
    for (const claim of draftClaims) {
      actionItems.push({
        id: `claim-${claim.id}`,
        title: 'Draft insurance claim',
        subtitle: claim.child
          ? `${claim.child.firstName} ${claim.child.lastName}`
          : claim.payerName,
        actionType: 'CLAIM',
        claimId: claim.id,
        priority: 2,
      });
    }
    for (const t of pendingTherapistRows) {
      actionItems.push({
        id: `therapist-${t.id}`,
        title: 'Verify therapist',
        subtitle: `${t.user.firstName} ${t.user.lastName}`,
        actionType: 'VERIFICATION',
        priority: 3,
      });
    }

    return {
      therapistCount,
      activeClients,
      appointmentsToday,
      pendingTherapists,
      missingEvvCount,
      draftClaimsCount,
      cancellationsToday,
      actionItems,
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

  async inviteTherapistForTenant(tenantId: string, therapistId: string) {
    const agency = await this.prisma.agency.findFirst({
      where: { tenantId },
      orderBy: { createdAt: 'asc' },
    });
    if (!agency) {
      throw new NotFoundException('Agency not found for tenant');
    }

    const therapist = await this.prisma.therapist.findFirst({
      where: { id: therapistId, tenantId },
      include: { user: true },
    });
    if (!therapist) {
      throw new NotFoundException('Therapist not found');
    }

    return this.prisma.agencyTherapist.upsert({
      where: {
        agencyId_therapistId: {
          agencyId: agency.id,
          therapistId: therapist.id,
        },
      },
      update: { status: 'ACTIVE', joinedAt: new Date() },
      create: {
        agencyId: agency.id,
        therapistId: therapist.id,
        status: 'ACTIVE',
        joinedAt: new Date(),
      },
      include: { therapist: { include: { user: true } }, agency: true },
    });
  }

  async removeTherapistFromAgency(tenantId: string, therapistId: string) {
    const agency = await this.prisma.agency.findFirst({
      where: { tenantId },
    });
    if (!agency) {
      throw new NotFoundException('Agency not found for tenant');
    }

    const link = await this.prisma.agencyTherapist.findUnique({
      where: {
        agencyId_therapistId: {
          agencyId: agency.id,
          therapistId,
        },
      },
      include: { therapist: { include: { user: true } } },
    });
    if (!link) {
      throw new NotFoundException('Therapist is not on this agency roster');
    }

    await this.prisma.agencyTherapist.update({
      where: { id: link.id },
      data: { status: 'INACTIVE' },
    });

    return link.therapist;
  }

  async listUpcomingAppointmentsForTenant(tenantId: string, days = 14) {
    const start = new Date();
    start.setHours(0, 0, 0, 0);
    const end = new Date(start);
    end.setDate(end.getDate() + days);

    return this.prisma.appointment.findMany({
      where: {
        tenantId,
        scheduledStart: { gte: start, lte: end },
        status: { notIn: ['CANCELLED', 'NO_SHOW'] },
      },
      include: {
        child: true,
        therapist: { include: { user: true } },
      },
      orderBy: { scheduledStart: 'asc' },
      take: 100,
    });
  }

  async listUnlinkedTherapistsForTenant(tenantId: string) {
    const agency = await this.prisma.agency.findFirst({
      where: { tenantId },
    });
    if (!agency) {
      return [];
    }
    const linked = await this.prisma.agencyTherapist.findMany({
      where: { agencyId: agency.id },
      select: { therapistId: true },
    });
    const linkedIds = linked.map((l) => l.therapistId);
    return this.prisma.therapist.findMany({
      where: {
        tenantId,
        id: linkedIds.length ? { notIn: linkedIds } : undefined,
      },
      include: { user: true },
      take: 50,
      orderBy: { createdAt: 'desc' },
    });
  }

  async create(data: Record<string, unknown>) {
    const tenantId = data.tenantId as string | undefined;
    const therapistId = data.therapistId as string | undefined;
    if (tenantId && therapistId) {
      const link = await this.inviteTherapistForTenant(tenantId, therapistId);
      return {
        id: link.id,
        agencyId: link.agencyId,
        therapistId: link.therapistId,
      };
    }
    throw new BadRequestException('Provide tenantId and therapistId');
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
