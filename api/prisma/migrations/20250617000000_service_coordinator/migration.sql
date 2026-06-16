-- Service Coordinator role and EI case management tables

ALTER TYPE "UserRole" ADD VALUE IF NOT EXISTS 'SERVICE_COORDINATOR';

CREATE TYPE "AgencyRosterMemberRole" AS ENUM ('SERVICE_COORDINATOR', 'ADMIN_STAFF');
CREATE TYPE "AgencyRosterStatus" AS ENUM ('ACTIVE', 'INACTIVE', 'SUSPENDED', 'PENDING');
CREATE TYPE "ChildScAssignmentStatus" AS ENUM ('ACTIVE', 'REMOVED');
CREATE TYPE "EiScreeningPriority" AS ENUM ('LOW', 'MEDIUM', 'HIGH');
CREATE TYPE "EiScreeningStatus" AS ENUM ('DRAFT', 'SUBMITTED');

ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "created_by_id" UUID;

ALTER TABLE "users" DROP CONSTRAINT IF EXISTS "users_created_by_id_fkey";
ALTER TABLE "users"
  ADD CONSTRAINT "users_created_by_id_fkey"
  FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE TABLE IF NOT EXISTS "agency_roster" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "agency_id" UUID NOT NULL,
  "user_id" UUID NOT NULL,
  "role" "AgencyRosterMemberRole" NOT NULL,
  "status" "AgencyRosterStatus" NOT NULL DEFAULT 'PENDING',
  "languages" TEXT[] DEFAULT ARRAY[]::TEXT[],
  "notes" TEXT,
  "added_by_id" UUID NOT NULL,
  "added_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "removed_at" TIMESTAMP(3),
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,

  CONSTRAINT "agency_roster_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "agency_roster_agency_id_user_id_key" ON "agency_roster"("agency_id", "user_id");
CREATE INDEX IF NOT EXISTS "agency_roster_agency_id_idx" ON "agency_roster"("agency_id");
CREATE INDEX IF NOT EXISTS "agency_roster_user_id_idx" ON "agency_roster"("user_id");
CREATE INDEX IF NOT EXISTS "agency_roster_status_idx" ON "agency_roster"("status");

ALTER TABLE "agency_roster" DROP CONSTRAINT IF EXISTS "agency_roster_agency_id_fkey";
ALTER TABLE "agency_roster"
  ADD CONSTRAINT "agency_roster_agency_id_fkey"
  FOREIGN KEY ("agency_id") REFERENCES "agencies"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "agency_roster" DROP CONSTRAINT IF EXISTS "agency_roster_user_id_fkey";
ALTER TABLE "agency_roster"
  ADD CONSTRAINT "agency_roster_user_id_fkey"
  FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "agency_roster" DROP CONSTRAINT IF EXISTS "agency_roster_added_by_id_fkey";
