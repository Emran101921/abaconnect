import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '../../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class GpsService {
  constructor(private readonly prisma: PrismaService) {}

  async recordCheckIn(
    userId: string,
    data: {
      sessionId: string;
      latitude: number;
      longitude: number;
      eventType: string;
      accuracyM?: number;
    },
  ) {
    const therapist = await this.prisma.therapist.findUnique({ where: { userId } });
    if (!therapist) {
      throw new BadRequestException('Therapist profile required for EVV');
    }

    const session = await this.prisma.session.findFirst({
      where: { id: data.sessionId, therapistId: therapist.id },
    });
    if (!session) throw new NotFoundException('Session not found');

    const event = await this.prisma.locationEvent.create({
      data: {
        tenantId: session.tenantId,
        sessionId: session.id,
        latitude: data.latitude,
        longitude: data.longitude,
        accuracyM: data.accuracyM,
        eventType: data.eventType,
      },
    });

    if (data.eventType === 'CHECK_IN') {
      await this.prisma.session.update({
        where: { id: session.id },
        data: {
          checkInAt: new Date(),
          gpsCheckInLat: data.latitude,
          gpsCheckInLng: data.longitude,
          evvVerified: true,
          evvMethod: 'GPS',
        },
      });
    } else if (data.eventType === 'CHECK_OUT') {
      await this.prisma.session.update({
        where: { id: session.id },
        data: {
          checkOutAt: new Date(),
          gpsCheckOutLat: data.latitude,
          gpsCheckOutLng: data.longitude,
          status: 'COMPLETED',
          evvVerified: true,
        },
      });
    }

    return event;
  }

  async listEventsForSession(userId: string, sessionId: string) {
    const therapist = await this.prisma.therapist.findUnique({ where: { userId } });
    if (!therapist) return [];
    const session = await this.prisma.session.findFirst({
      where: { id: sessionId, therapistId: therapist.id },
    });
    if (!session) throw new NotFoundException('Session not found');
    return this.prisma.locationEvent.findMany({
      where: { sessionId },
      orderBy: { recordedAt: 'asc' },
    });
  }

  async create(data: Record<string, unknown>) {
    void data;
    throw new BadRequestException('Use GraphQL recordEvvCheckIn');
  }

  async findAll() {
    return this.prisma.locationEvent.findMany({ take: 20 });
  }

  async findOne(id: string) {
    const row = await this.prisma.locationEvent.findUnique({ where: { id } });
    if (!row) throw new NotFoundException('Location event not found');
    return row;
  }

  async update(id: string, data: Record<string, unknown>) {
    await this.findOne(id);
    return this.prisma.locationEvent.update({
      where: { id },
      data: data as Parameters<typeof this.prisma.locationEvent.update>[0]['data'],
    });
  }

  async remove(id: string) {
    await this.findOne(id);
    await this.prisma.locationEvent.delete({ where: { id } });
    return { id, deleted: true };
  }
}
