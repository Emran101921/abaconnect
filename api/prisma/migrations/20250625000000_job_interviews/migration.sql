-- Job interview scheduling for agency hiring pipeline
CREATE TYPE "JobInterviewStatus" AS ENUM (
  'SCHEDULED',
  'CONFIRMED',
  'IN_PROGRESS',
  'COMPLETED',
  'CANCELLED'
);

CREATE TABLE "job_interviews" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "tenant_id" UUID NOT NULL,
  "agency_id" UUID NOT NULL,
  "application_id" UUID NOT NULL,
  "scheduled_by_user_id" UUID NOT NULL,
  "therapist_user_id" UUID NOT NULL,
  "scheduled_at" TIMESTAMP(3) NOT NULL,
  "duration_minutes" INTEGER NOT NULL DEFAULT 30,
  "status" "JobInterviewStatus" NOT NULL DEFAULT 'SCHEDULED',
  "recording_requested" BOOLEAN NOT NULL DEFAULT false,
  "agency_recording_consent" BOOLEAN NOT NULL DEFAULT false,
  "therapist_recording_consent" BOOLEAN NOT NULL DEFAULT false,
  "notes" TEXT,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,

  CONSTRAINT "job_interviews_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "job_interviews_application_id_key" ON "job_interviews"("application_id");
CREATE INDEX "job_interviews_tenant_id_idx" ON "job_interviews"("tenant_id");
CREATE INDEX "job_interviews_agency_id_idx" ON "job_interviews"("agency_id");
CREATE INDEX "job_interviews_therapist_user_id_idx" ON "job_interviews"("therapist_user_id");
CREATE INDEX "job_interviews_scheduled_at_idx" ON "job_interviews"("scheduled_at");
CREATE INDEX "job_interviews_status_idx" ON "job_interviews"("status");

ALTER TABLE "job_interviews"
  ADD CONSTRAINT "job_interviews_tenant_id_fkey"
  FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "job_interviews"
  ADD CONSTRAINT "job_interviews_agency_id_fkey"
  FOREIGN KEY ("agency_id") REFERENCES "agencies"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "job_interviews"
  ADD CONSTRAINT "job_interviews_application_id_fkey"
  FOREIGN KEY ("application_id") REFERENCES "job_opportunity_applications"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "job_interviews"
  ADD CONSTRAINT "job_interviews_scheduled_by_user_id_fkey"
  FOREIGN KEY ("scheduled_by_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "job_interviews"
  ADD CONSTRAINT "job_interviews_therapist_user_id_fkey"
  FOREIGN KEY ("therapist_user_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "call_sessions"
  ADD COLUMN "job_interview_id" UUID;

CREATE UNIQUE INDEX "call_sessions_job_interview_id_key" ON "call_sessions"("job_interview_id");

ALTER TABLE "call_sessions"
  ADD CONSTRAINT "call_sessions_job_interview_id_fkey"
  FOREIGN KEY ("job_interview_id") REFERENCES "job_interviews"("id") ON DELETE SET NULL ON UPDATE CASCADE;
