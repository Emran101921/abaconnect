-- Link upfront self-pay booking payments to appointments
ALTER TABLE "payments" ADD COLUMN "appointment_id" UUID;

CREATE UNIQUE INDEX "payments_appointment_id_key" ON "payments"("appointment_id");

ALTER TABLE "payments" ADD CONSTRAINT "payments_appointment_id_fkey" FOREIGN KEY ("appointment_id") REFERENCES "appointments"("id") ON DELETE SET NULL ON UPDATE CASCADE;
