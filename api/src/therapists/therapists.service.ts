import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class TherapistsService {
  constructor(private readonly prisma: PrismaService) {}

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
