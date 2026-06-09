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

  async updatePlanForTherapist(
    userId: string,
    planId: string,
    data: {
      title?: string;
      isActive?: boolean;
      goals?: unknown[];
    },
  ) {
    const therapist = await this.prisma.therapist.findUnique({
      where: { userId },
    });
    if (!therapist) {
      throw new BadRequestException('Therapist profile not found');
    }

    const plan = await this.prisma.treatmentPlan.findFirst({
      where: { id: planId, therapistId: therapist.id },
    });
    if (!plan) {
      throw new NotFoundException('Treatment plan not found');
    }

    return this.prisma.treatmentPlan.update({
      where: { id: planId },
      data: {
        title: data.title,
        isActive: data.isActive,
        goals:
          data.goals !== undefined
            ? (data.goals as Prisma.InputJsonValue)
            : undefined,
      },
      include: {
        child: true,
        therapist: { include: { user: true } },
      },
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

  async listProgressNotesForParentUser(userId: string) {
    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (!parent) return [];

    return this.prisma.progressNote.findMany({
      where: {
        signedAt: { not: null },
        session: { child: { parentId: parent.id } },
      },
      include: {
        session: {
          include: {
            child: true,
            therapist: { include: { user: true } },
          },
        },
      },
      orderBy: { signedAt: 'desc' },
      take: 50,
    });
  }

  async submitSessionFeedback(
    userId: string,
    sessionId: string,
    feedback: string,
  ) {
    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (!parent) {
      throw new BadRequestException('Parent profile not found');
    }

    const note = await this.prisma.progressNote.findFirst({
      where: {
        sessionId,
        session: { child: { parentId: parent.id } },
      },
    });
    if (!note) {
      throw new NotFoundException('Progress note not found for session');
    }

    return this.prisma.progressNote.update({
      where: { id: note.id },
      data: { parentFeedback: feedback },
      include: {
        session: {
          include: {
            child: true,
            therapist: { include: { user: true } },
          },
        },
      },
    });
  }

  async listBadgesForTherapist(therapistId: string) {
    return this.prisma.providerBadge.findMany({
      where: { therapistId },
      orderBy: { awardedAt: 'desc' },
    });
  }

  private startOfWeekMonday(date: Date): Date {
    const d = new Date(date);
    const day = d.getDay();
    const diff = d.getDate() - day + (day === 0 ? -6 : 1);
    d.setDate(diff);
    d.setHours(0, 0, 0, 0);
    return d;
  }

  async therapistWeeklyProgress(userId: string) {
    const therapist = await this.prisma.therapist.findUnique({
      where: { userId },
    });
    if (!therapist) {
      return { weeks: [], children: [] };
    }

    const now = new Date();
    const weekStarts: Date[] = [];
    for (let i = 5; i >= 0; i--) {
      const start = this.startOfWeekMonday(now);
      start.setDate(start.getDate() - i * 7);
      weekStarts.push(start);
    }

    const notes = await this.prisma.progressNote.findMany({
      where: {
        signedAt: { not: null, gte: weekStarts[0] },
        session: { therapistId: therapist.id },
      },
      select: { signedAt: true },
    });

    const weeks = weekStarts.map((start, index) => {
      const end =
        index < weekStarts.length - 1
          ? weekStarts[index + 1]
          : new Date(start.getTime() + 7 * 24 * 60 * 60 * 1000);
      const reportCount = notes.filter(
        (n) => n.signedAt! >= start && n.signedAt! < end,
      ).length;
      const weekLabel = start.toLocaleDateString('en-US', {
        month: 'short',
        day: 'numeric',
      });
      return { weekLabel, reportCount };
    });

    const plans = await this.listPlansForTherapistUser(userId);
    const children = plans
      .filter((p) => p.child)
      .map((p) => {
        const goals = Array.isArray(p.goals)
          ? (p.goals as { status?: string }[])
          : [];
        const total = goals.length;
        const done = goals.filter((g) => g.status === 'done').length;
        const goalCompletionPercent =
          total > 0 ? Math.round((done / total) * 100) : 0;
        return {
          childId: p.child!.id,
          childName: `${p.child!.firstName} ${p.child!.lastName}`,
          goalCompletionPercent,
          activePlanTitle: p.title,
        };
      });

    return { weeks, children };
  }
}
