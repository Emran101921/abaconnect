-- CreateEnum
CREATE TYPE "AgencyDocumentType" AS ENUM ('BAA', 'BUSINESS_LICENSE', 'INSURANCE_CERTIFICATE', 'W9', 'OTHER');

-- AlterTable
ALTER TABLE "agencies" ADD COLUMN "onboarding_complete" BOOLEAN NOT NULL DEFAULT false;

-- AlterTable
ALTER TABLE "users" ADD COLUMN "agency_id" UUID;

-- CreateTable
CREATE TABLE "agency_documents" (
    "id" UUID NOT NULL,
    "agency_id" UUID NOT NULL,
    "type" "AgencyDocumentType" NOT NULL,
    "title" TEXT NOT NULL,
    "file_name" TEXT NOT NULL,
    "mime_type" TEXT NOT NULL,
    "storage_key" TEXT NOT NULL,
    "uploaded_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "uploaded_by_id" UUID NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "agency_documents_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "agency_documents_agency_id_idx" ON "agency_documents"("agency_id");

-- CreateIndex
CREATE INDEX "agency_documents_type_idx" ON "agency_documents"("type");

-- CreateIndex
CREATE INDEX "users_agency_id_idx" ON "users"("agency_id");

-- AddForeignKey
ALTER TABLE "users" ADD CONSTRAINT "users_agency_id_fkey" FOREIGN KEY ("agency_id") REFERENCES "agencies"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "agency_documents" ADD CONSTRAINT "agency_documents_agency_id_fkey" FOREIGN KEY ("agency_id") REFERENCES "agencies"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "agency_documents" ADD CONSTRAINT "agency_documents_uploaded_by_id_fkey" FOREIGN KEY ("uploaded_by_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
