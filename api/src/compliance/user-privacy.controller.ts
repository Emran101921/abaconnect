import { Body, Controller, Get, Post, Req } from '@nestjs/common';
import type { Request } from 'express';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { AcknowledgeNoticeDto, SubmitPrivacyRightsRequestDto } from './dto/privacy.dto';
import { PrivacyClientContext, PrivacyNoticeService } from './privacy-notice.service';
import { PrivacyRightsService } from './privacy-rights.service';

function clientContext(req: Request, body?: AcknowledgeNoticeDto): PrivacyClientContext {
  return {
    ipAddress: req.ip,
    userAgent: req.headers['user-agent'] as string | undefined,
    appVersion: body?.appVersion,
    platform: body?.platform,
    deviceId: body?.deviceId ?? (req.headers['x-device-id'] as string | undefined),
  };
}

@Controller('compliance/me/privacy')
export class UserPrivacyController {
  constructor(
    private readonly notices: PrivacyNoticeService,
    private readonly rights: PrivacyRightsService,
  ) {}

  @Get('notice/summary')
  @Roles('PARENT', 'THERAPIST', 'AGENCY_ADMIN', 'PLATFORM_ADMIN')
  getSummary(@CurrentUser() user: AuthUser) {
    return this.notices.getActiveNoticeSummary(user.tenantId);
  }

  @Get('notice/full')
  @Roles('PARENT', 'THERAPIST', 'AGENCY_ADMIN', 'PLATFORM_ADMIN')
  async getFullNotice(@CurrentUser() user: AuthUser, @Req() req: Request) {
    await this.notices.logNoticeViewed(
      user.id,
      'notice_of_privacy_practices',
      clientContext(req),
    );
    return this.notices.getFullNotice(user.tenantId);
  }

  @Get('policy')
  @Roles('PARENT', 'THERAPIST', 'AGENCY_ADMIN', 'PLATFORM_ADMIN')
  async getPolicy(@CurrentUser() user: AuthUser, @Req() req: Request) {
    await this.notices.logNoticeViewed(user.id, 'privacy_policy', clientContext(req));
    return this.notices.getPrivacyPolicy(user.tenantId);
  }

  @Get('acknowledgment-status')
  @Roles('PARENT', 'THERAPIST', 'AGENCY_ADMIN', 'PLATFORM_ADMIN')
  getAckStatus(@CurrentUser() user: AuthUser) {
    return this.notices.getAcknowledgmentStatus(user.id, user.tenantId ?? '');
  }

  @Post('acknowledge')
  @Roles('PARENT', 'THERAPIST', 'AGENCY_ADMIN', 'PLATFORM_ADMIN')
  acknowledge(
    @CurrentUser() user: AuthUser,
    @Body() dto: AcknowledgeNoticeDto,
    @Req() req: Request,
  ) {
    return this.notices.acknowledgeNotice(user.id, clientContext(req, dto));
  }

  @Get('acknowledgment/download')
  @Roles('PARENT', 'THERAPIST', 'AGENCY_ADMIN', 'PLATFORM_ADMIN')
  async downloadAcknowledgment(@CurrentUser() user: AuthUser) {
    const status = await this.notices.getAcknowledgmentStatus(
      user.id,
      user.tenantId ?? '',
    );
    const acknowledgment = await this.notices.getLatestAcknowledgment(user.id);
    return { status, acknowledgment };
  }

  @Post('rights-requests')
  @Roles('PARENT', 'THERAPIST', 'AGENCY_ADMIN')
  submitRightsRequest(
    @CurrentUser() user: AuthUser,
    @Body() dto: SubmitPrivacyRightsRequestDto,
    @Req() req: Request,
  ) {
    return this.rights.submitRequest(
      user.id,
      dto.requestType,
      dto.payload,
      { ipAddress: req.ip, userAgent: req.headers['user-agent'] as string },
    );
  }

  @Get('rights-requests')
  @Roles('PARENT', 'THERAPIST', 'AGENCY_ADMIN')
  listRightsRequests(@CurrentUser() user: AuthUser) {
    return this.rights.listForUser(user.id);
  }
}
