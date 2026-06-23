-- Agency job opportunity marketplace: internal service needs → public therapist staffing posts

CREATE TYPE "JobServiceType" AS ENUM (
  'ABA', 'OT', 'PT', 'SPEECH', 'SPECIAL_INSTRUCTION', 'SOCIAL_WORK',
  'PSYCHOLOGY', 'NURSING', 'EVALUATION', 'SERVICE_COORDINATION', 'OTHER'
);

CREATE TYPE "JobOpportunityStatus" AS ENUM (
  'DRAFT', 'PENDING_REVIEW', 'PUBLISHED', 'PAUSED', 'CLOSED', 'BLOCKED', 'REMOVED'
);

CREATE TYPE "JobApplicationStatus" AS ENUM (
  'NEW_APPLICANT', 'UNDER_REVIEW', 'INTERVIEW_REQUESTED', 'CREDENTIAL_REVIEW',
  'OFFER_SENT', 'APPROVED', 'REJECTED', 'HIRED_CONTRACTED', 'WITHDRAWN'
);

CREATE TYPE "JobEmploymentType" AS ENUM (
  'W2', 'FORM_1099', 'PER_DIEM', 'PART_TIME', 'FULL_TIME'
);

CREATE TYPE "JobLocationModality" AS ENUM (
  'IN_PERSON', 'TELEHEALTH', 'HYBRID'
);

CREATE TYPE "ChildServiceNeedStatus" AS ENUM (
  'OPEN', 'JOB_POSTED', 'FILLED', 'CLOSED'
);

CREATE TYPE "PostingModerationFlagStatus" AS ENUM (
  'OPEN', 'RESOLVED', 'DISMISSED'
);

