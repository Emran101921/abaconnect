import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { TherapyType } from '../../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';

export interface BookAppointmentInput {
  childId: string;
  therapistId: string;
  therapyType: TherapyType;
  scheduledStart: Date;
  scheduledEnd: Date;
  notes?: string;
}

@Injectable()
export class AppointmentsService {
  constructor(private readonly prisma: PrismaService) {}

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

    return this.prisma.appointment.create({
      data: {
        tenantId: parent.tenantId,
        parentId: parent.id,
        childId: child.id,
        therapistId: therapist.id,
        therapyType: input.therapyType,
        scheduledStart: input.scheduledStart,
        scheduledEnd: input.scheduledEnd,
        notes: input.notes,
        status: 'REQUESTED',
      },
      include: {
        child: true,
        therapist: { include: { user: true } },
      },
    });
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

  async cancelForParentUser(userId: string, appointmentId: string, reason?: string) {
    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (!parent) {
      throw new BadRequestException('Parent profile not found');
    }

    const appointment = await this.prisma.appointment.findFirst({
      where: { id: appointmentId, parentId: parent.id },
    });
    if (!appointment) {
      throw new NotFoundException('Appointment not found');
    }

    return this.prisma.appointment.update({
      where: { id: appointmentId },
      data: {
        status: 'CANCELLED',
        cancelledReason: reason ?? 'Cancelled by parent',
      },
      include: {
        child: true,
        therapist: { include: { user: true } },
      },
    });
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
