import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
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

    return this.prisma.screeningResponse.create({
      data: {
        templateId: template.id,
        childId: child.id,
        parentId: parent.id,
        tenantId: parent.tenantId,
        responses: data.responses as Prisma.InputJsonValue,
      },
      include: { template: true, child: true },
    });
  }

  async create(data: Record<string, unknown>) {
    void data;
    throw new BadRequestException('Use GraphQL submitScreening');
  }

  async findAll() {
    return this.prisma.screeningTemplate.findMany({ take: 50 });
  }

  async findOne(id: string) {
    const row = await this.prisma.screeningTemplate.findUnique({ where: { id } });
    if (!row) {
      throw new NotFoundException('Screening template not found');
    }
    return row;
  }

  async update(id: string, data: Record<string, unknown>) {
    await this.findOne(id);
    return this.prisma.screeningTemplate.update({
      where: { id },
      data: data as Parameters<typeof this.prisma.screeningTemplate.update>[0]['data'],
    });
  }

  async remove(id: string) {
    await this.findOne(id);
    await this.prisma.screeningTemplate.delete({ where: { id } });
    return { id, deleted: true };
  }
}
