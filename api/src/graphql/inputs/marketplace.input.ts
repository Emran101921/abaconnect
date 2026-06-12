import { Field, ID, InputType } from '@nestjs/graphql';
import { IsBoolean, IsOptional, IsString, MinLength } from 'class-validator';
import {
  MarketplaceAuthorizationStatus,
  MarketplaceLocationType,
  MarketplaceUrgency,
} from '../../../generated/prisma/client';

@InputType()
export class CreateMarketplaceRequestInput {
  @Field(() => ID)
  childId!: string;

  @Field(() => ID, { nullable: true })
  screeningResponseId?: string;

  @Field()
  anonymousConsentGranted!: boolean;

  @Field(() => MarketplaceLocationType)
  locationType!: MarketplaceLocationType;

  @Field({ nullable: true })
  languagePreference?: string;

  @Field(() => MarketplaceUrgency, { nullable: true })
  urgency?: MarketplaceUrgency;

  @Field({ nullable: true })
  publicDescription?: string;
}

@InputType()
export class MarketplaceBrowseInput {
  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  zipCode?: string;

  @Field({ nullable: true })
  @IsOptional()
  radiusMiles?: number;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  serviceCategory?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  ageRange?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  language?: string;

  @Field(() => MarketplaceLocationType, { nullable: true })
  @IsOptional()
  locationType?: MarketplaceLocationType;

  @Field(() => MarketplaceUrgency, { nullable: true })
  @IsOptional()
  urgency?: MarketplaceUrgency;

  @Field(() => MarketplaceAuthorizationStatus, { nullable: true })
  @IsOptional()
  authorizationStatus?: MarketplaceAuthorizationStatus;
}

@InputType()
export class SubmitMarketplaceInterestInput {
  @Field(() => ID)
  marketplaceRequestId!: string;

  @Field({ nullable: true })
  message?: string;
}

@InputType()
export class GrantMarketplaceShareConsentInput {
  @Field(() => ID)
  marketplaceRequestId!: string;

  @Field(() => ID)
  providerProfileId!: string;
}

@InputType()
export class RevokeMarketplaceConsentInput {
  @Field(() => ID)
  marketplaceRequestId!: string;

  @Field(() => ID)
  providerProfileId!: string;
}

@InputType()
export class CompleteProviderMarketplaceOnboardingInput {
  @Field()
  accountType!: string;

  @Field()
  legalName!: string;

  @Field()
  displayName!: string;

  @Field({ nullable: true })
  licenseNumber?: string;

  @Field({ nullable: true })
  npi?: string;

  @Field(() => [String])
  serviceCategories!: string[];

  @Field(() => [String])
  coverageZipCodes!: string[];

  @Field(() => [String])
  languages!: string[];

  @Field()
  confidentialityTermsAccepted!: boolean;
}

@InputType()
export class SaveMarketplaceSearchInput {
  @Field()
  @IsString()
  @MinLength(1)
  name!: string;

  @Field(() => MarketplaceBrowseInput)
  filters!: MarketplaceBrowseInput;

  @Field({ nullable: true })
  @IsOptional()
  @IsBoolean()
  alertsEnabled?: boolean;
}

@InputType()
export class SetMarketplaceSavedSearchAlertsInput {
  @Field(() => ID)
  savedSearchId!: string;

  @Field()
  @IsBoolean()
  alertsEnabled!: boolean;
}
