import { Controller, Get, Param, Post, Query } from '@nestjs/common';
import { AuditAction } from '../../generated/prisma/client';
import { Roles } from '../common/decorators/roles.decorator';
import { Permissions } from '../common/decorators/permissions.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { AuditService } from '../audit/audit.service';
import { SecurityEventService } from '../security/security-event.service';
import { Permission } from '../security/permissions';
import { AdminSecurityService } from './admin-security.service';
import { ComplianceService } from './compliance.service';

@Controller('admin/security')
@Roles('PLATFORM_ADMIN', 'AGENCY_ADMIN', 'COMPLIANCE_AUDITOR')
export class AdminSecurityController {
  constructor(
    private readonly adminSecurity: AdminSecurityService,
    private readonly audit: AuditService,
    private readonly securityEvents: SecurityEventService,
    private readonly compliance: ComplianceService,
  ) {}

  @Get('dashboard')
  @Permissions(Permission.COMPLIANCE_READ, Permission.AUDIT_READ)
  async dashboard(@CurrentUser() user: AuthUser) {
    return this.adminSecurity.getDashboard(user.tenantId ?? '');
  }

  @Get('audit-logs/search')
  @Permissions(Permission.AUDIT_READ, Permission.AUDIT_SEARCH)
  searchAuditLogs(
    @CurrentUser() user: AuthUser,
    @Query('action') action?: AuditAction,
    @Query('actorId') actorId?: string,
    @Query('patientId') patientId?: string,
    @Query('entityType') entityType?: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
  ) {
    return this.audit.searchForTenant(user.tenantId ?? '', {
      action,
      actorId,
      patientId,
      entityType,
      from: from ? new Date(from) : undefined,
      to: to ? new Date(to) : undefined,
    });
  }

  @Post('users/:id/disable')
  @Roles('PLATFORM_ADMIN', 'AGENCY_ADMIN')
  @Permissions(Permission.USER_DISABLE)
  disableUser(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.adminSecurity.disableUser(user, id);
  }

  @Post('users/:id/force-password-reset')
  @Roles('PLATFORM_ADMIN', 'AGENCY_ADMIN')
  @Permissions(Permission.USER_MANAGE)
  forcePasswordReset(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.adminSecurity.forcePasswordReset(user, id);
  }

  @Post('users/:id/reset-mfa')
  @Roles('PLATFORM_ADMIN', 'AGENCY_ADMIN')
  @Permissions(Permission.USER_MANAGE)
  resetMfa(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.adminSecurity.resetMfa(user, id);
  }

  @Get('retention')
  @Permissions(Permission.COMPLIANCE_READ)
  retention(@CurrentUser() user: AuthUser) {
    return this.compliance.summarizeRetentionStatus(user.tenantId ?? '');
  }

  @Get('security-events')
  @Permissions(Permission.AUDIT_READ)
  listSecurityEvents(@CurrentUser() user: AuthUser) {
    return this.securityEvents.listForTenant(user.tenantId ?? '', 100);
  }
}
