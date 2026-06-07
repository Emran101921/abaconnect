-- Early Intervention screening: expanded child profile + screening recommendations

ALTER TABLE "children" ADD COLUMN IF NOT EXISTS "primary_language" TEXT;
ALTER TABLE "children" ADD COLUMN IF NOT EXISTS "guardian_name" TEXT;
ALTER TABLE "children" ADD COLUMN IF NOT EXISTS "guardian_phone" TEXT;
ALTER TABLE "children" ADD COLUMN IF NOT EXISTS "guardian_email" TEXT;
ALTER TABLE "children" ADD COLUMN IF NOT EXISTS "address_line1" TEXT;
ALTER TABLE "children" ADD COLUMN IF NOT EXISTS "zip_code" TEXT;
ALTER TABLE "children" ADD COLUMN IF NOT EXISTS "pediatrician_name" TEXT;
ALTER TABLE "children" ADD COLUMN IF NOT EXISTS "insurance_type" TEXT;
ALTER TABLE "children" ADD COLUMN IF NOT EXISTS "had_early_intervention" BOOLEAN;

ALTER TABLE "screening_responses" ADD COLUMN IF NOT EXISTS "recommendations" JSONB NOT NULL DEFAULT '[]';
ALTER TABLE "screening_responses" ADD COLUMN IF NOT EXISTS "is_draft" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "screening_responses" ADD COLUMN IF NOT EXISTS "consent_granted_at" TIMESTAMP(3);
