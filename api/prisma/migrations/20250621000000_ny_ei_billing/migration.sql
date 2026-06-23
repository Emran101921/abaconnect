-- NY Early Intervention billing module (parallel to commercial insurance claims)

CREATE TYPE "EiBillingQueueStatus" AS ENUM (
  'DRAFT_INCOMPLETE', 'MISSING_INFORMATION', 'READY_AGENCY_REVIEW',
  'READY_BILLING_VALIDATION', 'READY_AUTHORIZED_SUBMISSION', 'SUBMITTED',
  'REJECTED', 'DENIED', 'CORRECTION_NEEDED', 'RESUBMITTED', 'PAID', 'ARCHIVED'
);

CREATE TYPE "EiClearinghouseWorkflow" AS ENUM (
  'EI_HUB', 'STATE_FISCAL_AGENT', 'EMEDNY', 'EDI_837P_EXPORT', 'CSV_EXPORT', 'API_CLEARINGHOUSE'
);

CREATE TYPE "EiCredentialStatus" AS ENUM (
  'PENDING', 'ACTIVE', 'EXPIRED', 'SUSPENDED', 'REVOKED'
);

CREATE TYPE "EiMedicaidEnrollmentStatus" AS ENUM (
  'NOT_ENROLLED', 'PENDING', 'ENROLLED', 'SUSPENDED', 'TERMINATED'
);

CREATE TYPE "EiCorrectionStatus" AS ENUM (
  'OPEN', 'IN_PROGRESS', 'RESOLVED', 'ESCALATED', 'CLOSED'
);

CREATE TYPE "EiReconciliationStatus" AS ENUM (
  'UNRECONCILED', 'PARTIAL', 'RECONCILED', 'DISCREPANCY'
);

CREATE TYPE "EiEftEnrollmentStatus" AS ENUM (
  'NOT_STARTED', 'PENDING', 'ACTIVE', 'REJECTED'
);

CREATE TYPE "EiConsentStatus" AS ENUM (
  'PENDING', 'GRANTED', 'REVOKED', 'EXPIRED'
);

ALTER TYPE "AuditAction" ADD VALUE IF NOT EXISTS 'EI_BILLING_PROFILE_UPDATED';
ALTER TYPE "AuditAction" ADD VALUE IF NOT EXISTS 'EI_BILLING_RECORD_CREATED';
ALTER TYPE "AuditAction" ADD VALUE IF NOT EXISTS 'EI_BILLING_RECORD_VALIDATED';
ALTER TYPE "AuditAction" ADD VALUE IF NOT EXISTS 'EI_BILLING_QUEUE_TRANSITION';
ALTER TYPE "AuditAction" ADD VALUE IF NOT EXISTS 'EI_BILLING_RECORD_LOCKED';
ALTER TYPE "AuditAction" ADD VALUE IF NOT EXISTS 'EI_BILLING_RECORD_EXPORTED';
ALTER TYPE "AuditAction" ADD VALUE IF NOT EXISTS 'EI_BILLING_RECORD_SUBMITTED';
ALTER TYPE "AuditAction" ADD VALUE IF NOT EXISTS 'EI_BILLING_DENIAL_RECORDED';
ALTER TYPE "AuditAction" ADD VALUE IF NOT EXISTS 'EI_BILLING_PAYMENT_POSTED';
ALTER TYPE "AuditAction" ADD VALUE IF NOT EXISTS 'EI_BILLING_CLEARINGHOUSE_CONFIG_UPDATED';
ALTER TYPE "AuditAction" ADD VALUE IF NOT EXISTS 'EI_BILLING_CLEARINGHOUSE_TESTED';
ALTER TYPE "AuditAction" ADD VALUE IF NOT EXISTS 'EI_BILLING_ENROLLMENT_UPDATED';

