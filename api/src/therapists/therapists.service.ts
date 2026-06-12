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

  async findCaseloadChartsByUserId(userId: string) {
    const therapist = await this.findByUserId(userId);
    const now = new Date();

    const [appointments, sessions] = await Promise.all([
      this.prisma.appointment.findMany({
        where: {
          therapistId: therapist.id,
          status: { notIn: ['CANCELLED', 'NO_SHOW'] },
        },
        include: {
          child: { include: { parent: { include: { user: true } } } },
        },
        orderBy: { scheduledStart: 'desc' },
      }),
      this.prisma.session.findMany({
        where: { therapistId: therapist.id },
        orderBy: { checkOutAt: 'desc' },
      }),
    ]);

    const byChild = new Map<
      string,
      {
        child: (typeof appointments)[0]['child'];
        parentName: string;
        therapyTypes: Set<string>;
        upcomingAppointments: number;
        completedSessions: number;
        pendingDocumentation: number;
        lastVisitAt?: Date;
      }
    >();

    for (const row of appointments) {
      const key = row.childId;
      const parentName = `${row.child.parent.user.firstName} ${row.child.parent.user.lastName}`;
      const existing = byChild.get(key);
      if (existing) {
        existing.therapyTypes.add(row.therapyType);
        if (
          row.scheduledStart >= now &&
          !['COMPLETED', 'CANCELLED', 'NO_SHOW'].includes(row.status)
        ) {
          existing.upcomingAppointments += 1;
        }
      } else {
        byChild.set(key, {
          child: row.child,
          parentName,
          therapyTypes: new Set([row.therapyType]),
          upcomingAppointments:
            row.scheduledStart >= now &&
            !['COMPLETED', 'CANCELLED', 'NO_SHOW'].includes(row.status)
              ? 1
              : 0,
          completedSessions: 0,
          pendingDocumentation: 0,
          lastVisitAt: undefined,
        });
      }
    }

    for (const session of sessions) {
      const key = session.childId;
      const existing = byChild.get(key);
      if (!existing) continue;
      if (session.status === 'COMPLETED') {
        existing.completedSessions += 1;
        const visitAt = session.checkOutAt ?? session.checkInAt;
        if (
          visitAt &&
          (!existing.lastVisitAt || visitAt > existing.lastVisitAt)
        ) {
          existing.lastVisitAt = visitAt;
        }
      }
      if (session.status === 'PENDING_DOCUMENTATION') {
        existing.pendingDocumentation += 1;
      }
    }

    return [...byChild.values()]
      .map((entry) => {
        const c = entry.child;
        return {
          childId: c.id,
          chartNumber: `CH-${c.id.replace(/-/g, '').slice(-8).toUpperCase()}`,
          firstName: c.firstName,
          lastName: c.lastName,
          dateOfBirth: c.dateOfBirth,
          gender: c.gender ?? undefined,
          primaryLanguage: c.primaryLanguage ?? undefined,
          guardianName: c.guardianName ?? undefined,
          pediatricianName: c.pediatricianName ?? undefined,
          insuranceType: c.insuranceType ?? undefined,
          parentName: entry.parentName,
          therapyTypes: [...entry.therapyTypes],
          upcomingAppointments: entry.upcomingAppointments,
          completedSessions: entry.completedSessions,
          pendingDocumentation: entry.pendingDocumentation,
          lastVisitAt: entry.lastVisitAt,
        };
      })
      .sort((a, b) =>
        `${a.lastName} ${a.firstName}`.localeCompare(
          `${b.lastName} ${b.firstName}`,
        ),
      );
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