ALTER TABLE "agency_roster"
  ADD CONSTRAINT "agency_roster_added_by_id_fkey"
  FOREIGN KEY ("added_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE TABLE IF NOT EXISTS "child_service_coordinator_assignments" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "child_id" UUID NOT NULL,
  "service_coordinator_id" UUID NOT NULL,
  "agency_id" UUID NOT NULL,
  "assigned_by_id" UUID NOT NULL,
  "assigned_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "status" "ChildScAssignmentStatus" NOT NULL DEFAULT 'ACTIVE',
  "is_urgent" BOOLEAN NOT NULL DEFAULT false,
  "removed_at" TIMESTAMP(3),
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,

  CONSTRAINT "child_service_coordinator_assignments_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "child_service_coordinator_assignments_child_id_service_coordinator_id_agency_id_key"
  ON "child_service_coordinator_assignments"("child_id", "service_coordinator_id", "agency_id");
CREATE INDEX IF NOT EXISTS "child_service_coordinator_assignments_child_id_idx" ON "child_service_coordinator_assignments"("child_id");
CREATE INDEX IF NOT EXISTS "child_service_coordinator_assignments_service_coordinator_id_idx" ON "child_service_coordinator_assignments"("service_coordinator_id");
CREATE INDEX IF NOT EXISTS "child_service_coordinator_assignments_agency_id_idx" ON "child_service_coordinator_assignments"("agency_id");
CREATE INDEX IF NOT EXISTS "child_service_coordinator_assignments_status_idx" ON "child_service_coordinator_assignments"("status");

ALTER TABLE "child_service_coordinator_assignments" DROP CONSTRAINT IF EXISTS "child_service_coordinator_assignments_child_id_fkey";
ALTER TABLE "child_service_coordinator_assignments"
  ADD CONSTRAINT "child_service_coordinator_assignments_child_id_fkey"
  FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "child_service_coordinator_assignments" DROP CONSTRAINT IF EXISTS "child_service_coordinator_assignments_service_coordinator_id_fkey";
ALTER TABLE "child_service_coordinator_assignments"
  ADD CONSTRAINT "child_service_coordinator_assignments_service_coordinator_id_fkey"
  FOREIGN KEY ("service_coordinator_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "child_service_coordinator_assignments" DROP CONSTRAINT IF EXISTS "child_service_coordinator_assignments_agency_id_fkey";
ALTER TABLE "child_service_coordinator_assignments"
  ADD CONSTRAINT "child_service_coordinator_assignments_agency_id_fkey"
  FOREIGN KEY ("agency_id") REFERENCES "agencies"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "child_service_coordinator_assignments" DROP CONSTRAINT IF EXISTS "child_service_coordinator_assignments_assigned_by_id_fkey";
ALTER TABLE "child_service_coordinator_assignments"
  ADD CONSTRAINT "child_service_coordinator_assignments_assigned_by_id_fkey"
  FOREIGN KEY ("assigned_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE TABLE IF NOT EXISTS "ei_initial_screenings" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "child_id" UUID NOT NULL,
  "parent_id" UUID NOT NULL,
  "agency_id" UUID NOT NULL,
  "service_coordinator_id" UUID NOT NULL,
  "answers_json" JSONB NOT NULL DEFAULT '{}',
  "status" "EiScreeningStatus" NOT NULL DEFAULT 'DRAFT',
  "priority_level" "EiScreeningPriority" NOT NULL DEFAULT 'LOW',
  "follow_up_required" BOOLEAN NOT NULL DEFAULT false,
  "follow_up_due_date" DATE,
  "notes" TEXT,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,

  CONSTRAINT "ei_initial_screenings_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "ei_initial_screenings_child_id_idx" ON "ei_initial_screenings"("child_id");
CREATE INDEX IF NOT EXISTS "ei_initial_screenings_service_coordinator_id_idx" ON "ei_initial_screenings"("service_coordinator_id");
CREATE INDEX IF NOT EXISTS "ei_initial_screenings_agency_id_idx" ON "ei_initial_screenings"("agency_id");

ALTER TABLE "ei_initial_screenings" DROP CONSTRAINT IF EXISTS "ei_initial_screenings_child_id_fkey";
ALTER TABLE "ei_initial_screenings"
  ADD CONSTRAINT "ei_initial_screenings_child_id_fkey"
  FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ei_initial_screenings" DROP CONSTRAINT IF EXISTS "ei_initial_screenings_parent_id_fkey";
ALTER TABLE "ei_initial_screenings"
  ADD CONSTRAINT "ei_initial_screenings_parent_id_fkey"
  FOREIGN KEY ("parent_id") REFERENCES "parents"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ei_initial_screenings" DROP CONSTRAINT IF EXISTS "ei_initial_screenings_agency_id_fkey";
ALTER TABLE "ei_initial_screenings"
  ADD CONSTRAINT "ei_initial_screenings_agency_id_fkey"
  FOREIGN KEY ("agency_id") REFERENCES "agencies"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ei_initial_screenings" DROP CONSTRAINT IF EXISTS "ei_initial_screenings_service_coordinator_id_fkey";
ALTER TABLE "ei_initial_screenings"
  ADD CONSTRAINT "ei_initial_screenings_service_coordinator_id_fkey"
  FOREIGN KEY ("service_coordinator_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE IF NOT EXISTS "ei_ongoing_screenings" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "child_id" UUID NOT NULL,
  "parent_id" UUID NOT NULL,
  "agency_id" UUID NOT NULL,
  "service_coordinator_id" UUID NOT NULL,
  "answers_json" JSONB NOT NULL DEFAULT '{}',
  "status" "EiScreeningStatus" NOT NULL DEFAULT 'DRAFT',
  "progress_summary" TEXT,
  "new_concerns" TEXT,
  "priority_level" "EiScreeningPriority" NOT NULL DEFAULT 'LOW',
  "follow_up_required" BOOLEAN NOT NULL DEFAULT false,
  "follow_up_due_date" DATE,
  "notes" TEXT,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,

  CONSTRAINT "ei_ongoing_screenings_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "ei_ongoing_screenings_child_id_idx" ON "ei_ongoing_screenings"("child_id");
CREATE INDEX IF NOT EXISTS "ei_ongoing_screenings_service_coordinator_id_idx" ON "ei_ongoing_screenings"("service_coordinator_id");
CREATE INDEX IF NOT EXISTS "ei_ongoing_screenings_agency_id_idx" ON "ei_ongoing_screenings"("agency_id");

ALTER TABLE "ei_ongoing_screenings" DROP CONSTRAINT IF EXISTS "ei_ongoing_screenings_child_id_fkey";
ALTER TABLE "ei_ongoing_screenings"
  ADD CONSTRAINT "ei_ongoing_screenings_child_id_fkey"
  FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ei_ongoing_screenings" DROP CONSTRAINT IF EXISTS "ei_ongoing_screenings_parent_id_fkey";
ALTER TABLE "ei_ongoing_screenings"
  ADD CONSTRAINT "ei_ongoing_screenings_parent_id_fkey"
  FOREIGN KEY ("parent_id") REFERENCES "parents"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ei_ongoing_screenings" DROP CONSTRAINT IF EXISTS "ei_ongoing_screenings_agency_id_fkey";
ALTER TABLE "ei_ongoing_screenings"
  ADD CONSTRAINT "ei_ongoing_screenings_agency_id_fkey"
  FOREIGN KEY ("agency_id") REFERENCES "agencies"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ei_ongoing_screenings" DROP CONSTRAINT IF EXISTS "ei_ongoing_screenings_service_coordinator_id_fkey";
ALTER TABLE "ei_ongoing_screenings"
  ADD CONSTRAINT "ei_ongoing_screenings_service_coordinator_id_fkey"
  FOREIGN KEY ("service_coordinator_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE IF NOT EXISTS "service_coordination_notes" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "child_id" UUID NOT NULL,
  "parent_id" UUID NOT NULL,
  "agency_id" UUID NOT NULL,
  "service_coordinator_id" UUID NOT NULL,
  "note_type" TEXT NOT NULL,
  "note_text" TEXT NOT NULL,
  "action_required" BOOLEAN NOT NULL DEFAULT false,
  "action_due_date" DATE,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,

  CONSTRAINT "service_coordination_notes_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "service_coordination_notes_child_id_idx" ON "service_coordination_notes"("child_id");
CREATE INDEX IF NOT EXISTS "service_coordination_notes_service_coordinator_id_idx" ON "service_coordination_notes"("service_coordinator_id");
CREATE INDEX IF NOT EXISTS "service_coordination_notes_agency_id_idx" ON "service_coordination_notes"("agency_id");

ALTER TABLE "service_coordination_notes" DROP CONSTRAINT IF EXISTS "service_coordination_notes_child_id_fkey";
ALTER TABLE "service_coordination_notes"
  ADD CONSTRAINT "service_coordination_notes_child_id_fkey"
  FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "service_coordination_notes" DROP CONSTRAINT IF EXISTS "service_coordination_notes_parent_id_fkey";
ALTER TABLE "service_coordination_notes"
  ADD CONSTRAINT "service_coordination_notes_parent_id_fkey"
  FOREIGN KEY ("parent_id") REFERENCES "parents"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "service_coordination_notes" DROP CONSTRAINT IF EXISTS "service_coordination_notes_agency_id_fkey";
ALTER TABLE "service_coordination_notes"
  ADD CONSTRAINT "service_coordination_notes_agency_id_fkey"
  FOREIGN KEY ("agency_id") REFERENCES "agencies"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "service_coordination_notes" DROP CONSTRAINT IF EXISTS "service_coordination_notes_service_coordinator_id_fkey";
ALTER TABLE "service_coordination_notes"
  ADD CONSTRAINT "service_coordination_notes_service_coordinator_id_fkey"
  FOREIGN KEY ("service_coordinator_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
