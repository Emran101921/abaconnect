import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class AiService {
  constructor(private readonly prisma: PrismaService) {}

  async suggestSoapNote(context: {
    therapyType?: string;
    childName?: string;
    sessionNotes?: string;
  }) {
    void this.prisma;
    return {
      subjective: `Parent reports progress with ${context.childName ?? 'client'} during ${context.therapyType ?? 'therapy'} sessions.`,
      objective: 'Observed engagement and participation during structured activities.',
      assessment: 'Continues toward treatment goals with moderate support.',
      plan: 'Maintain current frequency; adjust goals at next review.',
    };
  }

  async suggestMatches(criteria: { therapyType?: string; zipCode?: string }) {
    const therapists = await this.prisma.therapist.findMany({
      where: {
        isVerified: true,
        isAcceptingClients: true,
        ...(criteria.therapyType
          ? { therapyTypes: { has: criteria.therapyType as never } }
          : {}),
      },
      include: { user: true },
      take: 5,
    });
    return therapists.map((t) => ({
      therapistId: t.id,
      name: `${t.user.firstName} ${t.user.lastName}`,
      score: Number(t.ratingAverage) / 5,
      reason: `Strong fit for ${criteria.therapyType ?? 'therapy'} in your area`,
    }));
  }

  async create(data: Record<string, unknown>) {
    return { id: 'ai', ...data };
  }

  async findAll() {
    return [];
  }

  async findOne(id: string) {
    return { id };
  }

  async update(id: string, data: Record<string, unknown>) {
    return { id, ...data };
  }

  async remove(id: string) {
    return { id, deleted: true };
  }
}
