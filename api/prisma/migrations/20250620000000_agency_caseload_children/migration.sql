-- Agency caseload children: agency-entered children without a registered parent account

ALTER TABLE "agencies" ADD COLUMN "caseload_parent_id" UUID;

CREATE TABLE "agency_caseload_children" (
    "id" UUID NOT NULL,
    "agency_id" UUID NOT NULL,
    "child_id" UUID NOT NULL,
    "tenant_id" UUID NOT NULL,
    "enrolled_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "enrolled_by_user_id" UUID NOT NULL,

    CONSTRAINT "agency_caseload_children_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "agency_caseload_children_agency_id_child_id_key"
    ON "agency_caseload_children"("agency_id", "child_id");
CREATE INDEX "agency_caseload_children_agency_id_idx"
    ON "agency_caseload_children"("agency_id");
CREATE INDEX "agency_caseload_children_child_id_idx"
    ON "agency_caseload_children"("child_id");
CREATE INDEX "agency_caseload_children_tenant_id_idx"
    ON "agency_caseload_children"("tenant_id");
CREATE INDEX "agencies_caseload_parent_id_idx" ON "agencies"("caseload_parent_id");

ALTER TABLE "agencies"
    ADD CONSTRAINT "agencies_caseload_parent_id_fkey"
    FOREIGN KEY ("caseload_parent_id") REFERENCES "parents"("id")
    ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "agency_caseload_children"
    ADD CONSTRAINT "agency_caseload_children_agency_id_fkey"
    FOREIGN KEY ("agency_id") REFERENCES "agencies"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "agency_caseload_children"
    ADD CONSTRAINT "agency_caseload_children_child_id_fkey"
    FOREIGN KEY ("child_id") REFERENCES "children"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "agency_caseload_children"
    ADD CONSTRAINT "agency_caseload_children_tenant_id_fkey"
    FOREIGN KEY ("tenant_id") REFERENCES "tenants"("id")
    ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "agency_caseload_children"
    ADD CONSTRAINT "agency_caseload_children_enrolled_by_user_id_fkey"
    FOREIGN KEY ("enrolled_by_user_id") REFERENCES "users"("id")
    ON DELETE RESTRICT ON UPDATE CASCADE;
