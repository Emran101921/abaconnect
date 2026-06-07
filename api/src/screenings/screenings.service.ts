import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '../../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ScreeningsService {
  constructor(private readonly prisma: PrismaService) {}

  async listTemplatesForTenant(tenantId: string) {
    return this.prisma.screeningTemplate.findMany({
      where: { tenantId, isActive: true },
      orderBy: [{ therapyType: 'asc' }, { version: 'desc' }],
    });
  }

  async submitResponseForParent(
    userId: string,
    data: {
      templateId: string;
      childId: string;
      responses: Record<string, unknown>;
    },
  ) {
    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (!parent) {
      throw new BadRequestException('Parent profile not found');
    }

    const child = await this.prisma.child.findFirst({
      where: { id: data.childId, parentId: parent.id },
    });
    if (!child) {
      throw new NotFoundException('Child not found');
    }

    const template = await this.prisma.screeningTemplate.findFirst({
      where: { id: data.templateId, tenantId: parent.tenantId },
    });
    if (!template) {
      throw new NotFoundException('Screening template not found');
    }

    const score = this.scoreResponses(data.responses);
    const riskLevel = this.riskLevelFromScore(score);

    return this.prisma.screeningResponse.create({
      data: {
        templateId: template.id,
        childId: child.id,
        parentId: parent.id,
        tenantId: parent.tenantId,
        responses: data.responses as Prisma.InputJsonValue,
        score,
        riskLevel,
      },
      include: { template: true, child: true },
    });
  }

  async listHistoryForParentUser(userId: string) {
    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (!parent) return [];

    return this.prisma.screeningResponse.findMany({
      where: { parentId: parent.id },
      include: { template: true, child: true },
      orderBy: { completedAt: 'desc' },
      take: 50,
    });
  }

  async getResponseForTenant(tenantId: string, responseId: string) {
    const row = await this.prisma.screeningResponse.findFirst({
      where: { id: responseId, tenantId },
      include: { template: true, child: true },
    });
    if (!row) throw new NotFoundException('Screening not found');
    return row;
  }

  async getScreeningFunnelForTenant(tenantId: string) {
    const [
      completedCount,
      lowRiskCount,
      moderateRiskCount,
      highRiskCount,
      recentScreenings,
    ] = await Promise.all([
      this.prisma.screeningResponse.count({ where: { tenantId } }),
      this.prisma.screeningResponse.count({
        where: { tenantId, riskLevel: 'LOW' },
      }),
      this.prisma.screeningResponse.count({
        where: { tenantId, riskLevel: 'MODERATE' },
      }),
      this.prisma.screeningResponse.count({
        where: { tenantId, riskLevel: 'HIGH' },
      }),
      this.prisma.screeningResponse.findMany({
        where: { tenantId },
        include: { template: true, child: true },
        orderBy: { completedAt: 'desc' },
        take: 10,
      }),
    ]);

    return {
      summary: {
        completedCount,
        lowRiskCount,
        moderateRiskCount,
        highRiskCount,
      },
      recentScreenings,
    };
  }

  private scoreResponses(responses: Record<string, unknown>) {
    let total = 0;
    let count = 0;
    for (const value of Object.values(responses)) {
      if (typeof value === 'number') {
        total += value;
        count += 1;
      } else if (value === true) {
        total += 1;
        count += 1;
      } else if (value === false) {
        count += 1;
      }
    }
    if (count === 0) return null;
    return Number((total / count).toFixed(2));
  }

  private riskLevelFromScore(score: number | null) {
    if (score == null) return null;
    if (score >= 0.7) return 'HIGH';
    if (score >= 0.4) return 'MODERATE';
    return 'LOW';
  }

  async create(data: Record<string, unknown>) {
    void data;
    throw new BadRequestException('Use GraphQL submitScreening');
  }

  async findAll() {
    return this.prisma.screeningTemplate.findMany({ take: 50 });
  }

  async findOne(id: string) {
    const row = await this.prisma.screeningTemplate.findUnique({
      where: { id },
    });
    if (!row) {
      throw new NotFoundException('Screening template not found');
    }
    return row;
  }

  async update(id: string, data: Record<string, unknown>) {
    await this.findOne(id);
    return this.prisma.screeningTemplate.update({
      where: { id },
      data: data as Parameters<
        typeof this.prisma.screeningTemplate.update
      >[0]['data'],
    });
  }

  async remove(id: string) {
    await this.findOne(id);
    await this.prisma.screeningTemplate.delete({ where: { id } });
    return { id, deleted: true };
  }
}
