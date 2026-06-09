import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { AuditAction, Prisma } from '../../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class AuditService {
  constructor(private readonly prisma: PrismaService) {}

  async log(data: {
    tenantId: string;
    actorId?: string;
    action: AuditAction | string;
    resourceType: string;
    resourceId?: string;
    metadata?: Record<string, unknown>;
    ipAddress?: string;
    userAgent?: string;
  }) {
    const metadata = { ...(data.metadata ?? {}) };
    this.assertMetadataSafe(metadata);
    return this.prisma.auditLog.create({
      data: {
        tenantId: data.tenantId,
        actorId: data.actorId,
        action: data.action as AuditAction,
        entityType: data.resourceType,
        entityId: data.resourceId,
        metadata: metadata as Prisma.InputJsonValue,
        ipAddress: data.ipAddress,
        userAgent: data.userAgent,
      },
    });
  }

  async findAllForTenant(tenantId: string, take = 50) {
    return this.prisma.auditLog.findMany({
      where: { tenantId },
      orderBy: { createdAt: 'desc' },
      take,
    });
  }

  async findOneForTenant(tenantId: string, id: string) {
    const row = await this.prisma.auditLog.findFirst({
      where: { id, tenantId },
    });
    if (!row) throw new NotFoundException('Audit log not found');
    return row;
  }

  /** @deprecated Append-only — updates are not permitted */
  async update(): Promise<never> {
    throw new ForbiddenException('Audit logs are append-only');
  }

  /** @deprecated Append-only — deletes are not permitted */
  async remove(): Promise<never> {
    throw new ForbiddenException('Audit logs are append-only');
  }

  private assertMetadataSafe(metadata: Record<string, unknown>): void {
    const forbidden = [
      'body',
      'message',
      'soap',
      'diagnosis',
      'childName',
      'responses',
    ];
    for (const key of Object.keys(metadata)) {
      if (forbidden.includes(key)) {
        throw new ForbiddenException(
          'Audit metadata must not contain PHI fields',
        );
      }
    }
  }
}