CREATE TABLE "ei_agency_billing_profiles" (
    "id" UUID NOT NULL,
    "tenant_id" UUID NOT NULL,
    "agency_id" UUID NOT NULL,
    "legal_name" TEXT NOT NULL,
    "npi" TEXT,
    "medicaid_provider_id" TEXT,
    "ein" TEXT,
    "etin" TEXT,
    "ei_hub_reference_id" TEXT,
    "eft_enrollment_status" "EiEftEnrollmentStatus" NOT NULL DEFAULT 'NOT_STARTED',
    "baa_signed_at" TIMESTAMPTZ,
    "baa_document_key" TEXT,
    "baa_signer_name" TEXT,
    "enrollment_complete" BOOLEAN NOT NULL DEFAULT false,
    "address_line1" TEXT,
    "address_line2" TEXT,
    "city" TEXT,
    "state" TEXT DEFAULT 'NY',
    "zip_code" TEXT,
    "phone" TEXT,
    "metadata" JSONB NOT NULL DEFAULT '{}',
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,
    CONSTRAINT "ei_agency_billing_profiles_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "ei_agency_billing_profiles_agency_id_key" ON "ei_agency_billing_profiles"("agency_id");
CREATE INDEX "ei_agency_billing_profiles_tenant_id_idx" ON "ei_agency_billing_profiles"("tenant_id");

ALTER TABLE "ei_agency_billing_profiles" ADD CONSTRAINT "ei_agency_billing_profiles_tenant_id_fkey"
  FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ei_agency_billing_profiles" ADD CONSTRAINT "ei_agency_billing_profiles_agency_id_fkey"
  FOREIGN KEY ("agency_id") REFERENCES "agencies"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "ei_provider_enrollments" (
    "id" UUID NOT NULL,
    "agency_id" UUID NOT NULL,
    "therapist_id" UUID NOT NULL,
    "rendering_npi" TEXT,
    "license_number" TEXT,
    "license_state" TEXT,
    "license_expiry" DATE,
    "discipline" TEXT,
    "ei_category" TEXT,
    "medicaid_enrollment_status" "EiMedicaidEnrollmentStatus" NOT NULL DEFAULT 'NOT_ENROLLED',
    "credential_status" "EiCredentialStatus" NOT NULL DEFAULT 'PENDING',
    "credential_expirations" JSONB NOT NULL DEFAULT '{}',
    "scr_clearance_date" DATE,
    "scr_clearance_expiry" DATE,
    "compliance_docs" JSONB NOT NULL DEFAULT '[]',
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,
    CONSTRAINT "ei_provider_enrollments_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "ei_provider_enrollments_agency_id_therapist_id_key"
  ON "ei_provider_enrollments"("agency_id", "therapist_id");
CREATE INDEX "ei_provider_enrollments_agency_id_idx" ON "ei_provider_enrollments"("agency_id");
CREATE INDEX "ei_provider_enrollments_therapist_id_idx" ON "ei_provider_enrollments"("therapist_id");
CREATE INDEX "ei_provider_enrollments_credential_status_idx" ON "ei_provider_enrollments"("credential_status");

ALTER TABLE "ei_provider_enrollments" ADD CONSTRAINT "ei_provider_enrollments_agency_id_fkey"
  FOREIGN KEY ("agency_id") REFERENCES "agencies"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ei_provider_enrollments" ADD CONSTRAINT "ei_provider_enrollments_therapist_id_fkey"
  FOREIGN KEY ("therapist_id") REFERENCES "therapists"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "ei_case_billing_profiles" (
    "id" UUID NOT NULL,
    "agency_id" UUID NOT NULL,
    "child_id" UUID NOT NULL,
    "ei_case_id" TEXT,
    "municipality" TEXT,
    "sc_reference_number" TEXT,
    "ifsp_authorization_number" TEXT,
    "service_type" TEXT,
    "frequency_per_week" INTEGER,
    "duration_minutes" INTEGER,
    "authorization_start_date" DATE,
    "authorization_end_date" DATE,
    "place_of_service" TEXT,
    "medicaid_cin" TEXT,
    "consent_status" "EiConsentStatus" NOT NULL DEFAULT 'PENDING',
    "consent_signed_at" TIMESTAMPTZ,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,
    CONSTRAINT "ei_case_billing_profiles_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "ei_case_billing_profiles_agency_id_child_id_key"
  ON "ei_case_billing_profiles"("agency_id", "child_id");
CREATE INDEX "ei_case_billing_profiles_agency_id_idx" ON "ei_case_billing_profiles"("agency_id");
CREATE INDEX "ei_case_billing_profiles_child_id_idx" ON "ei_case_billing_profiles"("child_id");
CREATE INDEX "ei_case_billing_profiles_ei_case_id_idx" ON "ei_case_billing_profiles"("ei_case_id");

ALTER TABLE "ei_case_billing_profiles" ADD CONSTRAINT "ei_case_billing_profiles_agency_id_fkey"
  FOREIGN KEY ("agency_id") REFERENCES "agencies"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ei_case_billing_profiles" ADD CONSTRAINT "ei_case_billing_profiles_child_id_fkey"
  FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "ei_billing_records" (
    "id" UUID NOT NULL,
    "tenant_id" UUID NOT NULL,
    "agency_id" UUID NOT NULL,
    "child_id" UUID NOT NULL,
    "session_id" UUID,
    "therapist_id" UUID NOT NULL,
    "case_profile_id" UUID NOT NULL,
    "queue_status" "EiBillingQueueStatus" NOT NULL DEFAULT 'DRAFT_INCOMPLETE',
    "units" DECIMAL(8,2) NOT NULL DEFAULT 0,
    "service_date" DATE NOT NULL,
    "start_time" TIMESTAMPTZ,
    "end_time" TIMESTAMPTZ,
    "validation_snapshot" JSONB NOT NULL DEFAULT '{}',
    "locked_at" TIMESTAMPTZ,
    "reviewed_by_id" UUID,
    "reviewed_at" TIMESTAMPTZ,
    "billed_amount" DECIMAL(10,2),
    "allowed_amount" DECIMAL(10,2),
    "submitted_at" TIMESTAMPTZ,
    "external_reference_id" TEXT,
    "clearinghouse_workflow" "EiClearinghouseWorkflow",
    "resubmission_of_id" UUID,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,
    CONSTRAINT "ei_billing_records_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "ei_billing_records_session_id_key" ON "ei_billing_records"("session_id");
CREATE UNIQUE INDEX "ei_billing_records_resubmission_of_id_key" ON "ei_billing_records"("resubmission_of_id");
CREATE INDEX "ei_billing_records_tenant_id_idx" ON "ei_billing_records"("tenant_id");
CREATE INDEX "ei_billing_records_agency_id_idx" ON "ei_billing_records"("agency_id");
CREATE INDEX "ei_billing_records_child_id_idx" ON "ei_billing_records"("child_id");
CREATE INDEX "ei_billing_records_therapist_id_idx" ON "ei_billing_records"("therapist_id");
CREATE INDEX "ei_billing_records_queue_status_idx" ON "ei_billing_records"("queue_status");
CREATE INDEX "ei_billing_records_service_date_idx" ON "ei_billing_records"("service_date");

ALTER TABLE "ei_billing_records" ADD CONSTRAINT "ei_billing_records_tenant_id_fkey"
  FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ei_billing_records" ADD CONSTRAINT "ei_billing_records_agency_id_fkey"
  FOREIGN KEY ("agency_id") REFERENCES "agencies"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ei_billing_records" ADD CONSTRAINT "ei_billing_records_child_id_fkey"
  FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ei_billing_records" ADD CONSTRAINT "ei_billing_records_session_id_fkey"
  FOREIGN KEY ("session_id") REFERENCES "sessions"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "ei_billing_records" ADD CONSTRAINT "ei_billing_records_therapist_id_fkey"
  FOREIGN KEY ("therapist_id") REFERENCES "therapists"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ei_billing_records" ADD CONSTRAINT "ei_billing_records_case_profile_id_fkey"
  FOREIGN KEY ("case_profile_id") REFERENCES "ei_case_billing_profiles"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "ei_billing_records" ADD CONSTRAINT "ei_billing_records_reviewed_by_id_fkey"
  FOREIGN KEY ("reviewed_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "ei_billing_records" ADD CONSTRAINT "ei_billing_records_resubmission_of_id_fkey"
  FOREIGN KEY ("resubmission_of_id") REFERENCES "ei_billing_records"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE TABLE "ei_billing_validation_issues" (
    "id" UUID NOT NULL,
    "record_id" UUID NOT NULL,
    "code" TEXT NOT NULL,
    "severity" TEXT NOT NULL,
    "message" TEXT NOT NULL,
    "resolved" BOOLEAN NOT NULL DEFAULT false,
    "resolved_at" TIMESTAMPTZ,
    "resolved_by_id" UUID,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "ei_billing_validation_issues_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "ei_billing_validation_issues_record_id_idx" ON "ei_billing_validation_issues"("record_id");
CREATE INDEX "ei_billing_validation_issues_resolved_idx" ON "ei_billing_validation_issues"("resolved");

ALTER TABLE "ei_billing_validation_issues" ADD CONSTRAINT "ei_billing_validation_issues_record_id_fkey"
  FOREIGN KEY ("record_id") REFERENCES "ei_billing_records"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ei_billing_validation_issues" ADD CONSTRAINT "ei_billing_validation_issues_resolved_by_id_fkey"
  FOREIGN KEY ("resolved_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE TABLE "ei_clearinghouse_configs" (
    "id" UUID NOT NULL,
    "tenant_id" UUID NOT NULL,
    "agency_id" UUID,
    "name" TEXT NOT NULL,
    "workflow" "EiClearinghouseWorkflow" NOT NULL,
    "trading_partner_id" TEXT,
    "submitter_id" TEXT,
    "receiver_id" TEXT,
    "api_endpoint_ref" TEXT,
    "sftp_host_ref" TEXT,
    "credentials_ref" TEXT,
    "baa_signed_at" TIMESTAMPTZ,
    "baa_effective_date" DATE,
    "test_mode" BOOLEAN NOT NULL DEFAULT true,
    "last_connection_test_at" TIMESTAMPTZ,
    "last_connection_test_result" TEXT,
    "error_logs" JSONB NOT NULL DEFAULT '[]',
    "is_active" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,
    CONSTRAINT "ei_clearinghouse_configs_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "ei_clearinghouse_configs_tenant_id_idx" ON "ei_clearinghouse_configs"("tenant_id");
CREATE INDEX "ei_clearinghouse_configs_agency_id_idx" ON "ei_clearinghouse_configs"("agency_id");
CREATE INDEX "ei_clearinghouse_configs_workflow_idx" ON "ei_clearinghouse_configs"("workflow");

ALTER TABLE "ei_clearinghouse_configs" ADD CONSTRAINT "ei_clearinghouse_configs_tenant_id_fkey"
  FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ei_clearinghouse_configs" ADD CONSTRAINT "ei_clearinghouse_configs_agency_id_fkey"
  FOREIGN KEY ("agency_id") REFERENCES "agencies"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "ei_denial_rejections" (
    "id" UUID NOT NULL,
    "record_id" UUID NOT NULL,
    "code" TEXT NOT NULL,
    "reason" TEXT NOT NULL,
    "payer_name" TEXT,
    "received_at" TIMESTAMPTZ NOT NULL,
    "assigned_staff_id" UUID,
    "correction_status" "EiCorrectionStatus" NOT NULL DEFAULT 'OPEN',
    "correction_notes" TEXT,
    "resubmission_record_id" UUID,
    "audit_metadata" JSONB NOT NULL DEFAULT '{}',
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ NOT NULL,
    CONSTRAINT "ei_denial_rejections_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "ei_denial_rejections_record_id_idx" ON "ei_denial_rejections"("record_id");
CREATE INDEX "ei_denial_rejections_correction_status_idx" ON "ei_denial_rejections"("correction_status");

ALTER TABLE "ei_denial_rejections" ADD CONSTRAINT "ei_denial_rejections_record_id_fkey"
  FOREIGN KEY ("record_id") REFERENCES "ei_billing_records"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ei_denial_rejections" ADD CONSTRAINT "ei_denial_rejections_assigned_staff_id_fkey"
  FOREIGN KEY ("assigned_staff_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE TABLE "ei_payment_postings" (
    "id" UUID NOT NULL,
    "record_id" UUID NOT NULL,
    "paid_amount" DECIMAL(10,2) NOT NULL,
    "allowed_amount" DECIMAL(10,2),
    "adjustment_amount" DECIMAL(10,2),
    "denied_amount" DECIMAL(10,2),
    "eft_reference" TEXT,
    "era_placeholder" TEXT,
    "reconciliation_status" "EiReconciliationStatus" NOT NULL DEFAULT 'UNRECONCILED',
    "posted_at" TIMESTAMPTZ NOT NULL,
    "posted_by_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "ei_payment_postings_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "ei_payment_postings_record_id_idx" ON "ei_payment_postings"("record_id");
CREATE INDEX "ei_payment_postings_reconciliation_status_idx" ON "ei_payment_postings"("reconciliation_status");

ALTER TABLE "ei_payment_postings" ADD CONSTRAINT "ei_payment_postings_record_id_fkey"
  FOREIGN KEY ("record_id") REFERENCES "ei_billing_records"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "ei_payment_postings" ADD CONSTRAINT "ei_payment_postings_posted_by_id_fkey"
  FOREIGN KEY ("posted_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
