import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { LocationType, TherapyType } from '../../generated/prisma/client';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.service';

export interface BookAppointmentInput {
  childId: string;
  therapistId: string;
  therapyType: TherapyType;
  scheduledStart: Date;
  scheduledEnd: Date;
  notes?: string;
  locationType?: LocationType;
}

@Injectable()
export class AppointmentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  async findByParentUserId(userId: string) {
    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (!parent) {
      return [];
    }
    return this.prisma.appointment.findMany({
      where: { parentId: parent.id },
      include: {
        child: true,
        therapist: { include: { user: true } },
      },
      orderBy: { scheduledStart: 'asc' },
    });
  }

  async findUpcomingForParentUser(userId: string) {
    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (!parent) {
      return [];
    }
    return this.prisma.appointment.findMany({
      where: {
        parentId: parent.id,
        scheduledStart: { gte: new Date() },
        status: { notIn: ['CANCELLED', 'COMPLETED', 'NO_SHOW'] },
      },
      include: {
        child: true,
        therapist: { include: { user: true } },
      },
      orderBy: { scheduledStart: 'asc' },
    });
  }

  async buildIcalForParentUser(userId: string): Promise<string> {
    const rows = await this.findUpcomingForParentUser(userId);
    const lines: string[] = [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//ABAConnect//EN',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
    ];

    for (const row of rows) {
      const therapistName = `${row.therapist.user.firstName} ${row.therapist.user.lastName}`;
      const childName = `${row.child.firstName} ${row.child.lastName}`;
      const summary = this.escapeIcalText(
        `${row.therapyType} – ${childName} with ${therapistName}`,
      );
      const description = this.escapeIcalText(
        `Status: ${row.status}. Location: ${row.locationType ?? 'IN_HOME'}.`,
      );
      lines.push('BEGIN:VEVENT');
      lines.push(`UID:${row.id}@abaconnect`);
      lines.push(`DTSTAMP:${this.formatIcalUtc(new Date())}`);
      lines.push(`DTSTART:${this.formatIcalUtc(row.scheduledStart)}`);
      lines.push(`DTEND:${this.formatIcalUtc(row.scheduledEnd)}`);
      lines.push(`SUMMARY:${summary}`);
      lines.push(`DESCRIPTION:${description}`);
      lines.push('END:VEVENT');
    }

    lines.push('END:VCALENDAR');
    return `${lines.join('\r\n')}\r\n`;
  }

  private formatIcalUtc(date: Date): string {
    return date.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '');
  }

  private escapeIcalText(value: string): string {
    return value
      .replace(/\\/g, '\\\\')
      .replace(/;/g, '\\;')
      .replace(/,/g, '\\,')
      .replace(/\n/g, '\\n');
  }

  async bookForParentUser(userId: string, input: BookAppointmentInput) {
    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (!parent) {
      throw new BadRequestException('Parent profile not found');
    }

    const child = await this.prisma.child.findFirst({
      where: { id: input.childId, parentId: parent.id },
    });
    if (!child) {
      throw new NotFoundException('Child not found');
    }

    const therapist = await this.prisma.therapist.findFirst({
      where: { id: input.therapistId, tenantId: parent.tenantId },
    });
    if (!therapist) {
      throw new NotFoundException('Therapist not found');
    }

    if (input.scheduledEnd <= input.scheduledStart) {
      throw new BadRequestException('scheduledEnd must be after scheduledStart');
    }

    const appointment = await this.prisma.appointment.create({
      data: {
        tenantId: parent.tenantId,
        parentId: parent.id,
        childId: child.id,
        therapistId: therapist.id,
        therapyType: input.therapyType,
        scheduledStart: input.scheduledStart,
        scheduledEnd: input.scheduledEnd,
        notes: input.notes,
        locationType: input.locationType ?? 'IN_HOME',
        status: 'REQUESTED',
      },
      include: {
        child: true,
        therapist: { include: { user: true } },
        parent: { include: { user: true } },
      },
    });

    await this.notifyBookingCreated(appointment);
    return appointment;
  }

  async respondForTherapistUserId(
    userId: string,
    appointmentId: string,
    action: 'CONFIRM' | 'DECLINE',
    reason?: string,
  ) {
    const therapist = await this.prisma.therapist.findUnique({
      where: { userId },
      include: { user: true },
    });
    if (!therapist) {
      throw new BadRequestException('Therapist profile not found');
    }

    const appointment = await this.prisma.appointment.findFirst({
      where: { id: appointmentId, therapistId: therapist.id },
      include: {
        child: true,
        parent: { include: { user: true } },
        therapist: { include: { user: true } },
      },
    });
    if (!appointment) {
      throw new NotFoundException('Appointment not found');
    }

    if (!['REQUESTED', 'SCHEDULED'].includes(appointment.status)) {
      throw new BadRequestException(
        `Cannot ${action.toLowerCase()} appointment in status ${appointment.status}`,
      );
    }

    const updated = await this.prisma.appointment.update({
      where: { id: appointmentId },
      data:
        action === 'CONFIRM'
          ? { status: 'CONFIRMED' }
          : {
              status: 'CANCELLED',
              cancelledReason: reason ?? 'Declined by therapist',
            },
      include: {
        child: true,
        parent: { include: { user: true } },
        therapist: { include: { user: true } },
      },
    });

    await this.notifyAppointmentResponse(updated, action);
    return updated;
  }

  private async notifyBookingCreated(appointment: {
    id: string;
    therapyType: string;
    scheduledStart: Date;
    child: { firstName: string; lastName: string };
    therapist: { userId: string; user: { firstName: string; lastName: string } };
    parent: { userId: string };
  }) {
    const childName = `${appointment.child.firstName} ${appointment.child.lastName}`;
    const when = appointment.scheduledStart.toLocaleString();
    await this.notifications.createForUser(appointment.therapist.userId, {
      title: 'New appointment request',
      body: `${childName} requested ${appointment.therapyType} on ${when}`,
      data: { appointmentId: appointment.id, type: 'APPOINTMENT_REQUESTED' },
    });
    await this.notifications.createForUser(appointment.parent.userId, {
      title: 'Booking submitted',
      body: `Your ${appointment.therapyType} request for ${childName} is pending therapist confirmation`,
      data: { appointmentId: appointment.id, type: 'APPOINTMENT_REQUESTED' },
    });
  }

  private async notifyAppointmentResponse(
    appointment: {
      id: string;
      therapyType: string;
      scheduledStart: Date;
      status: string;
      child: { firstName: string; lastName: string };
      parent: { userId: string };
      therapist: { user: { firstName: string; lastName: string } };
    },
    action: 'CONFIRM' | 'DECLINE',
  ) {
    const childName = `${appointment.child.firstName} ${appointment.child.lastName}`;
    const therapistName = `${appointment.therapist.user.firstName} ${appointment.therapist.user.lastName}`;
    const when = appointment.scheduledStart.toLocaleString();

    if (action === 'CONFIRM') {
      await this.notifications.createForUser(appointment.parent.userId, {
        title: 'Appointment confirmed',
        body: `${therapistName} confirmed ${appointment.therapyType} for ${childName} on ${when}`,
        data: { appointmentId: appointment.id, type: 'APPOINTMENT_CONFIRMED' },
      });
    } else {
      await this.notifications.createForUser(appointment.parent.userId, {
        title: 'Appointment declined',
        body: `${therapistName} could not accept ${appointment.therapyType} on ${when}`,
        data: { appointmentId: appointment.id, type: 'APPOINTMENT_DECLINED' },
      });
    }
  }

  async bookRecurringForParentUser(
    userId: string,
    input: BookAppointmentInput,
    weeks: number,
  ) {
    if (weeks < 2 || weeks > 12) {
      throw new BadRequestException('Recurring bookings must be 2–12 weeks');
    }
    const results = [];
    for (let i = 0; i < weeks; i++) {
      const weekMs = 7 * 24 * 60 * 60 * 1000;
      const row = await this.bookForParentUser(userId, {
        ...input,
        scheduledStart: new Date(input.scheduledStart.getTime() + weekMs * i),
        scheduledEnd: new Date(input.scheduledEnd.getTime() + weekMs * i),
        notes:
          i === 0
            ? input.notes
            : `${input.notes ?? 'Recurring session'} (week ${i + 1}/${weeks})`,
      });
      results.push(row);
    }
    return results;
  }

  async rescheduleForParentUser(
    userId: string,
    appointmentId: string,
    scheduledStart: Date,
    scheduledEnd: Date,
  ) {
    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (!parent) {
      throw new BadRequestException('Parent profile not found');
    }

    const appointment = await this.prisma.appointment.findFirst({
      where: { id: appointmentId, parentId: parent.id },
      include: {
        child: true,
        therapist: { include: { user: true } },
        parent: { include: { user: true } },
      },
    });
    if (!appointment) {
      throw new NotFoundException('Appointment not found');
    }

    if (['COMPLETED', 'CANCELLED', 'NO_SHOW'].includes(appointment.status)) {
      throw new BadRequestException('Cannot reschedule this appointment');
    }

    if (scheduledEnd <= scheduledStart) {
      throw new BadRequestException('scheduledEnd must be after scheduledStart');
    }

    const updated = await this.prisma.appointment.update({
      where: { id: appointmentId },
      data: {
        scheduledStart,
        scheduledEnd,
        status: 'RESCHEDULED',
      },
      include: {
        child: true,
        therapist: { include: { user: true } },
        parent: { include: { user: true } },
      },
    });

    const childName = `${updated.child.firstName} ${updated.child.lastName}`;
    const when = scheduledStart.toLocaleString();
    await this.notifications.createForUser(updated.therapist.userId, {
      title: 'Appointment rescheduled',
      body: `${childName} moved ${updated.therapyType} to ${when}`,
      data: { appointmentId: updated.id, type: 'APPOINTMENT_RESCHEDULED' },
    });
    await this.notifications.createForUser(updated.parent.userId, {
      title: 'Appointment updated',
      body: `Your ${updated.therapyType} session for ${childName} is now ${when}`,
      data: { appointmentId: updated.id, type: 'APPOINTMENT_RESCHEDULED' },
    });

    return updated;
  }

  async cancelForTherapistUser(
    userId: string,
    appointmentId: string,
    reason?: string,
  ) {
    const therapist = await this.prisma.therapist.findUnique({ where: { userId } });
    if (!therapist) {
      throw new BadRequestException('Therapist profile required');
    }

    const appointment = await this.prisma.appointment.findFirst({
      where: { id: appointmentId, therapistId: therapist.id },
      include: {
        child: true,
        therapist: { include: { user: true } },
        parent: { include: { user: true } },
      },
    });
    if (!appointment) {
      throw new NotFoundException('Appointment not found');
    }

    if (['COMPLETED', 'CANCELLED', 'NO_SHOW'].includes(appointment.status)) {
      throw new BadRequestException('Cannot cancel this appointment');
    }

    const updated = await this.prisma.appointment.update({
      where: { id: appointmentId },
      data: {
        status: 'CANCELLED',
        cancelledReason: reason ?? 'Cancelled by therapist',
      },
      include: {
        child: true,
        therapist: { include: { user: true } },
        parent: { include: { user: true } },
      },
    });

    const childName = `${updated.child.firstName} ${updated.child.lastName}`;
    const when = updated.scheduledStart.toLocaleString();
    const therapistName = `${updated.therapist.user.firstName} ${updated.therapist.user.lastName}`;
    const cancelReason = reason ?? 'Cancelled by therapist';
    await this.notifications.createForUser(updated.parent.userId, {
      title: 'Appointment cancelled',
      body: `${therapistName} cancelled ${updated.therapyType} for ${childName} on ${when}`,
      data: { appointmentId: updated.id, type: 'APPOINTMENT_CANCELLED' },
    });
    await this.notifications.createForUser(updated.therapist.userId, {
      title: 'Appointment cancelled',
      body: `You cancelled ${updated.therapyType} for ${childName} on ${when}`,
      data: { appointmentId: updated.id, type: 'APPOINTMENT_CANCELLED' },
    });

    return updated;
  }

  async cancelForParentUser(userId: string, appointmentId: string, reason?: string) {
    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (!parent) {
      throw new BadRequestException('Parent profile not found');
    }

    const appointment = await this.prisma.appointment.findFirst({
      where: { id: appointmentId, parentId: parent.id },
      include: {
        child: true,
        therapist: { include: { user: true } },
        parent: { include: { user: true } },
      },
    });
    if (!appointment) {
      throw new NotFoundException('Appointment not found');
    }

    if (['COMPLETED', 'CANCELLED', 'NO_SHOW'].includes(appointment.status)) {
      throw new BadRequestException('Cannot cancel this appointment');
    }

    const updated = await this.prisma.appointment.update({
      where: { id: appointmentId },
      data: {
        status: 'CANCELLED',
        cancelledReason: reason ?? 'Cancelled by parent',
      },
      include: {
        child: true,
        therapist: { include: { user: true } },
        parent: { include: { user: true } },
      },
    });

    const childName = `${updated.child.firstName} ${updated.child.lastName}`;
    const when = updated.scheduledStart.toLocaleString();
    const cancelReason = reason ?? 'Cancelled by parent';
    await this.notifications.createForUser(updated.therapist.userId, {
      title: 'Appointment cancelled',
      body: `${childName} cancelled ${updated.therapyType} on ${when}: ${cancelReason}`,
      data: { appointmentId: updated.id, type: 'APPOINTMENT_CANCELLED' },
    });
    await this.notifications.createForUser(updated.parent.userId, {
      title: 'Appointment cancelled',
      body: `Your ${updated.therapyType} session for ${childName} on ${when} was cancelled`,
      data: { appointmentId: updated.id, type: 'APPOINTMENT_CANCELLED' },
    });

    return updated;
  }

  async create(data: Record<string, unknown>) {
    void data;
    throw new BadRequestException('Use GraphQL bookAppointment or bookForParentUser');
  }

  async findAll() {
    return this.prisma.appointment.findMany({
      take: 100,
      orderBy: { scheduledStart: 'desc' },
      include: { child: true, therapist: { include: { user: true } } },
    });
  }

  async findOne(id: string) {
    const appointment = await this.prisma.appointment.findUnique({
      where: { id },
      include: { child: true, therapist: { include: { user: true } } },
    });
    if (!appointment) {
      throw new NotFoundException('Appointment not found');
    }
    return appointment;
  }

  async update(id: string, data: Record<string, unknown>) {
    await this.findOne(id);
    return this.prisma.appointment.update({
      where: { id },
      data: data as Parameters<typeof this.prisma.appointment.update>[0]['data'],
      include: { child: true, therapist: { include: { user: true } } },
    });
  }

  async remove(id: string) {
    await this.findOne(id);
    await this.prisma.appointment.delete({ where: { id } });
    return { id, deleted: true };
  }
}
