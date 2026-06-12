import { Field, Float, ID, Int, ObjectType, registerEnumType } from '@nestjs/graphql';
import {
  MarketplaceLocationType,
  MarketplaceUrgency,
} from '../../../generated/prisma/client';

registerEnumType(MarketplaceLocationType, { name: 'MarketplaceLocationType' });
registerEnumType(MarketplaceUrgency, { name: 'MarketplaceUrgency' });

@ObjectType()
export class PublicMarketplaceRequestType {
  @Field(() => ID)
  id: string;

  @Field()
  anonymousPublicId: string;

  @Field()
  serviceAreaLabel: string;

  @Field(() => Float, { nullable: true })
  distanceMiles?: number;

  @Field()
  ageRangeLabel: string;

  @Field(() => [String])
  serviceCategories: string[];

  @Field(() => [String])
  concernTags: string[];

  @Field({ nullable: true })
  languagePreference?: string;

  @Field()
  locationType: string;

  @Field()
  authorizationStatus: string;

  @Field()
  authorizationStatusLabel: string;

  @Field()
  urgency: string;

  @Field({ nullable: true })
  publicDescription?: string;

  @Field(() => Float, { nullable: true })
  mapPinLat?: number;

  @Field(() => Float, { nullable: true })
  mapPinLng?: number;

  @Field()
  status: string;

  @Field(() => Int, { nullable: true })
  interestCount?: number;

  @Field(() => Float, { nullable: true })
  matchScore?: number;
}

@ObjectType()
export class MarketplaceInterestProviderType {
  @Field(() => ID)
  id: string;

  @Field()
  displayName: string;

  @Field()
  accountType: string;

  @Field(() => [String])
  serviceCategories: string[];

  @Field(() => [String])
  languages: string[];

  @Field()
  verifiedStatus: string;
}

@ObjectType()
export class MarketplaceInterestType {
  @Field(() => ID)
  id: string;

  @Field()
  status: string;

  @Field({ nullable: true })
  message?: string;

  @Field(() => MarketplaceInterestProviderType)
  provider: MarketplaceInterestProviderType;
}

@ObjectType()
export class MarketplaceConsentProviderType {
  @Field(() => ID)
  id: string;

  @Field()
  displayName: string;

  @Field()
  accountType: string;
}

@ObjectType()
export class MarketplaceConsentRecordType {
  @Field(() => ID)
  id: string;

  @Field()
  consentType: string;

  @Field()
  consentTextVersion: string;

  @Field()
  granted: boolean;

  @Field({ nullable: true })
  revokedAt?: Date;

  @Field()
  createdAt: Date;

  @Field(() => MarketplaceConsentProviderType, { nullable: true })
  provider?: MarketplaceConsentProviderType;
}

@ObjectType()
export class ProviderMarketplaceProfileType {
  @Field(() => ID)
  id: string;

  @Field()
  accountType: string;

  @Field()
  legalName: string;

  @Field()
  displayName: string;

  @Field()
  verifiedStatus: string;

  @Field()
  confidentialityTermsAccepted: boolean;

  @Field(() => [String])
  serviceCategories: string[];

  @Field(() => [String])
  coverageZipCodes: string[];

  @Field(() => [String])
  languages: string[];
}

@ObjectType()
export class AuthorizedChildDetailsType {
  @Field(() => ID)
  childId: string;

  @Field()
  firstName: string;

  @Field()
  lastName: string;

  @Field()
  zipCode: string;

  @Field({ nullable: true })
  city?: string;

  @Field({ nullable: true })
  state?: string;

  @Field({ nullable: true })
  primaryLanguage?: string;

  @Field()
  parentName: string;

  @Field({ nullable: true })
  parentEmail?: string;

  @Field({ nullable: true })
  parentPhone?: string;

  @Field()
  marketplaceRequestId: string;

  @Field()
  anonymousPublicId: string;
}
