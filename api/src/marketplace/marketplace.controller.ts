import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  Req,
} from '@nestjs/common';
import type { Request } from 'express';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { Throttle } from '@nestjs/throttler';
import { MarketplaceService } from './marketplace.service';
import {
  AdminSuspendUserDto,
  CreateMarketplaceRequestDto,
  GrantShareConsentDto,
  ProviderInterestDto,
  ProviderOnboardingDto,
  ReportMarketplaceListingDto,
  RevokeConsentDto,
} from './dto/marketplace.dto';

function requestContext(req: Request) {
  return {
    ipAddress: req.ip,
    userAgent: req.headers['user-agent'] as string | undefined,
    deviceInfo: req.headers['x-device-id'] as string | undefined,
  };
}

@Controller()
export class MarketplaceController {
  constructor(private readonly marketplace: MarketplaceService) {}

  @Post('children/:childId/marketplace-request')
  @Roles('PARENT')
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  createRequest(
    @CurrentUser() user: AuthUser,
    @Param('childId') childId: string,
    @Body() body: CreateMarketplaceRequestDto,
    @Req() req: Request,
  ) {
    return this.marketplace.createMarketplaceRequestForParent(
      user.id,
      childId,
      body,
      requestContext(req),
    );
  }

  @Get('parent/marketplace-requests')
  @Roles('PARENT')
  listParentRequests(@CurrentUser() user: AuthUser) {
    return this.marketplace.listParentRequests(user.id);
  }

  @Get('parent/marketplace-requests/:id/interests')
  @Roles('PARENT')
  listInterests(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
  ) {
    return this.marketplace.listRequestInterestsForParent(user.id, id);
  }

  @Get('parent/marketplace-requests/:id/consents')
  @Roles('PARENT')
  listConsents(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
  ) {
    return this.marketplace.listConsentHistoryForParent(user.id, id);
  }

  @Post('marketplace-requests/:id/consent/share-with-provider')
  @Roles('PARENT')
  grantConsent(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() body: GrantShareConsentDto,
    @Req() req: Request,
  ) {
    return this.marketplace.grantShareConsent(
      user.id,
      id,
      body.providerProfileId,
      requestContext(req),
    );
  }

  @Post('marketplace-requests/:id/revoke-consent')
  @Roles('PARENT')
  revokeConsent(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() body: RevokeConsentDto,
    @Req() req: Request,
  ) {
    return this.marketplace.revokeConsent(
      user.id,
      id,
      body.providerProfileId,
      requestContext(req),
    );
  }

  @Post('marketplace-requests/:id/pause')
  @Roles('PARENT')
  pause(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.marketplace.pauseRequest(user.id, id);
  }

  @Post('marketplace-requests/:id/close')
  @Roles('PARENT')
  close(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.marketplace.closeRequest(user.id, id);
  }

  @Post('marketplace-requests/:id/report')
  @Roles('PARENT', 'THERAPIST', 'AGENCY_ADMIN')
  reportListing(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() body: ReportMarketplaceListingDto,
  ) {
    return this.marketplace.reportListing(user.id, id, body);
  }

  @Get('marketplace-requests')
  @Roles('THERAPIST', 'AGENCY_ADMIN')
  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  browse(
    @CurrentUser() user: AuthUser,
    @Query('zipCode') zipCode?: string,
    @Query('radiusMiles') radiusMiles?: string,
    @Query('serviceCategory') serviceCategory?: string,
    @Query('ageRange') ageRange?: string,
    @Query('language') language?: string,
    @Query('locationType') locationType?: string,
    @Query('authorizationStatus') authorizationStatus?: string,
    @Query('urgency') urgency?: string,
    @Query('page') page?: string,
    @Query('pageSize') pageSize?: string,
    @Req() req?: Request,
  ) {
    return this.marketplace.browsePublicRequestsForProvider(
      user.id,
      {
        zipCode,
        radiusMiles: radiusMiles ? Number(radiusMiles) : undefined,
        serviceCategory,
        ageRange,
        language,
        locationType: locationType as never,
        authorizationStatus: authorizationStatus as never,
        urgency: urgency as never,
        page: page ? Number(page) : 1,
        pageSize: pageSize ? Number(pageSize) : 20,
      },
      requestContext(req!),
    );
  }

