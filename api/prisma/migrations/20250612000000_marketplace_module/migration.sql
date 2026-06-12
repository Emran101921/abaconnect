-- Marketplace module: anonymous service requests, consent, provider profiles

CREATE TYPE "MarketplaceRequestStatus" AS ENUM ('DRAFT', 'ACTIVE', 'PAUSED', 'MATCHED', 'CLOSED');
CREATE TYPE "MarketplaceInterestStatus" AS ENUM ('PENDING_PARENT_REVIEW', 'ACCEPTED', 'REJECTED', 'WITHDRAWN');
CREATE TYPE "MarketplaceConsentType" AS ENUM ('ANONYMOUS_MARKETPLACE_POSTING', 'SHARE_IDENTIFIABLE_INFO', 'SHARE_DOCUMENTS', 'REVOKE_CONSENT');
CREATE TYPE "MarketplaceUrgency" AS ENUM ('ROUTINE', 'SOON', 'URGENT');
CREATE TYPE "MarketplaceAuthorizationStatus" AS ENUM ('PARENT_SCREENING_ONLY', 'EVALUATION_NEEDED', 'SERVICE_AUTHORIZED', 'IFSP_AVAILABLE_AFTER_CONSENT');
CREATE TYPE "MarketplaceLocationType" AS ENUM ('HOME', 'DAYCARE', 'CLINIC', 'TELEHEALTH', 'SCHOOL', 'COMMUNITY');
CREATE TYPE "MarketplaceAgeRange" AS ENUM ('MONTHS_0_12', 'MONTHS_13_24', 'MONTHS_25_36', 'YEARS_3_5', 'YEARS_6_8', 'YEARS_9_12', 'YEARS_13_PLUS');
CREATE TYPE "MarketplaceServiceCategory" AS ENUM ('SPEECH', 'OCCUPATIONAL', 'PHYSICAL', 'ABA', 'SPECIAL_INSTRUCTION', 'EVALUATION', 'NURSING', 'FEEDING', 'SOCIAL_WORK', 'SERVICE_COORDINATION', 'OTHER');
CREATE TYPE "ProviderMarketplaceAccountType" AS ENUM ('THERAPIST', 'AGENCY');
CREATE TYPE "ProviderMarketplaceVerificationStatus" AS ENUM ('PENDING', 'VERIFIED', 'REJECTED', 'SUSPENDED');

ALTER TYPE "AuditAction" ADD VALUE IF NOT EXISTS 'MARKETPLACE_REQUEST_VIEWED';
ALTER TYPE "AuditAction" ADD VALUE IF NOT EXISTS 'MARKETPLACE_INTEREST_SUBMITTED';
ALTER TYPE "AuditAction" ADD VALUE IF NOT EXISTS 'MARKETPLACE_IDENTIFIABLE_SHARED';

ALTER TABLE "children" ADD COLUMN IF NOT EXISTS "age_range" "MarketplaceAgeRange";
ALTER TABLE "children" ADD COLUMN IF NOT EXISTS "city" TEXT;
ALTER TABLE "children" ADD COLUMN IF NOT EXISTS "state" TEXT;

ALTER TABLE "screening_responses" ADD COLUMN IF NOT EXISTS "concern_tags" JSONB NOT NULL DEFAULT '[]';
ALTER TABLE "screening_responses" ADD COLUMN IF NOT EXISTS "suggested_service_categories" JSONB NOT NULL DEFAULT '[]';
ALTER TABLE "screening_responses" ADD COLUMN IF NOT EXISTS "disclaimer_accepted" BOOLEAN NOT NULL DEFAULT false;

