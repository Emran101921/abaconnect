import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.service';

export interface SaveSoapNoteInput {
  sessionId: string;
  subjective?: string;
  objective?: string;
  assessment?: string;
  plan?: string;
}

@Injectable()
export class SessionsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
  ) {}

  async findHistoryForParentUserId(userId: string) {
    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (!parent) {
      return [];
    }
    return this.prisma.session.findMany({
      where: {
        child: { parentId: parent.id },
        status: { in: ['COMPLETED', 'IN_PROGRESS', 'PENDING_DOCUMENTATION'] },
      },
      include: {
        child: true,
        therapist: { include: { user: true } },
        appointment: true,
      },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
  }

  async findByTherapistUserId(userId: string) {
    const therapist = await this.prisma.therapist.findUnique({
      where: { userId },
    });
    if (!therapist) {
      return [];
    }
    return this.prisma.session.findMany({
      where: { therapistId: therapist.id },
      include: {
        child: true,
        appointment: true,
        soapNote: true,
      },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
  }

  async ensureSessionForAppointment(userId: string, appointmentId: string) {
    const therapist = await this.prisma.therapist.findUnique({
      where: { userId },
    });
    if (!therapist) {
      throw new NotFoundException('Therapist profile not found');
    }

    const appointment = await this.prisma.appointment.findFirst({
      where: { id: appointmentId, therapistId: therapist.id },
    });
    if (!appointment) {
      throw new NotFoundException('Appointment not found');
    }

    const existing = await this.prisma.session.findUnique({
      where: { appointmentId },
      include: { child: true, soapNote: true },
    });
    if (existing) {
      return existing;
    }

    return this.prisma.session.create({
      data: {
        appointmentId: appointment.id,
        tenantId: appointment.tenantId,
        childId: appointment.childId,
        therapistId: therapist.id,
        status: 'IN_PROGRESS',
        checkInAt: new Date(),
      },
      include: { child: true, soapNote: true },
    });
  }

  async completeSessionForTherapist(userId: string, sessionId: string) {
    const therapist = await this.prisma.therapist.findUnique({
      where: { userId },
    });
    if (!therapist) {
      throw new NotFoundException('Therapist profile not found');
    }

    const session = await this.prisma.session.findFirst({
      where: { id: sessionId, therapistId: therapist.id },
      include: {
        appointment: true,
        child: true,
        therapist: { include: { user: true } },
      },
    });
    if (!session) {
      throw new NotFoundException('Session not found');
    }

    const now = new Date();
    const durationMinutes = session.checkInAt
      ? Math.max(
          1,
          Math.round((now.getTime() - session.checkInAt.getTime()) / 60000),
        )
      : 60;

    const updated = await this.prisma.session.update({
      where: { id: sessionId },
      data: {
        status: 'COMPLETED',
        checkOutAt: now,
        durationMinutes,
        evvVerified: true,
      },
      include: {
        child: true,
        appointment: { include: { parent: { include: { user: true } } } },
      },
    });

    await this.prisma.appointment.update({
      where: { id: session.appointmentId },
      data: { status: 'COMPLETED' },
    });

    const parentUserId = updated.appointment?.parent?.userId;
    if (parentUserId) {
      const childName = `${updated.child.firstName} ${updated.child.lastName}`;
      await this.notifications.createForUser(parentUserId, {
        title: 'Session completed',
        body: `Please rate your ${updated.appointment?.therapyType ?? 'therapy'} session with ${childName}`,
        data: {
          sessionId: updated.id,
          therapistId: therapist.id,
          type: 'SESSION_COMPLETED',
        },
      });
    }

    return updated;
  }

  async saveSoapNote(userId: string, input: SaveSoapNoteInput) {
    const therapist = await this.prisma.therapist.findUnique({
      where: { userId },
    });
    if (!therapist) {
      throw new NotFoundException('Therapist profile not found');
    }

    const session = await this.prisma.session.findFirst({
      where: { id: input.sessionId, therapistId: therapist.id },
    });
    if (!session) {
      throw new NotFoundException('Session not found');
    }

    return this.prisma.soapNote.upsert({
      where: { sessionId: session.id },
      create: {
        sessionId: session.id,
        authorId: userId,
        subjective: input.subjective,
        objective: input.objective,
        assessment: input.assessment,
        plan: input.plan,
      },
      update: {
        subjective: input.subjective,
        objective: input.objective,
        assessment: input.assessment,
        plan: input.plan,
      },
    });
  }

  async create(data: Record<string, unknown>) {
    void data;
    throw new BadRequestException('Use startSession mutation');
  }

  async findAll() {
    return this.prisma.session.findMany({ take: 50 });
  }

  async findOne(id: string) {
    const session = await this.prisma.session.findUnique({
      where: { id },
      include: { soapNote: true, child: true },
    });
    if (!session) {
      throw new NotFoundException('Session not found');
    }
    return session;
  }

  async update(id: string, data: Record<string, unknown>) {
    await this.findOne(id);
    return this.prisma.session.update({
      where: { id },
      data: data as Parameters<typeof this.prisma.session.update>[0]['data'],
    });
  }

  async remove(id: string) {
    await this.findOne(id);
    await this.prisma.session.delete({ where: { id } });
    return { id, deleted: true };
  }
}
