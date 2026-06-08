-- NYC EIP Individual Session Note structured form data
ALTER TABLE "soap_notes" ADD COLUMN IF NOT EXISTS "eip_form_data" JSONB;
