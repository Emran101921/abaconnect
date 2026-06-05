import { BadRequestException, Injectable } from '@nestjs/common';
import { AuditService } from '../audit/audit.service';
import { PrismaService } from '../prisma/prisma.service';

export interface MatchProviderInput {
  id: string;
  distanceKm: number;
  rating: number;
}

export interface ScoredProvider extends MatchProviderInput {
  score: number;
}

export interface MatchWeights {
  distance: number;
  rating: number;
}

@Injectable()
export class MatchingService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  async create(data: Record<string, unknown>) {
    const tenantId = data.tenantId as string | undefined;
    if (!tenantId) {
      throw new BadRequestException('tenantId is required');
    }
    const therapyType = data.therapyType as string | undefined;
    const latitude = data.latitude as number | undefined;
    const longitude = data.longitude as number | undefined;
    const parentUserId = data.parentUserId as string | undefined;

    const results = await this.findTherapistsForMatch(
      tenantId,
      therapyType,
      latitude,
      longitude,
    );

    const log = await this.audit.log({
      tenantId,
      actorId: parentUserId,
      action: 'READ',
      resourceType: 'MATCH_SEARCH',
      metadata: {
        therapyType,
        latitude,
        longitude,
        resultCount: results.length,
        topTherapistIds: results.slice(0, 10).map((r) => r.id),
      },
    });

    return {
      id: log.id,
      tenantId,
      therapyType,
      resultCount: results.length,
      results,
    };
  }

  async findAll(tenantId?: string) {
    return this.prisma.auditLog.findMany({
      where: {
        entityType: 'MATCH_SEARCH',
        ...(tenantId ? { tenantId } : {}),
      },
      orderBy: { createdAt: 'desc' },
      take: 25,
    });
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

  async findTherapistsForMatch(
    tenantId: string,
    therapyType?: string,
    latitude?: number,
    longitude?: number,
  ): Promise<ScoredProvider[]> {
    const therapists = await this.prisma.therapist.findMany({
      where: {
        tenantId,
        isVerified: true,
        isAcceptingClients: true,
        ...(therapyType ? { therapyTypes: { has: therapyType as never } } : {}),
      },
      include: { user: true },
      take: 50,
    });

    const providers: MatchProviderInput[] = therapists.map((t) => {
      const lat = latitude ?? 0;
      const lng = longitude ?? 0;
      const tLat = t.latitude ? Number(t.latitude) : lat;
      const tLng = t.longitude ? Number(t.longitude) : lng;
      const distanceKm = Math.hypot(tLat - lat, tLng - lng) * 111;
      return {
        id: t.id,
        distanceKm,
        rating: Number(t.ratingAverage) || 0,
      };
    });

    return this.scoreProviders(providers);
  }

  scoreProviders(
    providers: MatchProviderInput[],
    weights: MatchWeights = { distance: 0.6, rating: 0.4 },
  ): ScoredProvider[] {
    const maxDistance = Math.max(...providers.map((p) => p.distanceKm), 1);
    return providers
      .map((provider) => {
        const distanceScore = 1 - provider.distanceKm / maxDistance;
        const ratingScore = provider.rating / 5;
        const score =
          distanceScore * weights.distance + ratingScore * weights.rating;
        return { ...provider, score };
      })
      .sort((a, b) => b.score - a.score);
  }
}