  @Get('marketplace-requests/map')
  @Roles('THERAPIST', 'AGENCY_ADMIN')
  mapView(
    @CurrentUser() user: AuthUser,
    @Query('zipCode') zipCode?: string,
    @Query('radiusMiles') radiusMiles?: string,
    @Req() req?: Request,
  ) {
    return this.marketplace
      .browsePublicRequestsForProvider(
        user.id,
        {
          zipCode,
          radiusMiles: radiusMiles ? Number(radiusMiles) : 25,
          pageSize: 50,
        },
        requestContext(req!),
      )
      .then((result) => ({
        pins: result.items
          .filter((item) => item.mapPinLat && item.mapPinLng)
          .map((item) => ({
            requestId: item.id,
            anonymousPublicId: item.anonymousPublicId,
            lat: item.mapPinLat,
            lng: item.mapPinLng,
            serviceAreaLabel: item.serviceAreaLabel,
            ageRangeLabel: item.ageRangeLabel,
            serviceCategories: item.serviceCategories,
          })),
      }));
  }

  @Get('marketplace-requests/:id/public')
  @Roles('THERAPIST', 'AGENCY_ADMIN')
  getPublic(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Req() req: Request,
  ) {
    return this.marketplace.getPublicRequestForProvider(
      user.id,
      id,
      requestContext(req),
    );
  }

  @Post('marketplace-requests/:id/interests')
  @Roles('THERAPIST', 'AGENCY_ADMIN')
  submitInterest(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() body: ProviderInterestDto,
    @Req() req: Request,
  ) {
    return this.marketplace.submitProviderInterest(
      user.id,
      id,
      body,
      requestContext(req),
    );
  }

  @Get('provider/authorized-child-details/:marketplaceRequestId')
  @Roles('THERAPIST', 'AGENCY_ADMIN')
  authorizedChildDetails(
    @CurrentUser() user: AuthUser,
    @Param('marketplaceRequestId') marketplaceRequestId: string,
    @Req() req: Request,
  ) {
    return this.marketplace.getAuthorizedChildDetailsForProvider(
      user.id,
      marketplaceRequestId,
      requestContext(req),
    );
  }

  @Post('provider/marketplace-onboarding')
  @Roles('THERAPIST', 'AGENCY_ADMIN')
  providerOnboarding(
    @CurrentUser() user: AuthUser,
    @Body() body: ProviderOnboardingDto,
  ) {
    return this.marketplace.upsertProviderProfile(
      user.id,
      user.tenantId ?? '',
      body,
    );
  }

  @Get('admin/marketplace-requests')
  @Roles('PLATFORM_ADMIN')
  adminList(@CurrentUser() user: AuthUser) {
    return this.marketplace.adminListRequests(user.tenantId ?? '');
  }

  @Post('admin/marketplace-requests/:id/remove')
  @Roles('PLATFORM_ADMIN')
  adminRemove(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body('reason') reason: string,
  ) {
    return this.marketplace.adminRemoveListing(
      user.id,
      id,
      reason ?? 'Removed by admin',
    );
  }

  @Get('admin/audit-logs')
  @Roles('PLATFORM_ADMIN')
  adminAuditLogs(@CurrentUser() user: AuthUser) {
    return this.marketplace.adminMarketplaceAuditLogs(user.tenantId ?? '');
  }

  @Post('admin/users/:id/suspend')
  @Roles('PLATFORM_ADMIN')
  adminSuspendUser(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() body: AdminSuspendUserDto,
  ) {
    return this.marketplace.adminSuspendUser(user.id, id, body.reason);
  }

  @Post('admin/provider-agency/:id/verify')
  @Roles('PLATFORM_ADMIN')
  adminVerifyProvider(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
  ) {
    return this.marketplace.adminVerifyProvider(user.id, id);
  }
}