CREATE TABLE "marketplace_requests" (
    "id" UUID NOT NULL,
    "tenant_id" UUID NOT NULL,
    "child_id" UUID NOT NULL,
    "parent_user_id" UUID NOT NULL,
    "screening_response_id" UUID,
    "anonymous_public_id" TEXT NOT NULL,
    "status" "MarketplaceRequestStatus" NOT NULL DEFAULT 'DRAFT',
    "service_categories" JSONB NOT NULL DEFAULT '[]',
    "concern_tags" JSONB NOT NULL DEFAULT '[]',
    "age_range" "MarketplaceAgeRange" NOT NULL,
    "zip_code" TEXT NOT NULL,
    "city" TEXT,
    "state" TEXT,
    "zip_centroid_lat" DECIMAL(10,7) NOT NULL,
    "zip_centroid_lng" DECIMAL(10,7) NOT NULL,
    "map_pin_jitter_lat" DECIMAL(10,7),
    "map_pin_jitter_lng" DECIMAL(10,7),
    "approximate_location_enabled" BOOLEAN NOT NULL DEFAULT true,
    "exact_address_shared" BOOLEAN NOT NULL DEFAULT false,
    "location_type" "MarketplaceLocationType" NOT NULL,
    "preferred_schedule" JSONB NOT NULL DEFAULT '{}',
    "language_preference" TEXT,
    "authorization_status" "MarketplaceAuthorizationStatus" NOT NULL,
    "urgency" "MarketplaceUrgency" NOT NULL DEFAULT 'ROUTINE',
    "public_description" TEXT,
    "removed_at" TIMESTAMPTZ,
    "removed_reason" TEXT,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,
    CONSTRAINT "marketplace_requests_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "marketplace_requests_anonymous_public_id_key" ON "marketplace_requests"("anonymous_public_id");
CREATE INDEX "marketplace_requests_tenant_id_idx" ON "marketplace_requests"("tenant_id");
CREATE INDEX "marketplace_requests_child_id_idx" ON "marketplace_requests"("child_id");
CREATE INDEX "marketplace_requests_parent_user_id_idx" ON "marketplace_requests"("parent_user_id");
CREATE INDEX "marketplace_requests_status_idx" ON "marketplace_requests"("status");
CREATE INDEX "marketplace_requests_zip_code_idx" ON "marketplace_requests"("zip_code");
CREATE INDEX "marketplace_requests_age_range_idx" ON "marketplace_requests"("age_range");
CREATE INDEX "marketplace_requests_authorization_status_idx" ON "marketplace_requests"("authorization_status");

ALTER TABLE "marketplace_requests" ADD CONSTRAINT "marketplace_requests_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "marketplace_requests" ADD CONSTRAINT "marketplace_requests_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "marketplace_requests" ADD CONSTRAINT "marketplace_requests_parent_user_id_fkey" FOREIGN KEY ("parent_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "marketplace_requests" ADD CONSTRAINT "marketplace_requests_screening_response_id_fkey" FOREIGN KEY ("screening_response_id") REFERENCES "screening_responses"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE TABLE "provider_marketplace_profiles" (
    "id" UUID NOT NULL,
    "tenant_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "account_type" "ProviderMarketplaceAccountType" NOT NULL,
    "therapist_id" UUID,
    "agency_id" UUID,
    "legal_name" TEXT NOT NULL,
    "display_name" TEXT NOT NULL,
    "license_number" TEXT,
    "npi" TEXT,
    "service_categories" JSONB NOT NULL DEFAULT '[]',
    "coverage_zip_codes" JSONB NOT NULL DEFAULT '[]',
    "languages" JSONB NOT NULL DEFAULT '[]',
    "availability" JSONB NOT NULL DEFAULT '{}',
    "verified_status" "ProviderMarketplaceVerificationStatus" NOT NULL DEFAULT 'PENDING',
    "confidentiality_terms_accepted" BOOLEAN NOT NULL DEFAULT false,
    "confidentiality_accepted_at" TIMESTAMPTZ,
    "suspended_at" TIMESTAMPTZ,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,
    CONSTRAINT "provider_marketplace_profiles_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "provider_marketplace_profiles_user_id_key" ON "provider_marketplace_profiles"("user_id");
CREATE UNIQUE INDEX "provider_marketplace_profiles_therapist_id_key" ON "provider_marketplace_profiles"("therapist_id");
CREATE UNIQUE INDEX "provider_marketplace_profiles_agency_id_key" ON "provider_marketplace_profiles"("agency_id");
CREATE INDEX "provider_marketplace_profiles_tenant_id_idx" ON "provider_marketplace_profiles"("tenant_id");
CREATE INDEX "provider_marketplace_profiles_verified_status_idx" ON "provider_marketplace_profiles"("verified_status");

ALTER TABLE "provider_marketplace_profiles" ADD CONSTRAINT "provider_marketplace_profiles_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "provider_marketplace_profiles" ADD CONSTRAINT "provider_marketplace_profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "provider_marketplace_profiles" ADD CONSTRAINT "provider_marketplace_profiles_therapist_id_fkey" FOREIGN KEY ("therapist_id") REFERENCES "therapists"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "provider_marketplace_profiles" ADD CONSTRAINT "provider_marketplace_profiles_agency_id_fkey" FOREIGN KEY ("agency_id") REFERENCES "agencies"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE TABLE "marketplace_interests" (
    "id" UUID NOT NULL,
    "tenant_id" UUID NOT NULL,
    "marketplace_request_id" UUID NOT NULL,
    "provider_profile_id" UUID NOT NULL,
    "message" TEXT,
    "availability" JSONB NOT NULL DEFAULT '{}',
    "status" "MarketplaceInterestStatus" NOT NULL DEFAULT 'PENDING_PARENT_REVIEW',
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,
    CONSTRAINT "marketplace_interests_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "marketplace_interests_marketplace_request_id_provider_profile_id_key" ON "marketplace_interests"("marketplace_request_id", "provider_profile_id");
CREATE INDEX "marketplace_interests_tenant_id_idx" ON "marketplace_interests"("tenant_id");
CREATE INDEX "marketplace_interests_provider_profile_id_idx" ON "marketplace_interests"("provider_profile_id");
CREATE INDEX "marketplace_interests_status_idx" ON "marketplace_interests"("status");

ALTER TABLE "marketplace_interests" ADD CONSTRAINT "marketplace_interests_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "marketplace_interests" ADD CONSTRAINT "marketplace_interests_marketplace_request_id_fkey" FOREIGN KEY ("marketplace_request_id") REFERENCES "marketplace_requests"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "marketplace_interests" ADD CONSTRAINT "marketplace_interests_provider_profile_id_fkey" FOREIGN KEY ("provider_profile_id") REFERENCES "provider_marketplace_profiles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "marketplace_consent_records" (
    "id" UUID NOT NULL,
    "tenant_id" UUID NOT NULL,
    "parent_user_id" UUID NOT NULL,
    "child_id" UUID NOT NULL,
    "marketplace_request_id" UUID NOT NULL,
    "provider_profile_id" UUID,
    "consent_type" "MarketplaceConsentType" NOT NULL,
    "consent_text_version" TEXT NOT NULL,
    "consent_text_snapshot" TEXT NOT NULL,
    "granted" BOOLEAN NOT NULL DEFAULT true,
    "revoked_at" TIMESTAMPTZ,
    "ip_address" TEXT,
    "device_info" TEXT,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "marketplace_consent_records_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "marketplace_consent_records_tenant_id_idx" ON "marketplace_consent_records"("tenant_id");
CREATE INDEX "marketplace_consent_records_parent_user_id_idx" ON "marketplace_consent_records"("parent_user_id");
CREATE INDEX "marketplace_consent_records_child_id_idx" ON "marketplace_consent_records"("child_id");
CREATE INDEX "marketplace_consent_records_marketplace_request_id_idx" ON "marketplace_consent_records"("marketplace_request_id");
CREATE INDEX "marketplace_consent_records_provider_profile_id_idx" ON "marketplace_consent_records"("provider_profile_id");
CREATE INDEX "marketplace_consent_records_consent_type_idx" ON "marketplace_consent_records"("consent_type");

ALTER TABLE "marketplace_consent_records" ADD CONSTRAINT "marketplace_consent_records_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "marketplace_consent_records" ADD CONSTRAINT "marketplace_consent_records_parent_user_id_fkey" FOREIGN KEY ("parent_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "marketplace_consent_records" ADD CONSTRAINT "marketplace_consent_records_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "marketplace_consent_records" ADD CONSTRAINT "marketplace_consent_records_marketplace_request_id_fkey" FOREIGN KEY ("marketplace_request_id") REFERENCES "marketplace_requests"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "marketplace_consent_records" ADD CONSTRAINT "marketplace_consent_records_provider_profile_id_fkey" FOREIGN KEY ("provider_profile_id") REFERENCES "provider_marketplace_profiles"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE TABLE "marketplace_saved_searches" (
    "id" UUID NOT NULL,
    "tenant_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "filters" JSONB NOT NULL DEFAULT '{}',
    "alerts_enabled" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,
    CONSTRAINT "marketplace_saved_searches_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "marketplace_saved_searches_tenant_id_idx" ON "marketplace_saved_searches"("tenant_id");
CREATE INDEX "marketplace_saved_searches_user_id_idx" ON "marketplace_saved_searches"("user_id");

ALTER TABLE "marketplace_saved_searches" ADD CONSTRAINT "marketplace_saved_searches_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "marketplace_saved_searches" ADD CONSTRAINT "marketplace_saved_searches_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "marketplace_reports" (
    "id" UUID NOT NULL,
    "tenant_id" UUID NOT NULL,
    "reporter_user_id" UUID NOT NULL,
    "marketplace_request_id" UUID,
    "reported_user_id" UUID,
    "reason" TEXT NOT NULL,
    "details" TEXT,
    "status" TEXT NOT NULL DEFAULT 'OPEN',
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "marketplace_reports_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "marketplace_reports_tenant_id_idx" ON "marketplace_reports"("tenant_id");
CREATE INDEX "marketplace_reports_status_idx" ON "marketplace_reports"("status");

ALTER TABLE "marketplace_reports" ADD CONSTRAINT "marketplace_reports_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "marketplace_reports" ADD CONSTRAINT "marketplace_reports_reporter_user_id_fkey" FOREIGN KEY ("reporter_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "marketplace_reports" ADD CONSTRAINT "marketplace_reports_marketplace_request_id_fkey" FOREIGN KEY ("marketplace_request_id") REFERENCES "marketplace_requests"("id") ON DELETE SET NULL ON UPDATE CASCADE;
