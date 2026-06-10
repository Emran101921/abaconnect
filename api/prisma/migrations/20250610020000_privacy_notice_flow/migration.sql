-- CreateEnum
CREATE TYPE "PrivacyRightsRequestType" AS ENUM ('RECORD_ACCESS', 'CORRECTION', 'RESTRICTION', 'CONFIDENTIAL_COMMUNICATION', 'ACCOUNTING_OF_DISCLOSURES', 'CONTACT_PRIVACY_OFFICER', 'DATA_DELETION');

-- CreateEnum
CREATE TYPE "PrivacyRightsRequestStatus" AS ENUM ('NEW', 'IN_REVIEW', 'COMPLETED', 'DENIED', 'NEEDS_MORE_INFO');

-- CreateTable
CREATE TABLE "privacy_notice_versions" (
    "id" UUID NOT NULL,
    "tenant_id" UUID,
    "version_number" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "full_notice_text" TEXT NOT NULL,
    "privacy_policy_text" TEXT NOT NULL,
    "effective_date" TIMESTAMP(3) NOT NULL,
    "is_active" BOOLEAN NOT NULL DEFAULT false,
    "created_by_user_id" UUID,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "privacy_notice_versions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "hipaa_notice_acknowledgments" (
    "id" UUID NOT NULL,
    "tenant_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "notice_version_id" UUID NOT NULL,
    "notice_version" TEXT NOT NULL,
    "acknowledged_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "ip_address" TEXT,
    "user_agent" TEXT,
    "app_version" TEXT,
    "platform" TEXT,
    "device_id" TEXT,
    "acknowledgment_text_snapshot" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "hipaa_notice_acknowledgments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "privacy_rights_requests" (
    "id" UUID NOT NULL,
    "tenant_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "request_type" "PrivacyRightsRequestType" NOT NULL,
    "status" "PrivacyRightsRequestStatus" NOT NULL DEFAULT 'NEW',
    "payload" JSONB NOT NULL DEFAULT '{}',
    "internal_notes" TEXT,
    "admin_response_document_key" TEXT,
    "ip_address" TEXT,
    "user_agent" TEXT,
    "submitted_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "completed_at" TIMESTAMP(3),
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "privacy_rights_requests_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "privacy_notice_versions_tenant_id_idx" ON "privacy_notice_versions"("tenant_id");
CREATE INDEX "privacy_notice_versions_is_active_idx" ON "privacy_notice_versions"("is_active");
CREATE UNIQUE INDEX "privacy_notice_versions_tenant_id_version_number_key" ON "privacy_notice_versions"("tenant_id", "version_number");

-- CreateIndex
CREATE INDEX "hipaa_notice_acknowledgments_tenant_id_idx" ON "hipaa_notice_acknowledgments"("tenant_id");
CREATE INDEX "hipaa_notice_acknowledgments_user_id_idx" ON "hipaa_notice_acknowledgments"("user_id");
CREATE INDEX "hipaa_notice_acknowledgments_notice_version_id_idx" ON "hipaa_notice_acknowledgments"("notice_version_id");
CREATE INDEX "hipaa_notice_acknowledgments_acknowledged_at_idx" ON "hipaa_notice_acknowledgments"("acknowledged_at");

-- CreateIndex
CREATE INDEX "privacy_rights_requests_tenant_id_idx" ON "privacy_rights_requests"("tenant_id");
CREATE INDEX "privacy_rights_requests_user_id_idx" ON "privacy_rights_requests"("user_id");
CREATE INDEX "privacy_rights_requests_status_idx" ON "privacy_rights_requests"("status");
CREATE INDEX "privacy_rights_requests_request_type_idx" ON "privacy_rights_requests"("request_type");

-- AddForeignKey
ALTER TABLE "privacy_notice_versions" ADD CONSTRAINT "privacy_notice_versions_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "privacy_notice_versions" ADD CONSTRAINT "privacy_notice_versions_created_by_user_id_fkey" FOREIGN KEY ("created_by_user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "hipaa_notice_acknowledgments" ADD CONSTRAINT "hipaa_notice_acknowledgments_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "hipaa_notice_acknowledgments" ADD CONSTRAINT "hipaa_notice_acknowledgments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "hipaa_notice_acknowledgments" ADD CONSTRAINT "hipaa_notice_acknowledgments_notice_version_id_fkey" FOREIGN KEY ("notice_version_id") REFERENCES "privacy_notice_versions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "privacy_rights_requests" ADD CONSTRAINT "privacy_rights_requests_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "privacy_rights_requests" ADD CONSTRAINT "privacy_rights_requests_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
