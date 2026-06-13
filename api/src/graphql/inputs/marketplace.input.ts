import { Field, ID, InputType } from '@nestjs/graphql';
import {
  IsArray,
  IsBoolean,
  IsEnum,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  MinLength,
} from 'class-validator';
import {
  MarketplaceAuthorizationStatus,
  MarketplaceLocationType,
  MarketplaceUrgency,
} from '../../../generated/prisma/client';

@InputType()
export class CreateMarketplaceRequestInput {
  @Field(() => ID)
  @IsUUID()
  childId!: string;

  @Field(() => ID, { nullable: true })
  @IsOptional()
  @IsUUID()
  screeningResponseId?: string;

  @Field()
  @IsBoolean()
  anonymousConsentGranted!: boolean;

  @Field(() => MarketplaceLocationType)
  @IsEnum(MarketplaceLocationType)
  locationType!: MarketplaceLocationType;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  languagePreference?: string;

  @Field(() => MarketplaceUrgency, { nullable: true })
  @IsOptional()
  @IsEnum(MarketplaceUrgency)
  urgency?: MarketplaceUrgency;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
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
  @IsNumber()
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
  @IsEnum(MarketplaceLocationType)
  locationType?: MarketplaceLocationType;

  @Field(() => MarketplaceUrgency, { nullable: true })
  @IsOptional()
  @IsEnum(MarketplaceUrgency)
  urgency?: MarketplaceUrgency;

  @Field(() => MarketplaceAuthorizationStatus, { nullable: true })
  @IsOptional()
  @IsEnum(MarketplaceAuthorizationStatus)
  authorizationStatus?: MarketplaceAuthorizationStatus;
}

@InputType()
export class SubmitMarketplaceInterestInput {
  @Field(() => ID)
  @IsUUID()
  marketplaceRequestId!: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  message?: string;
}

@InputType()
export class GrantMarketplaceShareConsentInput {
  @Field(() => ID)
  @IsUUID()
  marketplaceRequestId!: string;

  @Field(() => ID)
  @IsUUID()
  providerProfileId!: string;

  @Field(() => [ID], { nullable: true })
  @IsOptional()
  @IsArray()
  @IsUUID('4', { each: true })
  documentIds?: string[];
}

@InputType()
export class RevokeMarketplaceConsentInput {
  @Field(() => ID)
  @IsUUID()
  marketplaceRequestId!: string;

  @Field(() => ID)
  @IsUUID()
  providerProfileId!: string;
}

@InputType()
export class CompleteProviderMarketplaceOnboardingInput {
  @Field()
  @IsString()
  @MinLength(1)
  accountType!: string;

  @Field()
  @IsString()
  @MinLength(1)
  legalName!: string;

  @Field()
  @IsString()
  @MinLength(1)
  displayName!: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  licenseNumber?: string;

  @Field({ nullable: true })
  @IsOptional()
  @IsString()
  npi?: string;

  @Field(() => [String])
  @IsArray()
  @IsString({ each: true })
  serviceCategories!: string[];

  @Field(() => [String])
  @IsArray()
  @IsString({ each: true })
  coverageZipCodes!: string[];

  @Field(() => [String])
  @IsArray()
  @IsString({ each: true })
  languages!: string[];

  @Field()
  @IsBoolean()
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
  @IsUUID()
  savedSearchId!: string;

  @Field()
  @IsBoolean()
  alertsEnabled!: boolean;
}
