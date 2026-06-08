import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '../../generated/prisma/client';
import { InsuranceService } from '../insurance/insurance.service';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.service';

export interface SaveSoapNoteInput {
  sessionId: string;
  subjective?: string;
  objective?: string;
  assessment?: string;
  plan?: string;
  eipFormData?: string;
}

@Injectable()
export class SessionsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
    private readonly insurance: InsuranceService,
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
        progressNote: true,
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
        status: 'PENDING_DOCUMENTATION',
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

    const childName = `${updated.child.firstName} ${updated.child.lastName}`;
    await this.notifications.createForUser(userId, {
      title: 'SOAP note due',
      body: `Document the session with ${childName}`,
      data: { sessionId: updated.id, type: 'SOAP_DUE' },
    });

    const parentUserId = updated.appointment?.parent?.userId;
    if (parentUserId) {
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

    await this.insurance.draftClaimFromSession(updated.id);

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

    let eipFormData: Record<string, unknown> | undefined;
    if (input.eipFormData) {
      try {
        eipFormData = JSON.parse(input.eipFormData) as Record<string, unknown>;
      } catch {
        throw new BadRequestException('eipFormData must be valid JSON');
      }
    }

    const note = await this.prisma.soapNote.upsert({
      where: { sessionId: session.id },
      create: {
        sessionId: session.id,
        authorId: userId,
        subjective: input.subjective,
        objective: input.objective,
        assessment: input.assessment,
        plan: input.plan,
        eipFormData: eipFormData as Prisma.InputJsonValue,
      },
      update: {
        subjective: input.subjective,
        objective: input.objective,
        assessment: input.assessment,
        plan: input.plan,
        ...(eipFormData !== undefined
          ? { eipFormData: eipFormData as Prisma.InputJsonValue }
          : {}),
      },
    });

    if (session.status === 'PENDING_DOCUMENTATION') {
      await this.prisma.session.update({
        where: { id: session.id },
        data: { status: 'COMPLETED' },
      });
      const claim = await this.prisma.insuranceClaim.findUnique({
        where: { sessionId: session.id },
      });
      if (claim) {
        await this.insurance.prepareClaimEdi(claim.id);
      }
    }

    return note;
  }

  async getSessionNoteFormContext(userId: string, sessionId: string) {
    const therapist = await this.prisma.therapist.findUnique({
      where: { userId },
      include: {
        user: true,
        agencyLinks: { include: { agency: true }, take: 1 },
      },
    });
    if (!therapist) {
      throw new NotFoundException('Therapist profile not found');
    }

    const session = await this.prisma.session.findFirst({
      where: { id: sessionId, therapistId: therapist.id },
      include: {
        child: true,
        appointment: true,
        soapNote: true,
      },
    });
    if (!session) {
      throw new NotFoundException('Session not found');
    }

    const apt = session.appointment;
    const child = session.child;
    const agency = therapist.agencyLinks[0]?.agency;
    const therapyLabel = apt.therapyType.replace(/_/g, ' ');
    const locationLabel =
      apt.locationType === 'TELEHEALTH'
        ? 'Telehealth'
        : apt.locationType === 'CLINIC'
          ? 'Facility'
          : 'Home/Community';

    const formatTime = (d: Date) =>
      d.toLocaleTimeString('en-US', {
        hour: 'numeric',
        minute: '2-digit',
        hour12: true,
      });

    const formatDate = (d: Date) => d.toISOString().slice(0, 10);

    const existingEip = session.soapNote?.eipFormData;
    const existingEipFormData =
      existingEip != null ? JSON.stringify(existingEip) : undefined;

    return {
      sessionId: session.id,
      childName: `${child.firstName} ${child.lastName}`,
      childDob: formatDate(child.dateOfBirth),
      childSex: child.gender ?? undefined,
      eiNumber: undefined,
      interventionistName: `${therapist.user.firstName} ${therapist.user.lastName}`,
      credentials: therapist.licenseNumber
        ? `${therapyLabel} (${therapist.licenseNumber})`
        : therapyLabel,
      npi: agency?.npi ?? undefined,
      serviceType: therapyLabel,
      sessionDate: formatDate(apt.scheduledStart),
      ifspServiceLocation: locationLabel,
      timeFrom: formatTime(apt.scheduledStart),
      timeTo: formatTime(apt.scheduledEnd),
      sessionDelivered:
        apt.locationType === 'TELEHEALTH' ? 'Telehealth' : 'In-person',
      icd10Code: child.diagnosisCodes[0] ?? undefined,
      existingEipFormData,
    };
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
