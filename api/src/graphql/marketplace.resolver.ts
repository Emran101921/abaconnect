import { Args, ID, Mutation, Query, Resolver } from '@nestjs/graphql';
import { Req } from '@nestjs/common';
import type { Request } from 'express';
import { Roles } from '../common/decorators/roles.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { MarketplaceService } from '../marketplace/marketplace.service';
import { toPublicMarketplaceRequest } from '../marketplace/marketplace-privacy.util';
import {
  CompleteProviderMarketplaceOnboardingInput,
  CreateMarketplaceRequestInput,
  GrantMarketplaceShareConsentInput,
  MarketplaceBrowseInput,
  RevokeMarketplaceConsentInput,
  SaveMarketplaceSearchInput,
  SetMarketplaceSavedSearchAlertsInput,
  SubmitMarketplaceInterestInput,
} from './inputs/marketplace.input';
import {
  AuthorizedChildDetailsType,
  MarketplaceConsentRecordType,
  MarketplaceInterestType,
  MarketplaceSavedSearchType,
  ProviderMarketplaceProfileType,
  PublicMarketplaceRequestType,
} from './types/marketplace.types';
import { parseSavedSearchFilters } from '../marketplace/marketplace-saved-search.util';

function ctx(req: Request) {
  return {
    ipAddress: req.ip,
    userAgent: req.headers['user-agent'] as string | undefined,
    deviceInfo: req.headers['x-device-id'] as string | undefined,
  };
}

@Resolver()
export class MarketplaceResolver {
  constructor(private readonly marketplace: MarketplaceService) {}

  @Mutation(() => PublicMarketplaceRequestType, {
    name: 'createMarketplaceRequest',
  })
  @Roles('PARENT')
  async createMarketplaceRequest(
    @CurrentUser() user: AuthUser,
    @Args('input') input: CreateMarketplaceRequestInput,
    @Req() req: Request,
  ) {
    const row = await this.marketplace.createMarketplaceRequestForParent(
      user.id,
      input.childId,
      input,
      ctx(req),
    );
    return { ...toPublicMarketplaceRequest(row), interestCount: 0 };
  }

  @Query(() => [PublicMarketplaceRequestType], {
    name: 'myMarketplaceRequests',
  })
  @Roles('PARENT')
  myMarketplaceRequests(@CurrentUser() user: AuthUser) {
    return this.marketplace.listParentRequests(user.id);
  }

  @Query(() => [MarketplaceInterestType], {
    name: 'marketplaceRequestInterests',
  })
  @Roles('PARENT')
  marketplaceRequestInterests(
    @CurrentUser() user: AuthUser,
    @Args('marketplaceRequestId', { type: () => ID })
    marketplaceRequestId: string,
  ) {
    return this.marketplace.listRequestInterestsForParent(
      user.id,
      marketplaceRequestId,
    );
  }

  @Query(() => ProviderMarketplaceProfileType, {
    name: 'myProviderMarketplaceProfile',
    nullable: true,
  })
  @Roles('THERAPIST', 'AGENCY_ADMIN')
  myProviderMarketplaceProfile(@CurrentUser() user: AuthUser) {
    return this.marketplace.getProviderProfile(user.id);
  }

  @Mutation(() => ProviderMarketplaceProfileType, {
    name: 'completeProviderMarketplaceOnboarding',
  })
  @Roles('THERAPIST', 'AGENCY_ADMIN')
  completeProviderMarketplaceOnboarding(
    @CurrentUser() user: AuthUser,
    @Args('input') input: CompleteProviderMarketplaceOnboardingInput,
  ) {
    return this.marketplace.upsertProviderProfile(
      user.id,
      user.tenantId ?? '',
      {
        accountType: input.accountType as 'THERAPIST' | 'AGENCY',
        legalName: input.legalName,
        displayName: input.displayName,
        licenseNumber: input.licenseNumber,
        npi: input.npi,
        serviceCategories: input.serviceCategories,
        coverageZipCodes: input.coverageZipCodes,
        languages: input.languages,
        confidentialityTermsAccepted: input.confidentialityTermsAccepted,
      },
    );
  }

  @Mutation(() => Boolean, { name: 'pauseMarketplaceRequest' })
  @Roles('PARENT')
  async pauseMarketplaceRequest(
    @CurrentUser() user: AuthUser,
    @Args('marketplaceRequestId', { type: () => ID })
    marketplaceRequestId: string,
  ) {
    await this.marketplace.pauseRequest(user.id, marketplaceRequestId);
    return true;
  }

  @Mutation(() => Boolean, { name: 'closeMarketplaceRequest' })
  @Roles('PARENT')
  async closeMarketplaceRequest(
    @CurrentUser() user: AuthUser,
    @Args('marketplaceRequestId', { type: () => ID })
    marketplaceRequestId: string,
  ) {
    await this.marketplace.closeRequest(user.id, marketplaceRequestId);
    return true;
  }

  @Query(() => [PublicMarketplaceRequestType], {
    name: 'browseMarketplaceRequests',
  })
  @Roles('THERAPIST', 'AGENCY_ADMIN')
  async browseMarketplaceRequests(
    @CurrentUser() user: AuthUser,
    @Args('input', { nullable: true }) input: MarketplaceBrowseInput,
    @Req() req: Request,
  ) {
    const result = await this.marketplace.browsePublicRequestsForProvider(
      user.id,
      input ?? {},
      ctx(req),
    );
    return result.items;
  }

