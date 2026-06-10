-- CreateTable
CREATE TABLE "auth_devices" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "device_id" TEXT NOT NULL,
    "device_model" TEXT,
    "platform" TEXT,
    "os_version" TEXT,
    "trusted" BOOLEAN NOT NULL DEFAULT false,
    "last_ip" TEXT,
    "last_location" TEXT,
    "last_latitude" DECIMAL(10,7),
    "last_longitude" DECIMAL(10,7),
    "first_seen_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "last_seen_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "mfa_verified_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "auth_devices_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "auth_devices_user_id_idx" ON "auth_devices"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "auth_devices_user_id_device_id_key" ON "auth_devices"("user_id", "device_id");

-- AddForeignKey
ALTER TABLE "auth_devices" ADD CONSTRAINT "auth_devices_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
