import {
  MarketplaceAuthorizationStatus,
  MarketplaceLocationType,
  MarketplaceUrgency,
  ProviderMarketplaceProfile,
} from '../../generated/prisma/client';
import { haversineMiles, zipToApproxCentroid } from './marketplace-zip.util';

export type SavedSearchFilters = {
  zipCode?: string;
  radiusMiles?: number;
  serviceCategory?: string;
  ageRange?: string;
  language?: string;
  locationType?: MarketplaceLocationType;
  urgency?: MarketplaceUrgency;
  authorizationStatus?: MarketplaceAuthorizationStatus;
};

export function parseSavedSearchFilters(value: unknown): SavedSearchFilters {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return {};
  }
  const raw = value as Record<string, unknown>;
  return {
    zipCode: typeof raw.zipCode === 'string' ? raw.zipCode : undefined,
    radiusMiles:
      typeof raw.radiusMiles === 'number' ? raw.radiusMiles : undefined,
    serviceCategory:
      typeof raw.serviceCategory === 'string' ? raw.serviceCategory : undefined,
    ageRange: typeof raw.ageRange === 'string' ? raw.ageRange : undefined,
    language: typeof raw.language === 'string' ? raw.language : undefined,
    locationType: raw.locationType as MarketplaceLocationType | undefined,
    urgency: raw.urgency as MarketplaceUrgency | undefined,
    authorizationStatus: raw.authorizationStatus as
      | MarketplaceAuthorizationStatus
      | undefined,
  };
}

export function requestMatchesSavedSearchFilters(
  request: {
    zipCode?: string | null;
    ageRange: string;
    languagePreference?: string | null;
    locationType: MarketplaceLocationType;
    urgency: MarketplaceUrgency;
    authorizationStatus: MarketplaceAuthorizationStatus;
    serviceCategories: unknown;
    zipCentroidLat: unknown;
    zipCentroidLng: unknown;
  },
  filters: SavedSearchFilters,
  profile: Pick<ProviderMarketplaceProfile, 'coverageZipCodes'>,
): boolean {
  if (filters.ageRange && request.ageRange !== filters.ageRange) {
    return false;
  }
  if (filters.language) {
    const pref = request.languagePreference?.toLowerCase() ?? '';
    if (!pref.includes(filters.language.toLowerCase())) {
      return false;
    }
  }
  if (filters.locationType && request.locationType !== filters.locationType) {
    return false;
  }
  if (filters.urgency && request.urgency !== filters.urgency) {
    return false;
  }
  if (
    filters.authorizationStatus &&
    request.authorizationStatus !== filters.authorizationStatus
  ) {
    return false;
  }
  if (filters.zipCode) {
    const zip = filters.zipCode.replace(/\D/g, '').slice(0, 5);
    if (request.zipCode?.slice(0, 5) !== zip) {
      return false;
    }
  }
  if (filters.serviceCategory) {
    const categories = Array.isArray(request.serviceCategories)
      ? request.serviceCategories.map((v) => String(v))
      : [];
    if (!categories.includes(filters.serviceCategory)) {
      return false;
    }
  }
  if (filters.radiusMiles) {
    const coverage = Array.isArray(profile.coverageZipCodes)
      ? profile.coverageZipCodes
      : [];
    if (coverage.length === 0) return false;
    const providerCentroid = zipToApproxCentroid(String(coverage[0]));
    const distance = haversineMiles(
      providerCentroid.lat,
      providerCentroid.lng,
      Number(request.zipCentroidLat),
      Number(request.zipCentroidLng),
    );
    if (distance > filters.radiusMiles) {
      return false;
    }
  }
  return true;
}
