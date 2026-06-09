-- CreateEnum
CREATE TYPE "SecurityEventSeverity" AS ENUM ('INFO', 'WARNING', 'CRITICAL');

-- AlterTable
ALTER TABLE "users" ADD COLUMN "failed_login_attempts" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "users" ADD COLUMN "locked_until" TIMESTAMP(3);

-- AlterTable
ALTER TABLE "agencies" ADD COLUMN "baa_signed_at" TIMESTAMP(3);
ALTER TABLE "agencies" ADD COLUMN "baa_document_key" TEXT;

-- AlterTable
ALTER TABLE "telehealth_sessions" ADD COLUMN "recording_consent_granted" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "telehealth_sessions" ADD COLUMN "recording_consent_at" TIMESTAMP(3);
ALTER TABLE "telehealth_sessions" ADD COLUMN "recording_consent_by_user_id" UUID;

-- CreateTable
CREATE TABLE "security_events" (
    "id" UUID NOT NULL,
    "tenant_id" UUID,
    "user_id" UUID,
    "event_type" TEXT NOT NULL,
    "severity" "SecurityEventSeverity" NOT NULL DEFAULT 'INFO',
    "ip_address" TEXT,
    "user_agent" TEXT,
    "metadata" JSONB NOT NULL DEFAULT '{}',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "security_events_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "security_events_tenant_id_idx" ON "security_events"("tenant_id");
CREATE INDEX "security_events_user_id_idx" ON "security_events"("user_id");
CREATE INDEX "security_events_event_type_idx" ON "security_events"("event_type");
CREATE INDEX "security_events_created_at_idx" ON "security_events"("created_at");

-- AddForeignKey
ALTER TABLE "security_events" ADD CONSTRAINT "security_events_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "security_events" ADD CONSTRAINT "security_events_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
