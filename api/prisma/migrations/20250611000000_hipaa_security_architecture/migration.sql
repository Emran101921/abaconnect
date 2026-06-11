-- HIPAA security architecture: roles, audit, claims, compliance docs, provider onboarding

-- New user roles
ALTER TYPE "UserRole" ADD VALUE IF NOT EXISTS 'BILLING_STAFF';
ALTER TYPE "UserRole" ADD VALUE IF NOT EXISTS 'COMPLIANCE_AUDITOR';
ALTER TYPE "UserRole" ADD VALUE IF NOT EXISTS 'SUPPORT_STAFF';

-- Extended audit actions
ALTER TYPE "AuditAction" ADD VALUE IF NOT EXISTS 'LOGIN_FAILED';
ALTER TYPE "AuditAction" ADD VALUE IF NOT EXISTS 'FILE_UPLOADED';
ALTER TYPE "AuditAction" ADD VALUE IF NOT EXISTS 'FILE_DOWNLOADED';
ALTER TYPE "AuditAction" ADD VALUE IF NOT EXISTS 'NOTE_CREATED';
ALTER TYPE "AuditAction" ADD VALUE IF NOT EXISTS 'NOTE_EDITED';
ALTER TYPE "AuditAction" ADD VALUE IF NOT EXISTS 'CLAIM_CREATED';
ALTER TYPE "AuditAction" ADD VALUE IF NOT EXISTS 'CLAIM_SUBMITTED';
ALTER TYPE "AuditAction" ADD VALUE IF NOT EXISTS 'CLAIM_RESUBMITTED';
ALTER TYPE "AuditAction" ADD VALUE IF NOT EXISTS 'PERMISSION_CHANGED';
ALTER TYPE "AuditAction" ADD VALUE IF NOT EXISTS 'USER_INVITED';
ALTER TYPE "AuditAction" ADD VALUE IF NOT EXISTS 'USER_DISABLED';
ALTER TYPE "AuditAction" ADD VALUE IF NOT EXISTS 'REPORT_EXPORTED';
ALTER TYPE "AuditAction" ADD VALUE IF NOT EXISTS 'PAYMENT_EVENT';
ALTER TYPE "AuditAction" ADD VALUE IF NOT EXISTS 'MESSAGE_SENT';
ALTER TYPE "AuditAction" ADD VALUE IF NOT EXISTS 'ARCHIVE';

-- New enums
CREATE TYPE "ComplianceDocumentType" AS ENUM (
  'PRIVACY_POLICY',
  'TERMS_OF_USE',
  'HIPAA_NOTICE',
  'CONSENT_FORM',
  'DATA_RETENTION_POLICY',
  'BREACH_NOTIFICATION_POLICY',
  'CONTACT_COMPLIANCE_OFFICER'
);

CREATE TYPE "ProviderOnboardingStatus" AS ENUM (
  'PENDING',
  'IN_REVIEW',
  'APPROVED',
  'SUSPENDED',
  'INACTIVE'
);

-- Provider onboarding fields
ALTER TABLE "therapists" ADD COLUMN IF NOT EXISTS "tax_id" TEXT;
ALTER TABLE "therapists" ADD COLUMN IF NOT EXISTS "background_check_status" TEXT;
ALTER TABLE "therapists" ADD COLUMN IF NOT EXISTS "background_check_completed_at" TIMESTAMP(3);
ALTER TABLE "therapists" ADD COLUMN IF NOT EXISTS "hipaa_training_attested_at" TIMESTAMP(3);
ALTER TABLE "therapists" ADD COLUMN IF NOT EXISTS "confidentiality_agreement_signed_at" TIMESTAMP(3);
ALTER TABLE "therapists" ADD COLUMN IF NOT EXISTS "agency_approved_at" TIMESTAMP(3);
ALTER TABLE "therapists" ADD COLUMN IF NOT EXISTS "agency_approved_by_id" UUID;
ALTER TABLE "therapists" ADD COLUMN IF NOT EXISTS "onboarding_status" "ProviderOnboardingStatus" NOT NULL DEFAULT 'PENDING';
ALTER TABLE "therapists" ADD COLUMN IF NOT EXISTS "phi_access_approved" BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS "therapists_onboarding_status_idx" ON "therapists"("onboarding_status");

