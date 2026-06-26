-- Phase 2/3: referrals, payroll pay rates

CREATE TYPE "AgencyReferralStatus" AS ENUM (
  'NEW',
  'CONTACTED',
  'SCREENING_STARTED',
  'INTAKE_SCHEDULED',
  'EVALUATION_NEEDED',
  'CONVERTED_TO_CLIENT',
  'NOT_ELIGIBLE',
  'CLOSED'
);

CREATE TABLE "agency_referrals" (
    "id" UUID NOT NULL,
    "agency_id" UUID NOT NULL,
    "tenant_id" UUID NOT NULL,
    "contact_name" TEXT,
    "contact_phone" TEXT,
    "contact_email" TEXT,
    "child_name" TEXT,
    "source_name" TEXT,
    "source_type" TEXT,
    "status" "AgencyReferralStatus" NOT NULL DEFAULT 'NEW',
    "notes" TEXT,
    "converted_child_id" UUID,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "agency_referrals_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "provider_pay_rates" (
    "id" UUID NOT NULL,
    "agency_id" UUID NOT NULL,
    "tenant_id" UUID NOT NULL,
    "therapist_id" UUID NOT NULL,
    "service_type" "TherapyType",
    "rate_cents" INTEGER NOT NULL,
    "rate_unit" TEXT NOT NULL,
    "effective_from" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "provider_pay_rates_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "agency_referrals_agency_id_idx" ON "agency_referrals"("agency_id");
CREATE INDEX "agency_referrals_tenant_id_idx" ON "agency_referrals"("tenant_id");
CREATE INDEX "agency_referrals_status_idx" ON "agency_referrals"("status");
CREATE INDEX "provider_pay_rates_agency_id_idx" ON "provider_pay_rates"("agency_id");
CREATE INDEX "provider_pay_rates_tenant_id_idx" ON "provider_pay_rates"("tenant_id");
CREATE INDEX "provider_pay_rates_therapist_id_idx" ON "provider_pay_rates"("therapist_id");

ALTER TABLE "agency_referrals" ADD CONSTRAINT "agency_referrals_agency_id_fkey" FOREIGN KEY ("agency_id") REFERENCES "agencies"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "provider_pay_rates" ADD CONSTRAINT "provider_pay_rates_agency_id_fkey" FOREIGN KEY ("agency_id") REFERENCES "agencies"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "provider_pay_rates" ADD CONSTRAINT "provider_pay_rates_therapist_id_fkey" FOREIGN KEY ("therapist_id") REFERENCES "therapists"("id") ON DELETE CASCADE ON UPDATE CASCADE;
