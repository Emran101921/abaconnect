import {
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { UserRole } from '../../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';

export interface EiBillingActor {
  id: string;
  tenantId: string;
  role: UserRole;
  agencyId?: string | null;
  therapistId?: string | null;
}

export async function resolveEiBillingActor(
  prisma: PrismaService,
  userId: string,
  tenantId: string,
): Promise<EiBillingActor> {
  const user = await prisma.user.findFirst({
    where: { id: userId, tenantId },
    include: { therapist: { select: { id: true } } },
  });
  if (!user) {
    throw new NotFoundException('User not found');
  }
  return {
    id: user.id,
    tenantId: user.tenantId,
    role: user.role,
    agencyId: user.agencyId,
    therapistId: user.therapist?.id,
  };
}

export function assertEiBillingRole(
  actor: EiBillingActor,
  allowed: UserRole[],
): void {
  if (!allowed.includes(actor.role)) {
    throw new ForbiddenException('Insufficient role for NY EI billing action');
  }
}

export async function resolveAgencyIdForActor(
  prisma: PrismaService,
  actor: EiBillingActor,
  agencyId?: string,
): Promise<string> {
  if (actor.role === 'PLATFORM_ADMIN') {
    if (!agencyId) {
      throw new ForbiddenException('agencyId required for platform admin');
    }
    const agency = await prisma.agency.findFirst({
      where: { id: agencyId, tenantId: actor.tenantId },
    });
    if (!agency) {
      throw new NotFoundException('Agency not found');
    }
    return agency.id;
  }

  if (actor.role === 'BILLING_STAFF' || actor.role === 'AGENCY_ADMIN') {
    if (!actor.agencyId) {
      throw new ForbiddenException('User is not linked to an agency');
    }
    return actor.agencyId;
  }

  throw new ForbiddenException('Agency context unavailable for this role');
}
