import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class TherapistsService {
  constructor(private readonly prisma: PrismaService) {}

  async getDashboardForUserId(userId: string) {
    const therapist = await this.prisma.therapist.findUnique({
      where: { userId },
    });
    if (!therapist) {
      throw new NotFoundException('Therapist profile not found');
    }

    const start = new Date();
    start.setHours(0, 0, 0, 0);
    const end = new Date(start);
    end.setHours(23, 59, 59, 999);

    const [
      pendingRequests,
      appointmentsToday,
      inProgressSessions,
      pendingDocumentation,
      pendingSessions,
      messageMemberships,
    ] = await Promise.all([
      this.prisma.appointment.count({
        where: { therapistId: therapist.id, status: 'REQUESTED' },
      }),
      this.prisma.appointment.count({
        where: {
          therapistId: therapist.id,
          scheduledStart: { gte: start, lte: end },
          status: { notIn: ['CANCELLED', 'NO_SHOW'] },
        },
      }),
      this.prisma.session.count({
        where: { therapistId: therapist.id, status: 'IN_PROGRESS' },
      }),
      this.prisma.session.count({
        where: {
          therapistId: therapist.id,
          status: 'PENDING_DOCUMENTATION',
        },
      }),
      this.prisma.session.findMany({
        where: {
          therapistId: therapist.id,
          status: 'PENDING_DOCUMENTATION',
        },
        take: 5,
        include: { child: true },
        orderBy: { checkOutAt: 'desc' },
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

    const unreadMessages = messageMemberships.filter((m) => {
      const last = m.thread.messages[0];
      if (!last || last.senderId === userId) return false;
      return !m.lastReadAt || m.lastReadAt < last.sentAt;
    }).length;

    const actionItems = [];
    if (pendingRequests > 0) {
      actionItems.push({
        id: 'pending-requests',
        title: 'Appointment requests',
        subtitle: `${pendingRequests} need confirmation`,
        actionType: 'APPOINTMENT',
        priority: 0,
      });
    }
    for (const session of pendingSessions) {
      actionItems.push({
        id: `soap-${session.id}`,
        title: 'SOAP note due',
        subtitle: session.child
          ? `${session.child.firstName} ${session.child.lastName}`
          : 'Session documentation',
        actionType: 'SOAP_DUE',
        sessionId: session.id,
        priority: 1,
      });
    }
    if (unreadMessages > 0) {
      actionItems.push({
        id: 'messages',
        title: 'Unread messages',
        subtitle: `${unreadMessages} thread(s)`,
        actionType: 'MESSAGE',
        priority: 2,
      });
    }

    return {
      pendingRequests,
      appointmentsToday,
      inProgressSessions,
      pendingDocumentation,
      unreadMessages,
      actionItems,
    };
  }

  async findByUserId(userId: string) {
    const therapist = await this.prisma.therapist.findUnique({
      where: { userId },
      include: { user: true },
    });
    if (!therapist) {
      throw new NotFoundException('Therapist profile not found');
    }
    return therapist;
  }

  async updateByUserId(
    userId: string,
    data: {
      bio?: string;
      npi?: string;
      licenseNumber?: string;
      licenseState?: string;
      yearsExperience?: number;
      therapyTypes?: string[];
    },
  ) {
    const therapist = await this.findByUserId(userId);
    return this.prisma.therapist.update({
      where: { id: therapist.id },
      data: data as Parameters<typeof this.prisma.therapist.update>[0]['data'],
      include: { user: true },
    });
  }

  async findAppointmentsByUserId(userId: string) {
    const therapist = await this.findByUserId(userId);
    return this.prisma.appointment.findMany({
      where: { therapistId: therapist.id },
      include: {
        child: true,
        parent: { include: { user: true } },
      },
      orderBy: { scheduledStart: 'asc' },
    });
  }

  async create(data: Record<string, unknown>) {
    void data;
    throw new BadRequestException('Use registration flow');
  }

  async findAll() {
    return this.prisma.therapist.findMany({
      take: 100,
      include: { user: true },
    });
  }

  async findOne(id: string) {
    const therapist = await this.prisma.therapist.findUnique({
      where: { id },
      include: { user: true },
    });
    if (!therapist) {
      throw new NotFoundException('Therapist not found');
    }
    return therapist;
  }

  async update(id: string, data: Record<string, unknown>) {
    await this.findOne(id);
    return this.prisma.therapist.update({
      where: { id },
      data: data as Parameters<typeof this.prisma.therapist.update>[0]['data'],
      include: { user: true },
    });
  }

  async remove(id: string) {
    await this.findOne(id);
    await this.prisma.therapist.delete({ where: { id } });
    return { id, deleted: true };
  }
}
