import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma, TherapyType } from '../../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ClinicalService {
  constructor(private readonly prisma: PrismaService) {}

  async listPlansForParentUser(userId: string) {
    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (!parent) return [];
    return this.prisma.treatmentPlan.findMany({
      where: { child: { parentId: parent.id }, isActive: true },
      include: {
        child: true,
        therapist: { include: { user: true } },
      },
      orderBy: { startDate: 'desc' },
      take: 30,
    });
  }

  async listPlansForTherapistUser(userId: string) {
    const therapist = await this.prisma.therapist.findUnique({
      where: { userId },
    });
    if (!therapist) return [];
    return this.prisma.treatmentPlan.findMany({
      where: { therapistId: therapist.id },
      include: { child: true },
      orderBy: { updatedAt: 'desc' },
      take: 30,
    });
  }

  async createPlanForTherapist(
    userId: string,
    data: {
      childId: string;
      therapyType: TherapyType;
      title: string;
      goals?: unknown[];
      startDate: Date;
    },
  ) {
    const therapist = await this.prisma.therapist.findUnique({
      where: { userId },
    });
    if (!therapist) {
      throw new BadRequestException('Therapist profile not found');
    }

    const child = await this.prisma.child.findFirst({
      where: { id: data.childId, tenantId: therapist.tenantId },
    });
    if (!child) {
      throw new NotFoundException('Child not found');
    }

    return this.prisma.treatmentPlan.create({
      data: {
        tenantId: therapist.tenantId,
        childId: child.id,
        therapistId: therapist.id,
        authorId: userId,
        therapyType: data.therapyType,
        title: data.title,
        goals: (data.goals ?? []) as Prisma.InputJsonValue,
        startDate: data.startDate,
        isActive: true,
      },
      include: { child: true },
    });
  }

  async saveProgressNote(
    userId: string,
    data: { sessionId: string; summary: string; parentFeedback?: string },
  ) {
    const therapist = await this.prisma.therapist.findUnique({
      where: { userId },
    });
    if (!therapist) {
      throw new BadRequestException('Therapist profile not found');
    }

    const session = await this.prisma.session.findFirst({
      where: { id: data.sessionId, therapistId: therapist.id },
    });
    if (!session) {
      throw new NotFoundException('Session not found');
    }

    return this.prisma.progressNote.upsert({
      where: { sessionId: session.id },
      create: {
        sessionId: session.id,
        authorId: userId,
        summary: data.summary,
        parentFeedback: data.parentFeedback,
        signedAt: new Date(),
      },
      update: {
        summary: data.summary,
        parentFeedback: data.parentFeedback,
        signedAt: new Date(),
      },
    });
  }

  async listBadgesForTherapist(therapistId: string) {
    return this.prisma.providerBadge.findMany({
      where: { therapistId },
      orderBy: { awardedAt: 'desc' },
    });
  }
}
