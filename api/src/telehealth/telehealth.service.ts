import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { TelehealthVendorService } from './telehealth-vendor.service';

@Injectable()
export class TelehealthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly vendor: TelehealthVendorService,
  ) {}

  async listForUser(userId: string) {
    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (parent) {
      return this.prisma.telehealthSession.findMany({
        where: {
          appointment: { parentId: parent.id },
        },
        include: {
          appointment: {
            include: { child: true, therapist: { include: { user: true } } },
          },
        },
        orderBy: { createdAt: 'desc' },
        take: 30,
      });
    }

    const therapist = await this.prisma.therapist.findUnique({
      where: { userId },
    });
    if (therapist) {
      return this.prisma.telehealthSession.findMany({
        where: { appointment: { therapistId: therapist.id } },
        include: {
          appointment: {
            include: { child: true, parent: { include: { user: true } } },
          },
        },
        orderBy: { createdAt: 'desc' },
        take: 30,
      });
    }

    return [];
  }

  async getOrCreateForAppointment(userId: string, appointmentId: string) {
    const appointment = await this.findAccessibleAppointment(
      userId,
      appointmentId,
    );
    const existing = await this.prisma.telehealthSession.findUnique({
      where: { appointmentId },
      include: { appointment: true },
    });
    if (existing) {
      return this.withJoinUrls(existing);
    }

    const roomId = `room_${appointment.id.replace(/-/g, '').slice(0, 12)}`;
    const full = await this.prisma.appointment.findUnique({
      where: { id: appointment.id },
      include: {
        child: true,
        therapist: { include: { user: true } },
        parent: { include: { user: true } },
      },
    });
    const links = await this.vendor.createRoomLinks(roomId, {
      providerName: full?.therapist?.user
        ? `${full.therapist.user.firstName} ${full.therapist.user.lastName}`
        : 'Provider',
      patientName: full?.child
        ? `${full.child.firstName} ${full.child.lastName}`
        : 'Patient',
    });

    const created = await this.prisma.telehealthSession.create({
      data: {
        tenantId: appointment.tenantId,
        appointmentId: appointment.id,
        roomId: links.roomId,
        vendor: links.vendor,
        providerUrl: links.providerUrl,
        patientUrl: links.patientUrl,
      },
      include: { appointment: true },
    });
    return this.withJoinUrls(created);
  }

  async grantRecordingConsent(userId: string, telehealthId: string) {
    const session = await this.findAccessibleTelehealth(userId, telehealthId);
    return this.prisma.telehealthSession.update({
      where: { id: session.id },
      data: {
        recordingConsentGranted: true,
        recordingConsentAt: new Date(),
        recordingConsentByUserId: userId,
      },
      include: { appointment: true },
    });
  }

  async startSession(userId: string, telehealthId: string) {
    const session = await this.findAccessibleTelehealth(userId, telehealthId);
    if (
      process.env.TELEHEALTH_RECORDING_ENABLED === 'true' &&
      !session.recordingConsentGranted
    ) {
      throw new BadRequestException(
        'Recording consent is required before starting this telehealth session',
      );
    }
    return this.prisma.telehealthSession.update({
      where: { id: session.id },
      data: { startedAt: new Date() },
      include: { appointment: true },
    });
  }

  private withJoinUrls<
    T extends {
      roomId: string;
      vendor?: string | null;
      providerUrl: string | null;
      patientUrl: string | null;
    },
  >(row: T) {
    const base =
      process.env.TELEHEALTH_BASE_URL ?? 'https://meet.abaconnect.local';
    return {
      ...row,
      providerUrl: row.providerUrl ?? `${base}/${row.roomId}?role=provider`,
      patientUrl: row.patientUrl ?? `${base}/${row.roomId}?role=patient`,
    };
  }

  private async findAccessibleAppointment(
    userId: string,
    appointmentId: string,
  ) {
    const appointment = await this.prisma.appointment.findUnique({
      where: { id: appointmentId },
      include: { parent: true, therapist: true },
    });
    if (!appointment) {
      throw new NotFoundException('Appointment not found');
    }
    const isParent = appointment.parent.userId === userId;
    const isTherapist = appointment.therapist.userId === userId;
    if (!isParent && !isTherapist) {
      throw new BadRequestException('Not authorized for this appointment');
    }
    return appointment;
  }

  private async findAccessibleTelehealth(userId: string, telehealthId: string) {
    const row = await this.prisma.telehealthSession.findUnique({
      where: { id: telehealthId },
      include: { appointment: { include: { parent: true, therapist: true } } },
    });
    if (!row) {
      throw new NotFoundException('Telehealth session not found');
    }
    const isParent = row.appointment.parent.userId === userId;
    const isTherapist = row.appointment.therapist.userId === userId;
    if (!isParent && !isTherapist) {
      throw new BadRequestException('Not authorized');
    }
    return row;
  }

  async create(data: Record<string, unknown>) {
    void data;
    throw new BadRequestException('Use GraphQL telehealth operations');
  }

  async findAll() {
    return this.prisma.telehealthSession.findMany({ take: 20 });
  }

  async findOne(id: string) {
    const row = await this.prisma.telehealthSession.findUnique({
      where: { id },
    });
    if (!row) throw new NotFoundException('Telehealth session not found');
    return row;
  }

  async update(id: string, data: Record<string, unknown>) {
    await this.findOne(id);
    return this.prisma.telehealthSession.update({
      where: { id },
      data: data as Parameters<
        typeof this.prisma.telehealthSession.update
      >[0]['data'],
    });
  }

  async remove(id: string) {
    await this.findOne(id);
    await this.prisma.telehealthSession.delete({ where: { id } });
    return { id, deleted: true };
  }
}
