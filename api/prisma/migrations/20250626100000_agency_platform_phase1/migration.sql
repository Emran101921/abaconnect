-- BloomOra agency platform Phase 1: branches, departments, programs, feature modules, settings

ALTER TYPE "UserRole" ADD VALUE IF NOT EXISTS 'DEPARTMENT_ADMIN';
ALTER TYPE "UserRole" ADD VALUE IF NOT EXISTS 'PAYROLL_STAFF';

CREATE TABLE "agency_branches" (
    "id" UUID NOT NULL,
    "agency_id" UUID NOT NULL,
    "tenant_id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "region" TEXT,
    "address_line1" TEXT,
    "address_line2" TEXT,
    "city" TEXT,
    "state" TEXT,
    "zip_code" TEXT,
    "phone" TEXT,
    "email" TEXT,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "agency_branches_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "agency_departments" (
    "id" UUID NOT NULL,
    "agency_id" UUID NOT NULL,
    "tenant_id" UUID NOT NULL,
    "branch_id" UUID,
    "name" TEXT NOT NULL,
    "code" TEXT,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "agency_departments_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "agency_programs" (
    "id" UUID NOT NULL,
    "agency_id" UUID NOT NULL,
    "tenant_id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "code" TEXT,
    "service_type" "TherapyType",
    "description" TEXT,
    "region" TEXT,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "settings" JSONB NOT NULL DEFAULT '{}',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "agency_programs_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "agency_feature_modules" (
    "id" UUID NOT NULL,
    "agency_id" UUID NOT NULL,
    "tenant_id" UUID NOT NULL,
    "module_key" TEXT NOT NULL,
    "enabled" BOOLEAN NOT NULL DEFAULT true,
    "settings" JSONB NOT NULL DEFAULT '{}',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "agency_feature_modules_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "agency_platform_settings" (
    "id" UUID NOT NULL,
    "agency_id" UUID NOT NULL,
    "tenant_id" UUID NOT NULL,
    "settings" JSONB NOT NULL DEFAULT '{}',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "agency_platform_settings_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "agency_permission_grants" (
    "id" UUID NOT NULL,
    "agency_id" UUID NOT NULL,
    "tenant_id" UUID NOT NULL,
    "scope_type" TEXT NOT NULL,
    "scope_id" UUID,
    "permission" TEXT NOT NULL,
    "granted" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "agency_permission_grants_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "agency_feature_modules_agency_id_module_key_key" ON "agency_feature_modules"("agency_id", "module_key");
CREATE UNIQUE INDEX "agency_platform_settings_agency_id_key" ON "agency_platform_settings"("agency_id");

CREATE INDEX "agency_branches_agency_id_idx" ON "agency_branches"("agency_id");
CREATE INDEX "agency_branches_tenant_id_idx" ON "agency_branches"("tenant_id");
CREATE INDEX "agency_departments_agency_id_idx" ON "agency_departments"("agency_id");
CREATE INDEX "agency_departments_tenant_id_idx" ON "agency_departments"("tenant_id");
CREATE INDEX "agency_departments_branch_id_idx" ON "agency_departments"("branch_id");
CREATE INDEX "agency_programs_agency_id_idx" ON "agency_programs"("agency_id");
CREATE INDEX "agency_programs_tenant_id_idx" ON "agency_programs"("tenant_id");
CREATE INDEX "agency_feature_modules_tenant_id_idx" ON "agency_feature_modules"("tenant_id");
CREATE INDEX "agency_platform_settings_tenant_id_idx" ON "agency_platform_settings"("tenant_id");
CREATE INDEX "agency_permission_grants_agency_id_idx" ON "agency_permission_grants"("agency_id");
CREATE INDEX "agency_permission_grants_tenant_id_idx" ON "agency_permission_grants"("tenant_id");
CREATE INDEX "agency_permission_grants_scope_type_scope_id_idx" ON "agency_permission_grants"("scope_type", "scope_id");

ALTER TABLE "agency_branches" ADD CONSTRAINT "agency_branches_agency_id_fkey" FOREIGN KEY ("agency_id") REFERENCES "agencies"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "agency_departments" ADD CONSTRAINT "agency_departments_agency_id_fkey" FOREIGN KEY ("agency_id") REFERENCES "agencies"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "agency_departments" ADD CONSTRAINT "agency_departments_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "agency_branches"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "agency_programs" ADD CONSTRAINT "agency_programs_agency_id_fkey" FOREIGN KEY ("agency_id") REFERENCES "agencies"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "agency_feature_modules" ADD CONSTRAINT "agency_feature_modules_agency_id_fkey" FOREIGN KEY ("agency_id") REFERENCES "agencies"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "agency_platform_settings" ADD CONSTRAINT "agency_platform_settings_agency_id_fkey" FOREIGN KEY ("agency_id") REFERENCES "agencies"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "agency_permission_grants" ADD CONSTRAINT "agency_permission_grants_agency_id_fkey" FOREIGN KEY ("agency_id") REFERENCES "agencies"("id") ON DELETE CASCADE ON UPDATE CASCADE;
