import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import { Roles } from '../common/decorators/roles.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import {
  CreateNoticeVersionDto,
  UpdatePrivacyRequestStatusDto,
} from './dto/privacy.dto';
import { PrivacyNoticeService } from './privacy-notice.service';
import { PrivacyRightsRequestStatus } from '../../generated/prisma/client';
import { PrivacyRightsService } from './privacy-rights.service';
import { ComplianceDocumentType } from '../../generated/prisma/client';
import { AuditService } from '../audit/audit.service';
import { SecurityEventService } from '../security/security-event.service';
import { ComplianceDocumentsService } from './compliance-documents.service';

@Controller('admin/compliance')
@Roles('PLATFORM_ADMIN')
export class AdminComplianceController {
  constructor(
    private readonly notices: PrivacyNoticeService,
    private readonly rights: PrivacyRightsService,
    private readonly audit: AuditService,
    private readonly securityEvents: SecurityEventService,
    private readonly legalDocuments: ComplianceDocumentsService,
  ) {}

  @Get('acknowledgments')
  listAcknowledgments(
    @CurrentUser() user: AuthUser,
    @Query('email') email?: string,
  ) {
    return this.notices.listAcknowledgmentsForTenant(user.tenantId ?? '', {
      email,
    });
  }

  @Get('notice-versions')
  listNoticeVersions(@CurrentUser() user: AuthUser) {
    return this.notices.listNoticeVersions(user.tenantId);
  }

  @Post('notice-versions')
  createNoticeVersion(
    @CurrentUser() user: AuthUser,
    @Body() dto: CreateNoticeVersionDto,
  ) {
    return this.notices.createNoticeVersion(user.id, user.tenantId ?? null, {
      versionNumber: dto.versionNumber,
      title: dto.title,
      fullNoticeText: dto.fullNoticeText,
      privacyPolicyText: dto.privacyPolicyText,
      effectiveDate: dto.effectiveDate
        ? new Date(dto.effectiveDate)
        : undefined,
      publish: dto.publish,
    });
  }

  @Patch('notice-versions/:id/publish')
  publishNoticeVersion(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.notices.publishNoticeVersion(user.id, id);
  }

  @Get('privacy-requests')
  listPrivacyRequests(
    @CurrentUser() user: AuthUser,
    @Query('status') status?: PrivacyRightsRequestStatus,
  ) {
    return this.rights.listForTenant(user.tenantId ?? '', status);
  }

  @Patch('privacy-requests/:id')
  updatePrivacyRequest(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: UpdatePrivacyRequestStatusDto,
  ) {
    return this.rights.updateStatus(user.id, user.tenantId ?? '', id, dto);
  }

  @Get('audit-logs')
  listPrivacyAuditLogs(@CurrentUser() user: AuthUser) {
    return this.audit.findAllForTenant(user.tenantId ?? '', 100);
  }

  @Get('security-events')
  listSecurityEvents(@CurrentUser() user: AuthUser) {
    return this.securityEvents.listForTenant(user.tenantId ?? '', 100);
  }

  @Post('legal-documents')
  createLegalDocument(
    @CurrentUser() user: AuthUser,
    @Body()
    dto: {
      documentType: ComplianceDocumentType;
      version: string;
      title: string;
      content: string;
      effectiveDate?: string;
      publish?: boolean;
    },
  ) {
    return this.legalDocuments.createVersion(user.id, user.tenantId ?? null, {
      documentType: dto.documentType,
      version: dto.version,
      title: dto.title,
      content: dto.content,
      effectiveDate: dto.effectiveDate
        ? new Date(dto.effectiveDate)
        : undefined,
      publish: dto.publish,
    });
  }

  @Patch('legal-documents/:id/publish')
  publishLegalDocument(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.legalDocuments.publishVersion(
      user.id,
      id,
      user.tenantId ?? null,
    );
  }
}
