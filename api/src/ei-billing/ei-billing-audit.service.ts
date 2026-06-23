import { Injectable } from '@nestjs/common';
import { AuditAction } from '../../generated/prisma/client';
import { AuditService } from '../audit/audit.service';

@Injectable()
export class EiBillingAuditService {
  constructor(private readonly audit: AuditService) {}

  log(
    tenantId: string,
    actorId: string,
    actorRole: string,
    action: AuditAction,
    entityType: string,
    entityId: string,
    metadata?: Record<string, unknown>,
    patientId?: string,
  ) {
    return this.audit.log({
      tenantId,
      actorId,
      actorRole,
      action,
      resourceType: entityType,
      resourceId: entityId,
      patientId,
      metadata,
    });
  }

  search(
    tenantId: string,
    filters: {
      entityType?: string;
      from?: Date;
      to?: Date;
      take?: number;
    },
  ) {
    return this.audit.searchForTenant(tenantId, {
      entityType: filters.entityType ?? 'EiBillingRecord',
      from: filters.from,
      to: filters.to,
      take: filters.take ?? 100,
    });
  }
}
