-- Secure in-app calling: sessions, participants, audit logs, notifications

CREATE TYPE "CallType" AS ENUM ('AUDIO', 'VIDEO');
CREATE TYPE "CallSessionStatus" AS ENUM (
  'INITIATED', 'RINGING', 'ACCEPTED', 'IN_PROGRESS', 'DECLINED',
  'MISSED', 'FAILED', 'ENDED', 'CANCELLED'
);
CREATE TYPE "CallParticipantJoinStatus" AS ENUM (
  'INVITED', 'RINGING', 'JOINED', 'LEFT', 'DECLINED', 'MISSED'
);
CREATE TYPE "CallAuditEventType" AS ENUM (
  'CALL_INITIATED', 'CALL_RINGING', 'CALL_ACCEPTED', 'CALL_DECLINED',
  'CALL_MISSED', 'CALL_FAILED', 'CALL_ENDED', 'CALL_CANCELLED',
  'CALL_PERMISSION_DENIED', 'CALL_TOKEN_CREATED', 'CALL_TOKEN_EXPIRED'
);

ALTER TABLE "agencies" ADD COLUMN "calling_enabled" BOOLEAN NOT NULL DEFAULT true;

CREATE TABLE "call_sessions" (
  "id" UUID NOT NULL,
  "tenant_id" UUID NOT NULL,
  "agency_id" UUID,
  "child_id" UUID,
  "call_type" "CallType" NOT NULL,
  "status" "CallSessionStatus" NOT NULL DEFAULT 'INITIATED',
  "initiated_by_user_id" UUID NOT NULL,
  "provider_name" TEXT NOT NULL,
  "provider_room_id" TEXT,
  "started_at" TIMESTAMP(3),
  "ended_at" TIMESTAMP(3),
  "duration_seconds" INTEGER,
  "ringing_expires_at" TIMESTAMP(3),
  "failure_reason" TEXT,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "call_sessions_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "call_participants" (
  "id" UUID NOT NULL,
  "call_session_id" UUID NOT NULL,
  "user_id" UUID NOT NULL,
  "role" "UserRole" NOT NULL,
  "join_status" "CallParticipantJoinStatus" NOT NULL DEFAULT 'INVITED',
  "joined_at" TIMESTAMP(3),
  "left_at" TIMESTAMP(3),
  "device_info" JSONB,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "call_participants_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "call_audit_logs" (
  "id" UUID NOT NULL,
  "tenant_id" UUID NOT NULL,
  "call_session_id" UUID NOT NULL,
  "agency_id" UUID,
  "child_id" UUID,
  "actor_user_id" UUID NOT NULL,
  "actor_role" "UserRole" NOT NULL,
  "target_user_id" UUID,
  "target_role" "UserRole",
  "event_type" "CallAuditEventType" NOT NULL,
  "call_type" "CallType",
  "call_status" "CallSessionStatus",
  "call_start_time" TIMESTAMP(3),
  "call_end_time" TIMESTAMP(3),
  "call_duration_seconds" INTEGER,
  "event_details" JSONB NOT NULL DEFAULT '{}',
  "reason" TEXT,
  "device_type" TEXT,
  "ip_address" TEXT,
  "user_agent" TEXT,
  "immutable_hash" TEXT,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "created_by" UUID NOT NULL,
  CONSTRAINT "call_audit_logs_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "call_notifications" (
  "id" UUID NOT NULL,
  "tenant_id" UUID NOT NULL,
  "call_session_id" UUID NOT NULL,
  "user_id" UUID NOT NULL,
  "title" TEXT NOT NULL,
  "body" TEXT NOT NULL,
  "data" JSONB NOT NULL DEFAULT '{}',
  "delivered_at" TIMESTAMP(3),
  "read_at" TIMESTAMP(3),
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "call_notifications_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "call_consent_settings" (
  "id" UUID NOT NULL,
  "agency_id" UUID NOT NULL,
  "recording_enabled" BOOLEAN NOT NULL DEFAULT false,
  "consent_required" BOOLEAN NOT NULL DEFAULT true,
  "retention_days" INTEGER NOT NULL DEFAULT 90,
  "updated_by_id" UUID,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "call_consent_settings_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "call_participants_call_session_id_user_id_key"
  ON "call_participants"("call_session_id", "user_id");
CREATE UNIQUE INDEX "call_consent_settings_agency_id_key"
  ON "call_consent_settings"("agency_id");

CREATE INDEX "call_sessions_tenant_id_idx" ON "call_sessions"("tenant_id");
CREATE INDEX "call_sessions_agency_id_idx" ON "call_sessions"("agency_id");
CREATE INDEX "call_sessions_child_id_idx" ON "call_sessions"("child_id");
CREATE INDEX "call_sessions_initiated_by_user_id_idx" ON "call_sessions"("initiated_by_user_id");
CREATE INDEX "call_sessions_status_idx" ON "call_sessions"("status");
CREATE INDEX "call_sessions_created_at_idx" ON "call_sessions"("created_at");

CREATE INDEX "call_participants_call_session_id_idx" ON "call_participants"("call_session_id");
CREATE INDEX "call_participants_user_id_idx" ON "call_participants"("user_id");

CREATE INDEX "call_audit_logs_tenant_id_idx" ON "call_audit_logs"("tenant_id");
CREATE INDEX "call_audit_logs_call_session_id_idx" ON "call_audit_logs"("call_session_id");
CREATE INDEX "call_audit_logs_agency_id_idx" ON "call_audit_logs"("agency_id");
CREATE INDEX "call_audit_logs_child_id_idx" ON "call_audit_logs"("child_id");
CREATE INDEX "call_audit_logs_actor_user_id_idx" ON "call_audit_logs"("actor_user_id");
CREATE INDEX "call_audit_logs_target_user_id_idx" ON "call_audit_logs"("target_user_id");
CREATE INDEX "call_audit_logs_event_type_idx" ON "call_audit_logs"("event_type");
CREATE INDEX "call_audit_logs_created_at_idx" ON "call_audit_logs"("created_at");

CREATE INDEX "call_notifications_tenant_id_idx" ON "call_notifications"("tenant_id");
CREATE INDEX "call_notifications_call_session_id_idx" ON "call_notifications"("call_session_id");
CREATE INDEX "call_notifications_user_id_idx" ON "call_notifications"("user_id");

ALTER TABLE "call_sessions" ADD CONSTRAINT "call_sessions_tenant_id_fkey"
  FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "call_sessions" ADD CONSTRAINT "call_sessions_agency_id_fkey"
  FOREIGN KEY ("agency_id") REFERENCES "agencies"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "call_sessions" ADD CONSTRAINT "call_sessions_child_id_fkey"
  FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "call_sessions" ADD CONSTRAINT "call_sessions_initiated_by_user_id_fkey"
  FOREIGN KEY ("initiated_by_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "call_participants" ADD CONSTRAINT "call_participants_call_session_id_fkey"
  FOREIGN KEY ("call_session_id") REFERENCES "call_sessions"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "call_participants" ADD CONSTRAINT "call_participants_user_id_fkey"
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "call_audit_logs" ADD CONSTRAINT "call_audit_logs_tenant_id_fkey"
  FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "call_audit_logs" ADD CONSTRAINT "call_audit_logs_call_session_id_fkey"
  FOREIGN KEY ("call_session_id") REFERENCES "call_sessions"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "call_audit_logs" ADD CONSTRAINT "call_audit_logs_agency_id_fkey"
  FOREIGN KEY ("agency_id") REFERENCES "agencies"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "call_audit_logs" ADD CONSTRAINT "call_audit_logs_actor_user_id_fkey"
  FOREIGN KEY ("actor_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "call_audit_logs" ADD CONSTRAINT "call_audit_logs_target_user_id_fkey"
  FOREIGN KEY ("target_user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "call_notifications" ADD CONSTRAINT "call_notifications_tenant_id_fkey"
  FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "call_notifications" ADD CONSTRAINT "call_notifications_call_session_id_fkey"
  FOREIGN KEY ("call_session_id") REFERENCES "call_sessions"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "call_notifications" ADD CONSTRAINT "call_notifications_user_id_fkey"
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "call_consent_settings" ADD CONSTRAINT "call_consent_settings_agency_id_fkey"
  FOREIGN KEY ("agency_id") REFERENCES "agencies"("id") ON DELETE CASCADE ON UPDATE CASCADE;
