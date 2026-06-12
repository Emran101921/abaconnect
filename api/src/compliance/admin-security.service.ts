import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { AuditAction } from '../../generated/prisma/client';
import { AuditService } from '../audit/audit.service';
import { PrismaService } from '../prisma/prisma.service';
import { AuthUser } from '../common/decorators/current-user.decorator';
@Injectable()
export class AdminSecurityService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  async getDashboard(tenantId: string) {
    const [
      activeUsers,
      inactiveUsers,
      failedLogins24h,
      recentPhiAccess,
      claimSubmissions7d,
      securityAlerts,
    ] = await Promise.all([
      this.prisma.user.count({ where: { tenantId, isActive: true } }),
      this.prisma.user.count({ where: { tenantId, isActive: false } }),
      this.prisma.securityEvent.count({
        where: {
          tenantId,
          eventType: 'LOGIN_FAILED',
          createdAt: { gte: new Date(Date.now() - 86_400_000) },
        },
      }),
      this.audit.findAllForTenant(tenantId, 20),
      this.prisma.auditLog.count({
        where: {
          tenantId,
          action: {
            in: [AuditAction.CLAIM_SUBMITTED, AuditAction.CLAIM_RESUBMITTED],
          },
          createdAt: { gte: new Date(Date.now() - 7 * 86_400_000) },
        },
      }),
      this.prisma.securityEvent.findMany({
        where: {
          tenantId,
          severity: { in: ['WARNING', 'CRITICAL'] },
        },
        orderBy: { createdAt: 'desc' },
        take: 10,
      }),
    ]);

    const phiReads = recentPhiAccess.filter(
      (row) =>
        (row.metadata as { phi?: boolean })?.phi === true ||
        row.action === AuditAction.READ,
    );

    return {
      activeUsers,
      inactiveUsers,
      failedLogins24h,
      claimSubmissions7d,
      recentPhiAccess: phiReads.slice(0, 10),
      securityAlerts,
      backupStatus: {
        note: 'Configure automated backups in HIPAA-eligible cloud (see docs/hipaa/HOSTING.md)',
        lastVerifiedAt: null,
      },
    };
  }

  async disableUser(actor: AuthUser, targetUserId: string) {
    const target = await this.prisma.user.findFirst({
      where: { id: targetUserId, tenantId: actor.tenantId },
    });
    if (!target) throw new NotFoundException('User not found');
    if (target.id === actor.id) {
      throw new ForbiddenException('Cannot disable your own account');
    }

    const updated = await this.prisma.user.update({
      where: { id: targetUserId },
      data: {
        isActive: false,
        tokenVersion: { increment: 1 },
      },
    });

    await this.audit.log({
      tenantId: actor.tenantId ?? '',
      actorId: actor.id,
      action: AuditAction.USER_DISABLED,
      resourceType: 'User',
      resourceId: targetUserId,
      metadata: { email: target.email, role: target.role },
    });

    return { id: updated.id, isActive: updated.isActive };
  }

  async forcePasswordReset(actor: AuthUser, targetUserId: string) {
    const target = await this.prisma.user.findFirst({
      where: { id: targetUserId, tenantId: actor.tenantId },
    });
    if (!target) throw new NotFoundException('User not found');

    const updated = await this.prisma.user.update({
      where: { id: targetUserId },
      data: { tokenVersion: { increment: 1 } },
    });

    await this.audit.log({
      tenantId: actor.tenantId ?? '',
      actorId: actor.id,
      action: AuditAction.PERMISSION_CHANGED,
      resourceType: 'User',
      resourceId: targetUserId,
      metadata: { action: 'force_password_reset' },
    });

    return {
      id: updated.id,
      message: 'User sessions revoked; password reset required on next login',
    };
  }

  async resetMfa(actor: AuthUser, targetUserId: string) {
    const target = await this.prisma.user.findFirst({
      where: { id: targetUserId, tenantId: actor.tenantId },
    });
    if (!target) throw new NotFoundException('User not found');

    await this.prisma.user.update({
      where: { id: targetUserId },
      data: {
        mfaEnabled: false,
        mfaSecret: null,
        tokenVersion: { increment: 1 },
      },
    });

    await this.audit.log({
      tenantId: actor.tenantId ?? '',
      actorId: actor.id,
      action: AuditAction.PERMISSION_CHANGED,
      resourceType: 'User',
      resourceId: targetUserId,
      metadata: { action: 'mfa_reset' },
    });

    return { id: targetUserId, mfaEnabled: false };
  }
}