CREATE TABLE "child_service_needs" (
    "id" UUID NOT NULL,
    "agency_id" UUID NOT NULL,
    "child_id" UUID NOT NULL,
    "service_type" "JobServiceType" NOT NULL,
    "internal_notes" TEXT,
    "internal_schedule" JSONB NOT NULL DEFAULT '{}',
    "created_by_user_id" UUID NOT NULL,
    "status" "ChildServiceNeedStatus" NOT NULL DEFAULT 'OPEN',
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,
    CONSTRAINT "child_service_needs_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "child_service_needs_agency_id_idx" ON "child_service_needs"("agency_id");
CREATE INDEX "child_service_needs_child_id_idx" ON "child_service_needs"("child_id");
CREATE INDEX "child_service_needs_status_idx" ON "child_service_needs"("status");

ALTER TABLE "child_service_needs" ADD CONSTRAINT "child_service_needs_agency_id_fkey"
  FOREIGN KEY ("agency_id") REFERENCES "agencies"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "child_service_needs" ADD CONSTRAINT "child_service_needs_child_id_fkey"
  FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "child_service_needs" ADD CONSTRAINT "child_service_needs_created_by_user_id_fkey"
  FOREIGN KEY ("created_by_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE TABLE "job_opportunities" (
    "id" UUID NOT NULL,
    "tenant_id" UUID NOT NULL,
    "agency_id" UUID NOT NULL,
    "child_service_need_id" UUID NOT NULL,
    "title" TEXT NOT NULL,
    "service_type" "JobServiceType" NOT NULL,
    "status" "JobOpportunityStatus" NOT NULL DEFAULT 'DRAFT',
    "public_description" TEXT,
    "zip_code" TEXT NOT NULL,
    "borough" TEXT,
    "county" TEXT,
    "service_radius_miles" INTEGER,
    "zip_centroid_lat" DECIMAL(10,7),
    "zip_centroid_lng" DECIMAL(10,7),
    "schedule" JSONB NOT NULL DEFAULT '{}',
    "language_requirement" TEXT,
    "employment_type" "JobEmploymentType",
    "pay_rate_min" DECIMAL(10,2),
    "pay_rate_max" DECIMAL(10,2),
    "pay_rate_display" TEXT,
    "location_modality" "JobLocationModality" NOT NULL DEFAULT 'IN_PERSON',
    "required_credentials" JSONB NOT NULL DEFAULT '[]',
    "required_experience" TEXT,
    "preferred_start_date" DATE,
    "phi_scan_passed" BOOLEAN NOT NULL DEFAULT false,
    "phi_scan_flags" JSONB NOT NULL DEFAULT '[]',
    "published_at" TIMESTAMPTZ,
    "moderation_note" TEXT,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,
    CONSTRAINT "job_opportunities_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "job_opportunities_child_service_need_id_key" ON "job_opportunities"("child_service_need_id");
CREATE INDEX "job_opportunities_tenant_id_idx" ON "job_opportunities"("tenant_id");
CREATE INDEX "job_opportunities_agency_id_idx" ON "job_opportunities"("agency_id");
CREATE INDEX "job_opportunities_status_idx" ON "job_opportunities"("status");
CREATE INDEX "job_opportunities_service_type_idx" ON "job_opportunities"("service_type");
CREATE INDEX "job_opportunities_zip_code_idx" ON "job_opportunities"("zip_code");

ALTER TABLE "job_opportunities" ADD CONSTRAINT "job_opportunities_tenant_id_fkey"
  FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "job_opportunities" ADD CONSTRAINT "job_opportunities_agency_id_fkey"
  FOREIGN KEY ("agency_id") REFERENCES "agencies"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "job_opportunities" ADD CONSTRAINT "job_opportunities_child_service_need_id_fkey"
  FOREIGN KEY ("child_service_need_id") REFERENCES "child_service_needs"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "job_opportunity_applications" (
    "id" UUID NOT NULL,
    "job_opportunity_id" UUID NOT NULL,
    "therapist_id" UUID NOT NULL,
    "applicant_user_id" UUID NOT NULL,
    "status" "JobApplicationStatus" NOT NULL DEFAULT 'NEW_APPLICANT',
    "message" TEXT,
    "credential_snapshot" JSONB NOT NULL DEFAULT '{}',
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,
    CONSTRAINT "job_opportunity_applications_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "job_opportunity_applications_job_opportunity_id_therapist_id_key"
  ON "job_opportunity_applications"("job_opportunity_id", "therapist_id");
CREATE INDEX "job_opportunity_applications_job_opportunity_id_idx" ON "job_opportunity_applications"("job_opportunity_id");
CREATE INDEX "job_opportunity_applications_therapist_id_idx" ON "job_opportunity_applications"("therapist_id");
CREATE INDEX "job_opportunity_applications_status_idx" ON "job_opportunity_applications"("status");

ALTER TABLE "job_opportunity_applications" ADD CONSTRAINT "job_opportunity_applications_job_opportunity_id_fkey"
  FOREIGN KEY ("job_opportunity_id") REFERENCES "job_opportunities"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "job_opportunity_applications" ADD CONSTRAINT "job_opportunity_applications_therapist_id_fkey"
  FOREIGN KEY ("therapist_id") REFERENCES "therapists"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "job_opportunity_applications" ADD CONSTRAINT "job_opportunity_applications_applicant_user_id_fkey"
  FOREIGN KEY ("applicant_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "application_status_history" (
    "id" UUID NOT NULL,
    "application_id" UUID NOT NULL,
    "from_status" "JobApplicationStatus",
    "to_status" "JobApplicationStatus" NOT NULL,
    "changed_by_user_id" UUID NOT NULL,
    "note" TEXT,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "application_status_history_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "application_status_history_application_id_idx" ON "application_status_history"("application_id");

ALTER TABLE "application_status_history" ADD CONSTRAINT "application_status_history_application_id_fkey"
  FOREIGN KEY ("application_id") REFERENCES "job_opportunity_applications"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "application_status_history" ADD CONSTRAINT "application_status_history_changed_by_user_id_fkey"
  FOREIGN KEY ("changed_by_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE TABLE "therapist_credential_wallets" (
    "id" UUID NOT NULL,
    "therapist_id" UUID NOT NULL,
    "documents" JSONB NOT NULL DEFAULT '[]',
    "updated_at" TIMESTAMPTZ NOT NULL,
    CONSTRAINT "therapist_credential_wallets_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "therapist_credential_wallets_therapist_id_key" ON "therapist_credential_wallets"("therapist_id");

ALTER TABLE "therapist_credential_wallets" ADD CONSTRAINT "therapist_credential_wallets_therapist_id_fkey"
  FOREIGN KEY ("therapist_id") REFERENCES "therapists"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "marketplace_audit_logs" (
    "id" UUID NOT NULL,
    "tenant_id" UUID NOT NULL,
    "event_type" TEXT NOT NULL,
    "entity_type" TEXT NOT NULL,
    "entity_id" UUID NOT NULL,
    "actor_user_id" UUID,
    "metadata" JSONB NOT NULL DEFAULT '{}',
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "marketplace_audit_logs_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "marketplace_audit_logs_tenant_id_idx" ON "marketplace_audit_logs"("tenant_id");
CREATE INDEX "marketplace_audit_logs_entity_type_entity_id_idx" ON "marketplace_audit_logs"("entity_type", "entity_id");
CREATE INDEX "marketplace_audit_logs_event_type_idx" ON "marketplace_audit_logs"("event_type");
CREATE INDEX "marketplace_audit_logs_created_at_idx" ON "marketplace_audit_logs"("created_at");

ALTER TABLE "marketplace_audit_logs" ADD CONSTRAINT "marketplace_audit_logs_tenant_id_fkey"
  FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "marketplace_audit_logs" ADD CONSTRAINT "marketplace_audit_logs_actor_user_id_fkey"
  FOREIGN KEY ("actor_user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE TABLE "posting_moderation_flags" (
    "id" UUID NOT NULL,
    "job_opportunity_id" UUID NOT NULL,
    "reason" TEXT NOT NULL,
    "status" "PostingModerationFlagStatus" NOT NULL DEFAULT 'OPEN',
    "flagged_by_user_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,
    CONSTRAINT "posting_moderation_flags_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "posting_moderation_flags_job_opportunity_id_idx" ON "posting_moderation_flags"("job_opportunity_id");
CREATE INDEX "posting_moderation_flags_status_idx" ON "posting_moderation_flags"("status");

ALTER TABLE "posting_moderation_flags" ADD CONSTRAINT "posting_moderation_flags_job_opportunity_id_fkey"
  FOREIGN KEY ("job_opportunity_id") REFERENCES "job_opportunities"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "posting_moderation_flags" ADD CONSTRAINT "posting_moderation_flags_flagged_by_user_id_fkey"
  FOREIGN KEY ("flagged_by_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE TABLE "saved_job_opportunities" (
    "id" UUID NOT NULL,
    "therapist_id" UUID NOT NULL,
    "job_opportunity_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "saved_job_opportunities_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "saved_job_opportunities_therapist_id_job_opportunity_id_key"
  ON "saved_job_opportunities"("therapist_id", "job_opportunity_id");
CREATE INDEX "saved_job_opportunities_therapist_id_idx" ON "saved_job_opportunities"("therapist_id");

ALTER TABLE "saved_job_opportunities" ADD CONSTRAINT "saved_job_opportunities_therapist_id_fkey"
  FOREIGN KEY ("therapist_id") REFERENCES "therapists"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "saved_job_opportunities" ADD CONSTRAINT "saved_job_opportunities_job_opportunity_id_fkey"
  FOREIGN KEY ("job_opportunity_id") REFERENCES "job_opportunities"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "agency_invites_to_apply" (
    "id" UUID NOT NULL,
    "job_opportunity_id" UUID NOT NULL,
    "therapist_id" UUID NOT NULL,
    "invited_by_user_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "agency_invites_to_apply_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "agency_invites_to_apply_job_opportunity_id_therapist_id_key"
  ON "agency_invites_to_apply"("job_opportunity_id", "therapist_id");
CREATE INDEX "agency_invites_to_apply_therapist_id_idx" ON "agency_invites_to_apply"("therapist_id");

ALTER TABLE "agency_invites_to_apply" ADD CONSTRAINT "agency_invites_to_apply_job_opportunity_id_fkey"
  FOREIGN KEY ("job_opportunity_id") REFERENCES "job_opportunities"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "agency_invites_to_apply" ADD CONSTRAINT "agency_invites_to_apply_therapist_id_fkey"
  FOREIGN KEY ("therapist_id") REFERENCES "therapists"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "agency_invites_to_apply" ADD CONSTRAINT "agency_invites_to_apply_invited_by_user_id_fkey"
  FOREIGN KEY ("invited_by_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