  @Mutation(() => Boolean, { name: 'submitMarketplaceInterest' })
  @Roles('THERAPIST', 'AGENCY_ADMIN')
  async submitMarketplaceInterest(
    @CurrentUser() user: AuthUser,
    @Args('input') input: SubmitMarketplaceInterestInput,
    @Req() req: Request,
  ) {
    await this.marketplace.submitProviderInterest(
      user.id,
      input.marketplaceRequestId,
      { message: input.message },
      ctx(req),
    );
    return true;
  }

  @Mutation(() => Boolean, { name: 'grantMarketplaceShareConsent' })
  @Roles('PARENT')
  async grantMarketplaceShareConsent(
    @CurrentUser() user: AuthUser,
    @Args('input') input: GrantMarketplaceShareConsentInput,
    @Req() req: Request,
  ) {
    await this.marketplace.grantShareConsent(
      user.id,
      input.marketplaceRequestId,
      input.providerProfileId,
      ctx(req),
      input.documentIds ?? [],
    );
    return true;
  }

  @Mutation(() => Boolean, { name: 'revokeMarketplaceShareConsent' })
  @Roles('PARENT')
  async revokeMarketplaceShareConsent(
    @CurrentUser() user: AuthUser,
    @Args('input') input: RevokeMarketplaceConsentInput,
    @Req() req: Request,
  ) {
    await this.marketplace.revokeConsent(
      user.id,
      input.marketplaceRequestId,
      input.providerProfileId,
      ctx(req),
    );
    return true;
  }

  @Query(() => [MarketplaceConsentRecordType], {
    name: 'marketplaceConsentHistory',
  })
  @Roles('PARENT')
  marketplaceConsentHistory(
    @CurrentUser() user: AuthUser,
    @Args('marketplaceRequestId', { type: () => ID })
    marketplaceRequestId: string,
  ) {
    return this.marketplace.listConsentHistoryForParent(
      user.id,
      marketplaceRequestId,
    );
  }

  @Query(() => AuthorizedChildDetailsType, {
    name: 'authorizedMarketplaceChildDetails',
    nullable: true,
  })
  @Roles('THERAPIST', 'AGENCY_ADMIN')
  async authorizedMarketplaceChildDetails(
    @CurrentUser() user: AuthUser,
    @Args('marketplaceRequestId', { type: () => ID })
    marketplaceRequestId: string,
    @Req() req: Request,
  ) {
    const details = await this.marketplace.getAuthorizedChildDetailsForProvider(
      user.id,
      marketplaceRequestId,
      ctx(req),
    );
    return {
      childId: details.child.id,
      firstName: details.child.firstName,
      lastName: details.child.lastName,
      zipCode: details.child.zipCode ?? '',
      city: details.child.city ?? undefined,
      state: details.child.state ?? undefined,
      primaryLanguage: details.child.primaryLanguage ?? undefined,
      parentName: details.parentContact.name,
      parentEmail: details.parentContact.email ?? undefined,
      parentPhone: details.parentContact.phone ?? undefined,
      marketplaceRequestId: details.marketplaceRequestId,
      anonymousPublicId: details.anonymousPublicId,
      sharedDocuments: details.sharedDocuments ?? [],
    };
  }

  @Query(() => [MarketplaceSavedSearchType], {
    name: 'myMarketplaceSavedSearches',
  })
  @Roles('THERAPIST', 'AGENCY_ADMIN')
  async myMarketplaceSavedSearches(@CurrentUser() user: AuthUser) {
    const rows = await this.marketplace.listProviderSavedSearches(user.id);
    return rows.map((row) => this.mapSavedSearch(row));
  }

  @Mutation(() => MarketplaceSavedSearchType, {
    name: 'saveMarketplaceSearch',
  })
  @Roles('THERAPIST', 'AGENCY_ADMIN')
  async saveMarketplaceSearch(
    @CurrentUser() user: AuthUser,
    @Args('input') input: SaveMarketplaceSearchInput,
  ) {
    const row = await this.marketplace.saveProviderSearch(user.id, input);
    return this.mapSavedSearch(row);
  }

  @Mutation(() => Boolean, { name: 'deleteMarketplaceSavedSearch' })
  @Roles('THERAPIST', 'AGENCY_ADMIN')
  async deleteMarketplaceSavedSearch(
    @CurrentUser() user: AuthUser,
    @Args('savedSearchId', { type: () => ID }) savedSearchId: string,
  ) {
    await this.marketplace.deleteProviderSavedSearch(user.id, savedSearchId);
    return true;
  }

  @Mutation(() => MarketplaceSavedSearchType, {
    name: 'setMarketplaceSavedSearchAlerts',
  })
  @Roles('THERAPIST', 'AGENCY_ADMIN')
  async setMarketplaceSavedSearchAlerts(
    @CurrentUser() user: AuthUser,
    @Args('input') input: SetMarketplaceSavedSearchAlertsInput,
  ) {
    const row = await this.marketplace.setSavedSearchAlerts(
      user.id,
      input.savedSearchId,
      input.alertsEnabled,
    );
    return this.mapSavedSearch(row);
  }

  private mapSavedSearch(row: {
    id: string;
    name: string;
    alertsEnabled: boolean;
    createdAt: Date;
    filters: unknown;
  }): MarketplaceSavedSearchType {
    const filters = parseSavedSearchFilters(row.filters);
    return {
      id: row.id,
      name: row.name,
      alertsEnabled: row.alertsEnabled,
      createdAt: row.createdAt,
      zipCode: filters.zipCode,
      radiusMiles: filters.radiusMiles,
      serviceCategory: filters.serviceCategory,
      ageRange: filters.ageRange,
      language: filters.language,
      locationType: filters.locationType,
      urgency: filters.urgency,
      authorizationStatus: filters.authorizationStatus,
    };
  }
}
