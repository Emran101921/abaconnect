-- CreateEnum
CREATE TYPE "AppointmentConfirmationStatus" AS ENUM ('PENDING', 'CONFIRMED', 'RESCHEDULE_REQUESTED', 'CANCELLED');

-- AlterTable
ALTER TABLE "appointments" ADD COLUMN "confirmation_status" "AppointmentConfirmationStatus" NOT NULL DEFAULT 'PENDING';
ALTER TABLE "appointments" ADD COLUMN "parent_confirmed_at" TIMESTAMP(3);
ALTER TABLE "appointments" ADD COLUMN "therapist_confirmed_at" TIMESTAMP(3);
ALTER TABLE "appointments" ADD COLUMN "reschedule_requested_by" TEXT;
ALTER TABLE "appointments" ADD COLUMN "proposed_scheduled_start" TIMESTAMP(3);
ALTER TABLE "appointments" ADD COLUMN "proposed_scheduled_end" TIMESTAMP(3);
ALTER TABLE "appointments" ADD COLUMN "reschedule_reason" TEXT;
ALTER TABLE "appointments" ADD COLUMN "cancel_requested_by" TEXT;
