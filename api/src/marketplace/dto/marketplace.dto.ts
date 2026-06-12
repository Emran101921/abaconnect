import {
  IsArray,
  IsBoolean,
  IsEnum,
  IsObject,
  IsOptional,
  IsString,
  IsUUID,
  MinLength,
} from 'class-validator';
import {
  MarketplaceLocationType,
  MarketplaceUrgency,
  ProviderMarketplaceAccountType,
} from '../../../generated/prisma/client';

export class CreateMarketplaceRequestDto {
  @IsOptional()
  @IsUUID()
  screeningResponseId?: string;

  @IsBoolean()
  anonymousConsentGranted!: boolean;

  @IsEnum(MarketplaceLocationType)
  locationType!: MarketplaceLocationType;

  @IsOptional()
  @IsObject()
  preferredSchedule?: Record<string, unknown>;

  @IsOptional()
  @IsString()
  languagePreference?: string;

  @IsOptional()
  @IsEnum(MarketplaceUrgency)
  urgency?: MarketplaceUrgency;

  @IsOptional()
  @IsString()
  @MinLength(0)
  publicDescription?: string;
}

export class GrantShareConsentDto {
  @IsUUID()
  providerProfileId!: string;

  @IsOptional()
  @IsArray()
  @IsUUID('4', { each: true })
  documentIds?: string[];
}

export class RevokeConsentDto {
  @IsUUID()
  providerProfileId!: string;
}

export class ProviderInterestDto {
  @IsOptional()
  @IsString()
  message?: string;

  @IsOptional()
  @IsObject()
  availability?: Record<string, unknown>;
}

export class ProviderOnboardingDto {
  @IsEnum(ProviderMarketplaceAccountType)
  accountType!: ProviderMarketplaceAccountType;

  @IsString()
  @MinLength(1)
  legalName!: string;

  @IsString()
  @MinLength(1)
  displayName!: string;

  @IsOptional()
  @IsString()
  licenseNumber?: string;

  @IsOptional()
  @IsString()
  npi?: string;

  @IsArray()
  @IsString({ each: true })
  serviceCategories!: string[];

  @IsArray()
  @IsString({ each: true })
  coverageZipCodes!: string[];

  @IsArray()
  @IsString({ each: true })
  languages!: string[];

  @IsOptional()
  @IsObject()
  availability?: Record<string, unknown>;

  @IsBoolean()
  confidentialityTermsAccepted!: boolean;
}

export class ReportMarketplaceListingDto {
  @IsString()
  @MinLength(3)
  reason!: string;

  @IsOptional()
  @IsString()
  details?: string;

  @IsOptional()
  @IsUUID()
  reportedUserId?: string;
}

export class AdminSuspendUserDto {
  @IsOptional()
  @IsString()
  reason?: string;
}
