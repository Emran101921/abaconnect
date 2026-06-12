import { Field, ID, InputType } from '@nestjs/graphql';
import {
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
  zipCode?: string;

  @Field({ nullable: true })
  radiusMiles?: number;

  @Field({ nullable: true })
  serviceCategory?: string;

  @Field({ nullable: true })
  ageRange?: string;

  @Field({ nullable: true })
  language?: string;
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
