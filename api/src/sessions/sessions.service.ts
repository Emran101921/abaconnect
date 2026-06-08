import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '../../generated/prisma/client';
import { InsuranceService } from '../insurance/insurance.service';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.service';
import { isEipFormFullySigned } from './eip-form.util';

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

  private parseEipFormData(raw?: string) {
    if (!raw) return undefined;
    try {
      return JSON.parse(raw) as Record<string, unknown>;
    } catch {
      throw new BadRequestException('eipFormData must be valid JSON');
    }
  }

  private isSoapNoteLocked(soapNote?: {
    signedAt: Date | null;
    eipFormData: Prisma.JsonValue;
  } | null) {
    if (!soapNote) return false;
    if (soapNote.signedAt != null) return true;
    const data = soapNote.eipFormData as Record<string, unknown> | null;
    return isEipFormFullySigned(data ?? undefined);
  }

  private buildSessionNoteFormContext(
    session: {
      id: string;
      child: {
        firstName: string;
        lastName: string;
        dateOfBirth: Date;
        gender: string | null;
        diagnosisCodes: string[];
      };
      appointment: {
        therapyType: string;
        locationType: string;
        scheduledStart: Date;
        scheduledEnd: Date;
      };
      soapNote?: {
        signedAt: Date | null;
        eipFormData: Prisma.JsonValue;
      } | null;
    },
    therapist: {
      user: { firstName: string; lastName: string };
      npi: string | null;
      licenseNumber: string | null;
      licenseState: string | null;
    },
    agency?: { npi: string | null } | null,
  ) {
    const apt = session.appointment;
    const child = session.child;
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
    const isFullySigned = this.isSoapNoteLocked(session.soapNote);

    return {
      sessionId: session.id,
      childName: `${child.firstName} ${child.lastName}`,
      childDob: formatDate(child.dateOfBirth),
      childSex: child.gender ?? undefined,
      eiNumber: undefined,
      interventionistName: `${therapist.user.firstName} ${therapist.user.lastName}`,
      credentials: therapyLabel,
      npi: therapist.npi ?? agency?.npi ?? undefined,
      licenseNumber: therapist.licenseNumber ?? undefined,
      licenseState: therapist.licenseState ?? undefined,
      serviceType: therapyLabel,
      sessionDate: formatDate(apt.scheduledStart),
      ifspServiceLocation: locationLabel,
      timeFrom: formatTime(apt.scheduledStart),
      timeTo: formatTime(apt.scheduledEnd),
      sessionDelivered:
        apt.locationType === 'TELEHEALTH' ? 'Telehealth' : 'In-person',
      icd10Code: child.diagnosisCodes[0] ?? undefined,
      existingEipFormData,
      isFullySigned,
    };
  }

  private async upsertSoapNote(
    sessionId: string,
    authorId: string,
    input: SaveSoapNoteInput,
    options: { allowLockedEdit: boolean },
  ) {
    const session = await this.prisma.session.findUnique({
      where: { id: sessionId },
      include: { soapNote: true },
    });
    if (!session) {
      throw new NotFoundException('Session not found');
    }

    if (
      !options.allowLockedEdit &&
      this.isSoapNoteLocked(session.soapNote)
    ) {
      throw new ForbiddenException(
        'Session note is fully signed and cannot be edited by the therapist.',
      );
    }

    const eipFormData = this.parseEipFormData(input.eipFormData);
    const fullySigned =
      eipFormData != null ? isEipFormFullySigned(eipFormData) : false;

    const note = await this.prisma.soapNote.upsert({
      where: { sessionId: session.id },
      create: {
        sessionId: session.id,
        authorId,
        subjective: input.subjective,
        objective: input.objective,
        assessment: input.assessment,
        plan: input.plan,
        eipFormData: eipFormData as Prisma.InputJsonValue,
        signedAt: fullySigned ? new Date() : null,
      },
      update: {
        subjective: input.subjective,
        objective: input.objective,
        assessment: input.assessment,
        plan: input.plan,
        ...(eipFormData !== undefined
          ? {
              eipFormData: eipFormData as Prisma.InputJsonValue,
              signedAt: fullySigned
                ? (session.soapNote?.signedAt ?? new Date())
                : null,
            }
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

    return this.upsertSoapNote(session.id, userId, input, {
      allowLockedEdit: false,
    });
  }

  async saveSoapNoteForAgency(
    tenantId: string,
    userId: string,
    input: SaveSoapNoteInput,
  ) {
    await this.getSessionForAgency(tenantId, input.sessionId);
    return this.upsertSoapNote(input.sessionId, userId, input, {
      allowLockedEdit: true,
    });
  }

  async saveSoapNoteForAdmin(
    tenantId: string,
    userId: string,
    input: SaveSoapNoteInput,
  ) {
    await this.getSessionForAdmin(tenantId, input.sessionId);
    return this.upsertSoapNote(input.sessionId, userId, input, {
      allowLockedEdit: true,
    });
  }

  async getSessionForAgency(tenantId: string, sessionId: string) {
    const agency = await this.prisma.agency.findFirst({
      where: { tenantId },
    });
    if (!agency) {
      throw new NotFoundException('Agency not found');
    }

    const session = await this.prisma.session.findFirst({
      where: {
        id: sessionId,
        therapist: {
          agencyLinks: {
            some: { agencyId: agency.id, status: 'ACTIVE' },
          },
        },
      },
      include: {
        child: true,
        appointment: true,
        soapNote: true,
        therapist: {
          include: {
            user: true,
            agencyLinks: { include: { agency: true }, take: 1 },
          },
        },
      },
    });
    if (!session) {
      throw new NotFoundException('Session not found');
    }
    return session;
  }

  async getSessionForAdmin(tenantId: string, sessionId: string) {
    const session = await this.prisma.session.findFirst({
      where: { id: sessionId, tenantId },
      include: {
        child: true,
        appointment: true,
        soapNote: true,
        therapist: {
          include: {
            user: true,
            agencyLinks: { include: { agency: true }, take: 1 },
          },
        },
      },
    });
    if (!session) {
      throw new NotFoundException('Session not found');
    }
    return session;
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

    const agency = therapist.agencyLinks[0]?.agency;
    return this.buildSessionNoteFormContext(
      session,
      { ...therapist, user: therapist.user },
      agency,
    );
  }

  async getSessionNoteFormContextForAgency(
    tenantId: string,
    sessionId: string,
  ) {
    const session = await this.getSessionForAgency(tenantId, sessionId);
    const agency = session.therapist.agencyLinks[0]?.agency;
    return this.buildSessionNoteFormContext(
      session,
      session.therapist,
      agency,
    );
  }

  async getSessionNoteFormContextForAdmin(
    tenantId: string,
    sessionId: string,
  ) {
    const session = await this.getSessionForAdmin(tenantId, sessionId);
    const agency = session.therapist.agencyLinks[0]?.agency;
    return this.buildSessionNoteFormContext(
      session,
      session.therapist,
      agency,
    );
  }

  async listDocumentedSessionsForAgency(tenantId: string) {
    const agency = await this.prisma.agency.findFirst({
      where: { tenantId },
    });
    if (!agency) {
      return [];
    }

    return this.prisma.session.findMany({
      where: {
        soapNote: { isNot: null },
        therapist: {
          agencyLinks: {
            some: { agencyId: agency.id, status: 'ACTIVE' },
          },
        },
      },
      include: {
        child: true,
        appointment: true,
        soapNote: true,
        therapist: { include: { user: true } },
      },
      orderBy: { updatedAt: 'desc' },
      take: 100,
    });
  }

  async listDocumentedSessionsForAdmin(tenantId: string) {
    return this.prisma.session.findMany({
      where: {
        tenantId,
        soapNote: { isNot: null },
      },
      include: {
        child: true,
        appointment: true,
        soapNote: true,
        therapist: { include: { user: true } },
      },
      orderBy: { updatedAt: 'desc' },
      take: 100,
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
