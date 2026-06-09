import { Injectable } from '@nestjs/common';
import { Prisma, SecurityEventSeverity } from '../../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';

export interface SecurityEventInput {
  tenantId?: string;
  userId?: string;
  eventType: string;
  severity?: SecurityEventSeverity;
  ipAddress?: string;
  userAgent?: string;
  metadata?: Record<string, unknown>;
}

export interface SecurityEventInvestigationFilters {
  tenantId?: string;
  userId?: string;
  eventType?: string;
  severity?: SecurityEventSeverity;
  fromDate?: Date;
  toDate?: Date;
  take?: number;
}

@Injectable()
export class SecurityEventService {
  constructor(private readonly prisma: PrismaService) {}

  async log(event: SecurityEventInput) {
    return this.prisma.securityEvent.create({
      data: {
        tenantId: event.tenantId,
        userId: event.userId,
        eventType: event.eventType,
        severity: event.severity ?? 'INFO',
        ipAddress: event.ipAddress,
        userAgent: event.userAgent,
        metadata: (event.metadata ?? {}) as Prisma.InputJsonValue,
      },
    });
  }

  async listForTenant(tenantId: string, take = 50) {
    return this.prisma.securityEvent.findMany({
      where: { tenantId },
      orderBy: { createdAt: 'desc' },
      take,
    });
  }

  async listForInvestigation(filters: SecurityEventInvestigationFilters) {
    const where: Prisma.SecurityEventWhereInput = {};
    if (filters.tenantId) where.tenantId = filters.tenantId;
    if (filters.userId) where.userId = filters.userId;
    if (filters.eventType) where.eventType = filters.eventType;
    if (filters.severity) where.severity = filters.severity;
    if (filters.fromDate || filters.toDate) {
      where.createdAt = {};
      if (filters.fromDate) where.createdAt.gte = filters.fromDate;
      if (filters.toDate) where.createdAt.lte = filters.toDate;
    }
    return this.prisma.securityEvent.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: filters.take ?? 100,
    });
  }
}
