import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '../../generated/prisma/client';
import { PhiAuditService } from '../audit/phi-audit.service';
import { PrismaService } from '../prisma/prisma.service';
import {
  hasInterventionistSignature,
  hasParentSignature,
} from './eip-form.util';
import { buildServiceLogPdf } from './service-log-pdf.util';

@Injectable()
export class ServiceLogService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly phiAudit: PhiAuditService,
  ) {}

  async ensureFromSessionNote(
    sessionId: string,
    soapNoteId: string,
    eipFormData: Record<string, unknown>,
  ) {
    const therapistSigned = hasInterventionistSignature(eipFormData);
    const parentSigned = hasParentSignature(eipFormData);
    if (!therapistSigned && !parentSigned) {
      return null;
    }

    const session = await this.prisma.session.findUnique({
      where: { id: sessionId },
      include: {
        child: {
          include: {
            parent: { include: { user: true } },
          },
        },
        therapist: { include: { user: true } },
        appointment: true,
      },
    });
    if (!session) {
      return null;
    }

    const existing = await this.prisma.serviceLog.findUnique({
      where: { sessionId },
    });

    const logData = this.buildLogDataSnapshot(eipFormData, session);
    const payload: Prisma.ServiceLogUncheckedUpdateInput = {
      tenantId: session.tenantId,
      childId: session.childId,
      therapistId: session.therapistId,
      logData: logData as Prisma.InputJsonValue,
    };

    if (therapistSigned) {
      payload.therapistSignatureName = String(
        eipFormData.interventionistSignature ?? '',
      ).trim();
      payload.therapistSignedAt =
        existing?.therapistSignedAt ??
        (typeof eipFormData.interventionistSignatureLocationAt === 'string'
          ? new Date(eipFormData.interventionistSignatureLocationAt)
          : new Date());
    }

    if (parentSigned) {
      payload.parentSignatureName = String(
        eipFormData.parentSignature ?? '',
      ).trim();
      payload.parentSignatureDate =
        typeof eipFormData.parentSignatureDate === 'string'
          ? eipFormData.parentSignatureDate
          : null;
      payload.parentSignedAt =
        typeof eipFormData.parentSignatureLocationAt === 'string'
          ? new Date(eipFormData.parentSignatureLocationAt)
          : new Date();
      payload.parentSignatureLat =
        typeof eipFormData.parentSignatureLatitude === 'number'
          ? eipFormData.parentSignatureLatitude
          : null;
      payload.parentSignatureLng =
        typeof eipFormData.parentSignatureLongitude === 'number'
          ? eipFormData.parentSignatureLongitude
          : null;
    }

    return this.prisma.serviceLog.upsert({
      where: { sessionId },
      create: {
        sessionId,
        soapNoteId,
        tenantId: session.tenantId,
        childId: session.childId,
        therapistId: session.therapistId,
        therapistSignatureName: therapistSigned
          ? (payload.therapistSignatureName as string | null)
          : null,
        therapistSignedAt: therapistSigned
          ? (payload.therapistSignedAt as Date | null)
          : null,
        parentSignatureName: parentSigned
          ? (payload.parentSignatureName as string | null)
          : null,
        parentSignatureDate: parentSigned
          ? (payload.parentSignatureDate as string | null)
          : null,
        parentSignedAt: parentSigned
          ? (payload.parentSignedAt as Date | null)
          : null,
        parentSignatureLat: parentSigned
          ? (payload.parentSignatureLat as Prisma.Decimal | null)
          : null,
        parentSignatureLng: parentSigned
          ? (payload.parentSignatureLng as Prisma.Decimal | null)
          : null,
        logData: logData as Prisma.InputJsonValue,
      },
      update: payload,
    });
  }

  async findBySessionId(sessionId: string) {
    return this.prisma.serviceLog.findUnique({
      where: { sessionId },
      include: {
        session: { include: { child: true } },
      },
    });
  }

  async listForTherapistUser(userId: string) {
    const therapist = await this.prisma.therapist.findUnique({
      where: { userId },
    });
    if (!therapist) {
      throw new NotFoundException('Therapist profile not found');
    }

    return this.prisma.serviceLog.findMany({
      where: { therapistId: therapist.id },
      include: {
        session: {
          include: {
            child: true,
            appointment: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getForTherapistSession(userId: string, sessionId: string) {
    const therapist = await this.prisma.therapist.findUnique({
      where: { userId },
    });
    if (!therapist) {
      throw new NotFoundException('Therapist profile not found');
    }

    const log = await this.prisma.serviceLog.findFirst({
      where: { sessionId, therapistId: therapist.id },
      include: {
        session: {
          include: {
            child: true,
            therapist: { include: { user: true } },
            appointment: true,
          },
        },
      },
    });
    if (!log) {
      throw new NotFoundException('Service log not found');
    }
    return log;
  }

  async getForAgencySession(
    tenantId: string,
    sessionId: string,
    actorId: string,
  ) {
    const agency = await this.prisma.agency.findFirst({
      where: { tenantId },
    });
    if (!agency) {
      throw new NotFoundException('Agency not found');
    }

    const log = await this.prisma.serviceLog.findFirst({
      where: {
        sessionId,
        tenantId,
        session: {
          therapist: {
            agencyLinks: {
              some: { agencyId: agency.id, status: 'ACTIVE' },
            },
          },
        },
      },
      include: {
        session: {
          include: {
            child: true,
            therapist: { include: { user: true } },
            appointment: true,
          },
        },
      },
    });
    if (!log) {
      throw new NotFoundException('Service log not found');
    }

    await this.phiAudit.logPhiAccess({
      tenantId,
      actorId,
      action: 'READ',
      resourceType: 'service_log',
      resourceId: log.id,
    });

    return log;
  }

  async buildPdfForTherapist(userId: string, sessionId: string) {
    const log = await this.getForTherapistSession(userId, sessionId);
    return this.buildPdfBuffer(log);
  }

  async buildPdfForAgency(
    tenantId: string,
    sessionId: string,
    actorId: string,
  ) {
    const log = await this.getForAgencySession(tenantId, sessionId, actorId);
    return this.buildPdfBuffer(log);
  }

  async listForParentUser(userId: string) {
    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (!parent) return [];

    return this.prisma.serviceLog.findMany({
      where: {
        parentSignedAt: { not: null },
        session: { child: { parentId: parent.id } },
      },
      include: {
        session: {
          include: {
            child: true,
            appointment: true,
            therapist: { include: { user: true } },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
  }

  async getForParentSession(userId: string, sessionId: string) {
    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (!parent) {
      throw new NotFoundException('Parent profile not found');
    }

    const log = await this.prisma.serviceLog.findFirst({
      where: {
        sessionId,
        parentSignedAt: { not: null },
        session: { child: { parentId: parent.id } },
      },
      include: {
        session: {
          include: {
            child: true,
            therapist: { include: { user: true } },
            appointment: true,
          },
        },
      },
    });
    if (!log) {
      throw new NotFoundException('Service log not found');
    }

    await this.phiAudit.logPhiAccess({
      tenantId: parent.tenantId,
      actorId: userId,
      action: 'READ',
      resourceType: 'service_log',
      resourceId: log.id,
      patientId: log.session.childId,
    });

    return log;
  }

  async buildPdfForParent(userId: string, sessionId: string) {
    const log = await this.getForParentSession(userId, sessionId);
    return this.buildPdfBuffer(log);
  }

  private async buildPdfBuffer(
    log: Awaited<ReturnType<ServiceLogService['getForTherapistSession']>>,
  ) {
    const child = log.session.child;
    const therapist = log.session.therapist.user;
    const sessionDate =
      log.session.appointment?.scheduledStart.toISOString().slice(0, 10) ??
      (typeof (log.logData as Record<string, unknown>).sessionDate === 'string'
        ? ((log.logData as Record<string, unknown>).sessionDate as string)
        : undefined);

    const buffer = await buildServiceLogPdf(log, {
      childName: `${child.firstName} ${child.lastName}`,
      therapistName: `${therapist.firstName} ${therapist.lastName}`,
      sessionDate,
    });

    const safeChild = `${child.firstName}-${child.lastName}`.replace(
      /[^a-zA-Z0-9_-]+/g,
      '-',
    );
    const filename = `service-log-${safeChild}-${sessionDate ?? log.id.slice(0, 8)}.pdf`;

    return { buffer, filename };
  }

  private buildLogDataSnapshot(
    eipFormData: Record<string, unknown>,
    session: {
      child: {
        firstName: string;
        lastName: string;
        dateOfBirth: Date;
        gender: string | null;
        guardianName: string | null;
        guardianPhone: string | null;
        guardianEmail: string | null;
        parent: {
          user: {
            firstName: string;
            lastName: string;
            email: string;
            phone: string | null;
          };
        };
      };
      appointment: { scheduledStart: Date } | null;
    },
  ) {
    const pick = (key: string) => eipFormData[key];
    const child = session.child;
    const parentUser = child.parent.user;
    const parentName =
      child.guardianName?.trim() ||
      `${parentUser.firstName} ${parentUser.lastName}`.trim();
    const parentEmail = child.guardianEmail?.trim() || parentUser.email;
    const parentPhone = child.guardianPhone?.trim() || parentUser.phone || null;

    return {
      childName:
        pick('childName') ?? `${child.firstName} ${child.lastName}`,
      childDob:
        pick('childDob') ?? child.dateOfBirth.toISOString().slice(0, 10),
      childSex: pick('childSex') ?? child.gender ?? null,
      parentName,
      parentEmail,
      parentPhone,
      sessionDate:
        pick('sessionDate') ??
        session.appointment?.scheduledStart.toISOString().slice(0, 10),
      serviceType: pick('serviceType'),
      ifspServiceLocation: pick('ifspServiceLocation'),
      timeFrom: pick('timeFrom'),
      timeTo: pick('timeTo'),
      sessionDelivered: pick('sessionDelivered'),
      parentRelationship: pick('parentRelationship'),
      interventionistName: pick('interventionistName'),
      interventionistSignature: pick('interventionistSignature'),
      interventionistSignatureDate: pick('interventionistSignatureDate'),
      interventionistSignatureLatitude: pick('interventionistSignatureLatitude'),
      interventionistSignatureLongitude: pick(
        'interventionistSignatureLongitude',
      ),
      q1IfspOutcomes: pick('q1IfspOutcomes'),
      q2SessionDescription: pick('q2SessionDescription'),
      q4HomeStrategies: pick('q4HomeStrategies'),
      parentSignature: pick('parentSignature'),
      parentSignatureDate: pick('parentSignatureDate'),
      parentSignatureLatitude: pick('parentSignatureLatitude'),
      parentSignatureLongitude: pick('parentSignatureLongitude'),
    };
  }

  async assertTherapistCanAccessSession(userId: string, sessionId: string) {
    const therapist = await this.prisma.therapist.findUnique({
      where: { userId },
    });
    if (!therapist) {
      throw new ForbiddenException('Therapist profile not found');
    }
    const session = await this.prisma.session.findFirst({
      where: { id: sessionId, therapistId: therapist.id },
    });
    if (!session) {
      throw new ForbiddenException('Session not found');
    }
    return session;
  }
}
