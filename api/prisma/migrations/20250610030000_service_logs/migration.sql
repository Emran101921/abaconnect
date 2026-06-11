-- CreateTable
CREATE TABLE "service_logs" (
    "id" UUID NOT NULL,
    "tenant_id" UUID NOT NULL,
    "session_id" UUID NOT NULL,
    "soap_note_id" UUID NOT NULL,
    "child_id" UUID NOT NULL,
    "therapist_id" UUID NOT NULL,
    "parent_signature_name" TEXT NOT NULL,
    "parent_signature_date" TEXT,
    "parent_signed_at" TIMESTAMP(3) NOT NULL,
    "parent_signature_lat" DECIMAL(10,7),
    "parent_signature_lng" DECIMAL(10,7),
    "log_data" JSONB NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "service_logs_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "service_logs_session_id_key" ON "service_logs"("session_id");

-- CreateIndex
CREATE UNIQUE INDEX "service_logs_soap_note_id_key" ON "service_logs"("soap_note_id");

-- CreateIndex
CREATE INDEX "service_logs_tenant_id_idx" ON "service_logs"("tenant_id");

-- CreateIndex
CREATE INDEX "service_logs_child_id_idx" ON "service_logs"("child_id");

-- CreateIndex
CREATE INDEX "service_logs_therapist_id_idx" ON "service_logs"("therapist_id");

-- CreateIndex
CREATE INDEX "service_logs_parent_signed_at_idx" ON "service_logs"("parent_signed_at");

-- AddForeignKey
ALTER TABLE "service_logs" ADD CONSTRAINT "service_logs_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "sessions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "service_logs" ADD CONSTRAINT "service_logs_soap_note_id_fkey" FOREIGN KEY ("soap_note_id") REFERENCES "soap_notes"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "service_logs" ADD CONSTRAINT "service_logs_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "service_logs" ADD CONSTRAINT "service_logs_therapist_id_fkey" FOREIGN KEY ("therapist_id") REFERENCES "therapists"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "service_logs" ADD CONSTRAINT "service_logs_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id") ON DELETE CASCADE ON UPDATE CASCADE;
