import { Injectable } from '@nestjs/common';
import { AuditService } from './audit.service';

@Injectable()
export class PhiAuditService {
  constructor(private readonly audit: AuditService) {}

  async logPhiAccess(data: {
    tenantId: string;
    actorId: string;
    action: 'READ' | 'EXPORT' | 'UPDATE' | 'DELETE';
    resourceType: string;
    resourceId?: string;
    ipAddress?: string;
    userAgent?: string;
  }): Promise<void> {
    await this.audit.log({
      tenantId: data.tenantId,
      actorId: data.actorId,
      action: data.action,
      resourceType: data.resourceType,
      resourceId: data.resourceId,
      ipAddress: data.ipAddress,
      userAgent: data.userAgent,
      metadata: { phi: true },
    });
  }
}
