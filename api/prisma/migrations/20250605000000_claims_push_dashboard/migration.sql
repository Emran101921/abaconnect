-- Link insurance claims to sessions for auto-assembly
ALTER TABLE "insurance_claims" ADD COLUMN IF NOT EXISTS "session_id" UUID;
CREATE UNIQUE INDEX IF NOT EXISTS "insurance_claims_session_id_key" ON "insurance_claims"("session_id");
ALTER TABLE "insurance_claims"
  ADD CONSTRAINT "insurance_claims_session_id_fkey"
  FOREIGN KEY ("session_id") REFERENCES "sessions"("id") ON DELETE SET NULL ON UPDATE CASCADE;
