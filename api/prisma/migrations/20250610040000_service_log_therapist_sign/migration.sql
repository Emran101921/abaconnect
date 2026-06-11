-- AlterTable
ALTER TABLE "service_logs" ADD COLUMN "therapist_signature_name" TEXT;
ALTER TABLE "service_logs" ADD COLUMN "therapist_signed_at" TIMESTAMP(3);

-- Make parent signature fields optional (log created when therapist signs)
ALTER TABLE "service_logs" ALTER COLUMN "parent_signature_name" DROP NOT NULL;
ALTER TABLE "service_logs" ALTER COLUMN "parent_signed_at" DROP NOT NULL;

-- CreateIndex
CREATE INDEX "service_logs_therapist_signed_at_idx" ON "service_logs"("therapist_signed_at");
