import {
  BadRequestException,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { AuditAction, EiBillingQueueStatus } from '../../generated/prisma/client';
import {
  EI_QUEUE_ROLE_PERMISSIONS,
  EI_QUEUE_TRANSITIONS,
} from './ei-billing.constants';
import { EiBillingActor } from './ei-billing-access.util';
import { EiBillingAuditService } from './ei-billing-audit.service';

@Injectable()
export class EiBillingQueueService {
  constructor(private readonly audit: EiBillingAuditService) {}

  assertTransitionAllowed(
    from: EiBillingQueueStatus,
    to: EiBillingQueueStatus,
  ): void {
    const allowed = EI_QUEUE_TRANSITIONS[from] ?? [];
    if (!allowed.includes(to)) {
      throw new BadRequestException(
        `Invalid queue transition from ${from} to ${to}`,
      );
    }
  }

  assertRoleForTargetStatus(
    actor: EiBillingActor,
    target: EiBillingQueueStatus,
  ): void {
    const roles = EI_QUEUE_ROLE_PERMISSIONS[target];
    if (roles && !roles.includes(actor.role)) {
      throw new ForbiddenException(
        `Role ${actor.role} cannot transition records to ${target}`,
      );
    }
  }

  async logTransition(
    tenantId: string,
    actor: EiBillingActor,
    recordId: string,
    from: EiBillingQueueStatus,
    to: EiBillingQueueStatus,
    childId?: string,
  ) {
    return this.audit.log(
      tenantId,
      actor.id,
      actor.role,
      AuditAction.EI_BILLING_QUEUE_TRANSITION,
      'EiBillingRecord',
      recordId,
      { from, to },
      childId,
    );
  }
}
