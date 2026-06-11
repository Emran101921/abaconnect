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
    actorRole?: string;
    action: AuditAction | string;
    resourceType: string;
    resourceId?: string;
    patientId?: string;
    success?: boolean;
    deviceId?: string;
    metadata?: Record<string, unknown>;
    ipAddress?: string;
    userAgent?: string;
    fieldChanges?: Record<string, { old?: unknown; new?: unknown }>;
  }) {
    const metadata = { ...(data.metadata ?? {}) };
    if (data.fieldChanges) {
      metadata.fieldChanges = this.sanitizeFieldChanges(data.fieldChanges);
    }
    this.assertMetadataSafe(metadata);
    return this.prisma.auditLog.create({
      data: {
        tenantId: data.tenantId,
        actorId: data.actorId,
        actorRole: data.actorRole,
        action: data.action as AuditAction,
        entityType: data.resourceType,
        entityId: data.resourceId,
        patientId: data.patientId,
        success: data.success ?? true,
        deviceId: data.deviceId,
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

  async searchForTenant(
    tenantId: string,
    filters: {
      action?: AuditAction;
      actorId?: string;
      patientId?: string;
      entityType?: string;
      from?: Date;
      to?: Date;
      take?: number;
    },
  ) {
    return this.prisma.auditLog.findMany({
      where: {
        tenantId,
        ...(filters.action ? { action: filters.action } : {}),
        ...(filters.actorId ? { actorId: filters.actorId } : {}),
        ...(filters.patientId ? { patientId: filters.patientId } : {}),
        ...(filters.entityType ? { entityType: filters.entityType } : {}),
        ...(filters.from || filters.to
          ? {
              createdAt: {
                ...(filters.from ? { gte: filters.from } : {}),
                ...(filters.to ? { lte: filters.to } : {}),
              },
            }
          : {}),
      },
      orderBy: { createdAt: 'desc' },
      take: filters.take ?? 100,
      include: {
        actor: {
          select: {
            id: true,
            email: true,
            firstName: true,
            lastName: true,
            role: true,
          },
        },
      },
    });
  }

  private sanitizeFieldChanges(
    changes: Record<string, { old?: unknown; new?: unknown }>,
  ): Record<string, { old?: unknown; new?: unknown }> {
    const sensitive = new Set([
      'ssn',
      'medicaidId',
      'insuranceMemberId',
      'diagnosis',
      'dateOfBirth',
      'body',
      'subjective',
      'objective',
      'assessment',
      'plan',
    ]);
    const out: Record<string, { old?: unknown; new?: unknown }> = {};
    for (const [key, value] of Object.entries(changes)) {
      if (sensitive.has(key)) {
        out[key] = { old: '[REDACTED]', new: '[REDACTED]' };
      } else {
        out[key] = value;
      }
    }
    return out;
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
