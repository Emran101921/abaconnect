import {
  MarketplaceAuthorizationStatus,
  MarketplaceLocationType,
  MarketplaceRequest,
} from '../../generated/prisma/client';
import { formatAgeRangeLabel } from './marketplace-age-range.util';
import { FORBIDDEN_PUBLIC_FIELDS } from './marketplace.constants';

export type PublicMarketplaceRequest = {
  id: string;
  anonymousPublicId: string;
  serviceAreaLabel: string;
  distanceMiles?: number;
  ageRangeLabel: string;
  serviceCategories: string[];
  concernTags: string[];
  languagePreference?: string;
  preferredSchedule: Record<string, unknown>;
  locationType: MarketplaceLocationType;
  authorizationStatus: MarketplaceAuthorizationStatus;
  authorizationStatusLabel: string;
  urgency: string;
  publicDescription?: string;
  mapPinLat?: number;
  mapPinLng?: number;
  exactAddressShared: boolean;
  status: string;
  createdAt: Date;
};

const AUTH_LABELS: Record<MarketplaceAuthorizationStatus, string> = {
  PARENT_SCREENING_ONLY: 'Parent screening only',
  EVALUATION_NEEDED: 'Evaluation needed',
  SERVICE_AUTHORIZED: 'Service authorized',
  IFSP_AVAILABLE_AFTER_CONSENT: 'IFSP available after consent',
};

export function authorizationStatusLabel(
  status: MarketplaceAuthorizationStatus,
): string {
  return AUTH_LABELS[status] ?? status;
}

export function buildServiceAreaLabel(
  city?: string | null,
  state?: string | null,
  zipCode?: string | null,
): string {
  const parts = [city, state].filter(Boolean);
  const area = parts.length > 0 ? parts.join(', ') : 'Service area';
  const zip = zipCode?.slice(0, 5);
  return zip ? `${area} ${zip} area` : `${area} area`;
}

export function toPublicMarketplaceRequest(
  row: MarketplaceRequest,
  options?: { distanceMiles?: number },
): PublicMarketplaceRequest {
  assertNoForbiddenFields(row as unknown as Record<string, unknown>);

  const mapLat = row.mapPinJitterLat ?? row.zipCentroidLat;
  const mapLng = row.mapPinJitterLng ?? row.zipCentroidLng;

  return {
    id: row.id,
    anonymousPublicId: row.anonymousPublicId,
    serviceAreaLabel: buildServiceAreaLabel(row.city, row.state, row.zipCode),
    distanceMiles: options?.distanceMiles,
    ageRangeLabel: formatAgeRangeLabel(row.ageRange),
    serviceCategories: parseJsonArray(row.serviceCategories),
    concernTags: parseJsonArray(row.concernTags),
    languagePreference: row.languagePreference ?? undefined,
    preferredSchedule: parseJsonObject(row.preferredSchedule),
    locationType: row.locationType,
    authorizationStatus: row.authorizationStatus,
    authorizationStatusLabel: authorizationStatusLabel(row.authorizationStatus),
    urgency: row.urgency,
    publicDescription: sanitizePublicDescription(row.publicDescription),
    mapPinLat: mapLat ? Number(mapLat) : undefined,
    mapPinLng: mapLng ? Number(mapLng) : undefined,
    exactAddressShared: row.exactAddressShared,
    status: row.status,
    createdAt: row.createdAt,
  };
}

export function sanitizePublicDescription(
  text?: string | null,
): string | undefined {
  if (!text?.trim()) return undefined;
  const blocked = [
    /\bautism\b/i,
    /\bdiagnos(is|ed)\b/i,
    /\brequires?\s+ab[ab]\b/i,
    /\bconfirmed\b/i,
    /\bmedicaid\s*id\b/i,
    /\binsurance\s*id\b/i,
  ];
  let out = text.trim();
  for (const pattern of blocked) {
    out = out.replace(pattern, '[redacted]');
  }
  return out.slice(0, 500);
}

function parseJsonArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value.map((v) => String(v));
}

function parseJsonObject(value: unknown): Record<string, unknown> {
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return {};
}

function assertNoForbiddenFields(payload: Record<string, unknown>): void {
  for (const key of FORBIDDEN_PUBLIC_FIELDS) {
    if (payload[key] !== undefined && payload[key] !== null) {
      throw new Error(`Forbidden marketplace field leaked: ${key}`);
    }
  }
}

export function mapTherapyTypeToServiceCategory(code: string): string {
  switch (code) {
    case 'SPEECH':
      return 'SPEECH';
    case 'OCCUPATIONAL':
      return 'OCCUPATIONAL';
    case 'PHYSICAL':
      return 'PHYSICAL';
    case 'ABA':
      return 'ABA';
    case 'EARLY_INTERVENTION':
      return 'SPECIAL_INSTRUCTION';
    case 'DEVELOPMENTAL_EVALUATION':
      return 'EVALUATION';
    default:
      return 'OTHER';
  }
}

export function deriveConcernTagsFromScreening(
  recommendations: Array<{ code?: string; explanation?: string }>,
  areaFlags?: Record<string, boolean>,
): string[] {
  const tags = new Set<string>();
  if (areaFlags?.speech) tags.add('communication delay');
  if (areaFlags?.ot) tags.add('motor delay');
  if (areaFlags?.feeding) tags.add('feeding concerns');
  if (areaFlags?.aba) tags.add('behavior concerns');
  if (areaFlags?.medical) tags.add('medical concerns');
  for (const rec of recommendations) {
    const exp = (rec.explanation ?? '').toLowerCase();
    if (exp.includes('sensory')) tags.add('sensory concerns');
    if (exp.includes('social')) tags.add('social-emotional concerns');
    if (exp.includes('motor')) tags.add('motor delay');
    if (exp.includes('communication') || exp.includes('language')) {
      tags.add('communication delay');
    }
  }
  return [...tags];
}