ALTER TABLE "therapists" ADD CONSTRAINT "therapists_agency_approved_by_id_fkey"
  FOREIGN KEY ("agency_approved_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- Audit log enhancements
ALTER TABLE "audit_logs" ADD COLUMN IF NOT EXISTS "actor_role" TEXT;
ALTER TABLE "audit_logs" ADD COLUMN IF NOT EXISTS "patient_id" UUID;
ALTER TABLE "audit_logs" ADD COLUMN IF NOT EXISTS "success" BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE "audit_logs" ADD COLUMN IF NOT EXISTS "device_id" TEXT;

CREATE INDEX IF NOT EXISTS "audit_logs_actor_role_idx" ON "audit_logs"("actor_role");
CREATE INDEX IF NOT EXISTS "audit_logs_patient_id_idx" ON "audit_logs"("patient_id");

-- Insurance claim security fields
ALTER TABLE "insurance_claims" ADD COLUMN IF NOT EXISTS "therapist_id" UUID;
ALTER TABLE "insurance_claims" ADD COLUMN IF NOT EXISTS "created_by_id" UUID;
ALTER TABLE "insurance_claims" ADD COLUMN IF NOT EXISTS "submitted_by_id" UUID;
ALTER TABLE "insurance_claims" ADD COLUMN IF NOT EXISTS "resubmission_of_id" UUID;
ALTER TABLE "insurance_claims" ADD COLUMN IF NOT EXISTS "payment_status" TEXT;
ALTER TABLE "insurance_claims" ADD COLUMN IF NOT EXISTS "cpt_code" TEXT;
ALTER TABLE "insurance_claims" ADD COLUMN IF NOT EXISTS "authorization_number" TEXT;
ALTER TABLE "insurance_claims" ADD COLUMN IF NOT EXISTS "locked_at" TIMESTAMP(3);
ALTER TABLE "insurance_claims" ADD COLUMN IF NOT EXISTS "duplicate_hash" TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS "insurance_claims_resubmission_of_id_key" ON "insurance_claims"("resubmission_of_id");
CREATE INDEX IF NOT EXISTS "insurance_claims_therapist_id_idx" ON "insurance_claims"("therapist_id");
CREATE INDEX IF NOT EXISTS "insurance_claims_duplicate_hash_idx" ON "insurance_claims"("duplicate_hash");

ALTER TABLE "insurance_claims" ADD CONSTRAINT "insurance_claims_therapist_id_fkey"
  FOREIGN KEY ("therapist_id") REFERENCES "therapists"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "insurance_claims" ADD CONSTRAINT "insurance_claims_created_by_id_fkey"
  FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "insurance_claims" ADD CONSTRAINT "insurance_claims_submitted_by_id_fkey"
  FOREIGN KEY ("submitted_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "insurance_claims" ADD CONSTRAINT "insurance_claims_resubmission_of_id_fkey"
  FOREIGN KEY ("resubmission_of_id") REFERENCES "insurance_claims"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- Claim edit history
CREATE TABLE IF NOT EXISTS "claim_edit_history" (
  "id" UUID NOT NULL,
  "tenant_id" UUID NOT NULL,
  "claim_id" UUID NOT NULL,
  "editor_id" UUID NOT NULL,
  "editor_role" TEXT,
  "action" TEXT NOT NULL,
  "field_changes" JSONB NOT NULL DEFAULT '{}',
  "ip_address" TEXT,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "claim_edit_history_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "claim_edit_history_tenant_id_idx" ON "claim_edit_history"("tenant_id");
CREATE INDEX IF NOT EXISTS "claim_edit_history_claim_id_idx" ON "claim_edit_history"("claim_id");
CREATE INDEX IF NOT EXISTS "claim_edit_history_editor_id_idx" ON "claim_edit_history"("editor_id");
CREATE INDEX IF NOT EXISTS "claim_edit_history_created_at_idx" ON "claim_edit_history"("created_at");

ALTER TABLE "claim_edit_history" ADD CONSTRAINT "claim_edit_history_tenant_id_fkey"
  FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "claim_edit_history" ADD CONSTRAINT "claim_edit_history_claim_id_fkey"
  FOREIGN KEY ("claim_id") REFERENCES "insurance_claims"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "claim_edit_history" ADD CONSTRAINT "claim_edit_history_editor_id_fkey"
  FOREIGN KEY ("editor_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Compliance legal documents
CREATE TABLE IF NOT EXISTS "compliance_documents" (
  "id" UUID NOT NULL,
  "tenant_id" UUID,
  "document_type" "ComplianceDocumentType" NOT NULL,
  "version" TEXT NOT NULL,
  "title" TEXT NOT NULL,
  "content" TEXT NOT NULL,
  "effective_date" TIMESTAMP(3) NOT NULL,
  "is_active" BOOLEAN NOT NULL DEFAULT false,
  "created_by_id" UUID,
  "published_at" TIMESTAMP(3),
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "compliance_documents_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "compliance_documents_tenant_id_document_type_version_key"
  ON "compliance_documents"("tenant_id", "document_type", "version");
CREATE INDEX IF NOT EXISTS "compliance_documents_tenant_id_document_type_is_active_idx"
  ON "compliance_documents"("tenant_id", "document_type", "is_active");

ALTER TABLE "compliance_documents" ADD CONSTRAINT "compliance_documents_tenant_id_fkey"
  FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "compliance_documents" ADD CONSTRAINT "compliance_documents_created_by_id_fkey"
  FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE TABLE IF NOT EXISTS "compliance_document_acceptances" (
  "id" UUID NOT NULL,
  "tenant_id" UUID NOT NULL,
  "document_id" UUID NOT NULL,
  "user_id" UUID NOT NULL,
  "ip_address" TEXT,
  "user_agent" TEXT,
  "accepted_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "compliance_document_acceptances_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "compliance_document_acceptances_user_id_document_id_key"
  ON "compliance_document_acceptances"("user_id", "document_id");
CREATE INDEX IF NOT EXISTS "compliance_document_acceptances_tenant_id_idx"
  ON "compliance_document_acceptances"("tenant_id");
CREATE INDEX IF NOT EXISTS "compliance_document_acceptances_document_id_idx"
  ON "compliance_document_acceptances"("document_id");

ALTER TABLE "compliance_document_acceptances" ADD CONSTRAINT "compliance_document_acceptances_tenant_id_fkey"
  FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "compliance_document_acceptances" ADD CONSTRAINT "compliance_document_acceptances_document_id_fkey"
  FOREIGN KEY ("document_id") REFERENCES "compliance_documents"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "compliance_document_acceptances" ADD CONSTRAINT "compliance_document_acceptances_user_id_fkey"
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Existing verified providers retain PHI access
UPDATE "therapists"
SET "phi_access_approved" = true,
    "onboarding_status" = 'APPROVED'
WHERE "is_verified" = true;
