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

    const [
      childrenCount,
      upcomingAppointments,
      appointmentsToday,
      openClaimsCount,
      completedSessions,
      reviewedTherapistIds,
      nextTelehealth,
      lastProgress,
      messageMemberships,
    ] = await Promise.all([
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
      this.prisma.insuranceClaim.count({
        where: {
          parentId: parent.id,
          status: { in: ['DRAFT', 'SUBMITTED', 'PENDING', 'UNDER_REVIEW'] },
        },
      }),
      this.prisma.session.findMany({
        where: {
          status: 'COMPLETED',
          child: { parentId: parent.id },
        },
        orderBy: { checkOutAt: 'desc' },
        take: 10,
        include: {
          child: true,
          therapist: { include: { user: true } },
        },
      }),
      this.prisma.review.findMany({
        where: { parentId: parent.id },
        select: { therapistId: true },
      }),
      this.prisma.appointment.findFirst({
        where: {
          parentId: parent.id,
          locationType: 'TELEHEALTH',
          scheduledStart: { gte: new Date() },
          status: { in: ['CONFIRMED', 'REQUESTED'] },
        },
        orderBy: { scheduledStart: 'asc' },
      }),
      this.prisma.progressNote.findFirst({
        where: {
          session: { child: { parentId: parent.id } },
        },
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.messageParticipant.findMany({
        where: { userId },
        include: {
          thread: {
            include: {
              messages: {
                where: { deletedAt: null },
                orderBy: { sentAt: 'desc' },
                take: 1,
              },
            },
          },
        },
      }),
    ]);

    const reviewed = new Set(reviewedTherapistIds.map((r) => r.therapistId));
    const unreadMessages = messageMemberships.filter((m) => {
      const last = m.thread.messages[0];
      if (!last || last.senderId === userId) return false;
      return !m.lastReadAt || m.lastReadAt < last.sentAt;
    }).length;

    const actionItems = [];
    if (unreadMessages > 0) {
      actionItems.push({
        id: 'messages',
        title: 'Unread messages',
        subtitle: `${unreadMessages} thread(s) need a reply`,
        actionType: 'MESSAGE',
        priority: 1,
      });
    }
    const seenTherapists = new Set<string>();
    for (const session of completedSessions) {
      const t = session.therapist;
      if (!t || reviewed.has(t.id) || seenTherapists.has(t.id)) continue;
      seenTherapists.add(t.id);
      actionItems.push({
        id: `review-${session.id}`,
        title: 'Leave a session review',
        subtitle: `${session.child.firstName} with ${t.user.firstName}`,
        actionType: 'REVIEW',
        sessionId: session.id,
        priority: 2,
      });
      if (actionItems.filter((a) => a.actionType === 'REVIEW').length >= 2)
        break;
    }
    if (openClaimsCount > 0) {
      actionItems.push({
        id: 'claims',
        title: 'Insurance claims in progress',
        subtitle: `${openClaimsCount} open claim(s)`,
        actionType: 'CLAIM',
        priority: 3,
      });
    }
    if (nextTelehealth) {
      actionItems.push({
        id: `telehealth-${nextTelehealth.id}`,
        title: 'Upcoming telehealth visit',
        subtitle: nextTelehealth.scheduledStart.toISOString(),
        actionType: 'TELEHEALTH',
        appointmentId: nextTelehealth.id,
        priority: 0,
      });
    }

    return {
      childrenCount,
      upcomingAppointments,
      appointmentsToday,
      openClaimsCount,
      lastSessionSummary: lastProgress?.summary ?? undefined,
      nextTelehealthAppointmentId: nextTelehealth?.id,
      actionItems,
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
