import { JobOpportunity } from '../../generated/prisma/client';
import { FORBIDDEN_PUBLIC_JOB_FIELDS } from './job-opportunity.constants';
import {
  buildLocationAreaLabel,
  formatJobServiceTypeLabel,
} from './job-opportunity-phi.util';

export type PublicJobOpportunity = {
  id: string;
  title: string;
  serviceType: string;
  serviceTypeLabel: string;
  status: string;
  publicDescription?: string;
  locationAreaLabel: string;
  zipCode: string;
  borough?: string;
  county?: string;
  serviceRadiusMiles?: number;
  distanceMiles?: number;
  schedule: Record<string, unknown>;
  languageRequirement?: string;
  employmentType?: string;
  payRateDisplay?: string;
  locationModality: string;
  requiredCredentials: unknown[];
  requiredExperience?: string;
  preferredStartDate?: Date;
  publishedAt?: Date;
  agencyName?: string;
  applicationCount?: number;
  createdAt: Date;
};

function parseJsonObject(value: unknown): Record<string, unknown> {
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return {};
}

function parseJsonArray(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

function assertNoForbiddenFields(payload: Record<string, unknown>): void {
  for (const key of FORBIDDEN_PUBLIC_JOB_FIELDS) {
    if (payload[key] !== undefined && payload[key] !== null) {
      throw new Error(`Forbidden job opportunity field leaked: ${key}`);
    }
  }
}

export function toPublicJobOpportunity(
  row: JobOpportunity & {
    agency?: { name: string };
    _count?: { applications: number };
  },
  options?: { distanceMiles?: number },
): PublicJobOpportunity {
  const publicJob: PublicJobOpportunity = {
    id: row.id,
    title: row.title,
    serviceType: row.serviceType,
    serviceTypeLabel: formatJobServiceTypeLabel(row.serviceType),
    status: row.status,
    publicDescription: row.publicDescription ?? undefined,
    locationAreaLabel: buildLocationAreaLabel(
      row.borough,
      row.county,
      row.zipCode,
    ),
    zipCode: row.zipCode.slice(0, 5),
    borough: row.borough ?? undefined,
    county: row.county ?? undefined,
    serviceRadiusMiles: row.serviceRadiusMiles ?? undefined,
    distanceMiles: options?.distanceMiles,
    schedule: parseJsonObject(row.schedule),
    languageRequirement: row.languageRequirement ?? undefined,
    employmentType: row.employmentType ?? undefined,
    payRateDisplay:
      row.payRateDisplay ??
      (row.payRateMin && row.payRateMax
        ? `$${row.payRateMin}-$${row.payRateMax}/hr`
        : undefined),
    locationModality: row.locationModality,
    requiredCredentials: parseJsonArray(row.requiredCredentials),
    requiredExperience: row.requiredExperience ?? undefined,
    preferredStartDate: row.preferredStartDate ?? undefined,
    publishedAt: row.publishedAt ?? undefined,
    agencyName: row.agency?.name,
    applicationCount: row._count?.applications,
    createdAt: row.createdAt,
  };

  assertNoForbiddenFields(publicJob as unknown as Record<string, unknown>);

  return publicJob;
}
