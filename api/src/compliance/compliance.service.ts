import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ComplianceService {
  constructor(private readonly prisma: PrismaService) {}

  async listConsentsForUser(userId: string) {
    return this.prisma.hipaaConsent.findMany({
      where: { userId },
      orderBy: { grantedAt: 'desc' },
      take: 20,
    });
  }

  async grantConsent(
    userId: string,
    data: { consentType: string; version: string },
  ) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new BadRequestException('User not found');

    await this.prisma.hipaaConsent.updateMany({
      where: {
        userId,
        consentType: data.consentType,
        granted: true,
        revokedAt: null,
      },
      data: { granted: false, revokedAt: new Date() },
    });

    return this.prisma.hipaaConsent.create({
      data: {
        tenantId: user.tenantId,
        userId,
        consentType: data.consentType,
        version: data.version,
        granted: true,
      },
    });
  }

  async revokeConsent(userId: string, consentId: string) {
    const row = await this.prisma.hipaaConsent.findFirst({
      where: { id: consentId, userId },
    });
    if (!row) throw new NotFoundException('Consent not found');
    return this.prisma.hipaaConsent.update({
      where: { id: consentId },
      data: { granted: false, revokedAt: new Date() },
    });
  }

  async create(data: Record<string, unknown>) {
    void data;
    throw new BadRequestException('Use GraphQL grantConsent');
  }

  async findAll() {
    return this.prisma.hipaaConsent.findMany({ take: 20 });
  }

  async findOne(id: string) {
    const row = await this.prisma.hipaaConsent.findUnique({ where: { id } });
    if (!row) throw new NotFoundException('Consent not found');
    return row;
  }

  async update(id: string, data: Record<string, unknown>) {
    await this.findOne(id);
    return this.prisma.hipaaConsent.update({
      where: { id },
      data: data as Parameters<
        typeof this.prisma.hipaaConsent.update
      >[0]['data'],
    });
  }

  async remove(id: string) {
    await this.findOne(id);
    await this.prisma.hipaaConsent.delete({ where: { id } });
    return { id, deleted: true };
  }
}
