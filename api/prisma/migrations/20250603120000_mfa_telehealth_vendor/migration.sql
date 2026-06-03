-- MFA on users and telehealth vendor tag
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "mfa_secret" TEXT;
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "mfa_enabled" BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE "telehealth_sessions" ADD COLUMN IF NOT EXISTS "vendor" TEXT;
