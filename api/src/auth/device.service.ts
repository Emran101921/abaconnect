import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { GeoIpService } from '../security/geoip.service';
import { SecurityEventService } from '../security/security-event.service';

export interface DeviceContext {
  deviceId?: string;
  deviceModel?: string;
  platform?: string;
  osVersion?: string;
  ipAddress?: string;
  userAgent?: string;
}

interface DeviceOwner {
  id: string;
  tenantId: string;
}

export interface RecordLoginResult {
  /** True when this device has never completed MFA on this account before. */
  isNewDevice: boolean;
  deviceId?: string;
}

@Injectable()
export class DeviceService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly geoip: GeoIpService,
    private readonly securityEvents: SecurityEventService,
  ) {}

  /**
   * Records (or updates) the device a user is logging in from and reports
   * whether it is a previously-untrusted/new device. New devices always
   * trigger a step-up MFA challenge upstream.
   */
  async recordLogin(
    user: DeviceOwner,
    ctx?: DeviceContext,
  ): Promise<RecordLoginResult> {
    if (!ctx?.deviceId) {
      // No device fingerprint (e.g. legacy client) — treat as untrusted so a
      // fresh MFA challenge is required, but nothing to persist.
      return { isNewDevice: true };
    }

    const geo = await this.geoip.lookup(ctx.ipAddress);
    const existing = await this.prisma.authDevice.findUnique({
      where: { userId_deviceId: { userId: user.id, deviceId: ctx.deviceId } },
    });
    const isNewDevice = !existing || !existing.trusted;

    await this.prisma.authDevice.upsert({
      where: { userId_deviceId: { userId: user.id, deviceId: ctx.deviceId } },
      create: {
        userId: user.id,
        deviceId: ctx.deviceId,
        deviceModel: ctx.deviceModel,
        platform: ctx.platform,
        osVersion: ctx.osVersion,
        lastIp: ctx.ipAddress,
        lastLocation: geo?.label,
        lastLatitude: geo?.latitude,
        lastLongitude: geo?.longitude,
        lastSeenAt: new Date(),
      },
      update: {
        deviceModel: ctx.deviceModel ?? existing?.deviceModel,
        platform: ctx.platform ?? existing?.platform,
        osVersion: ctx.osVersion ?? existing?.osVersion,
        lastIp: ctx.ipAddress,
        lastLocation: geo?.label ?? existing?.lastLocation,
        lastLatitude: geo?.latitude ?? existing?.lastLatitude,
        lastLongitude: geo?.longitude ?? existing?.lastLongitude,
        lastSeenAt: new Date(),
      },
    });

    if (isNewDevice) {
      await this.securityEvents.log({
        tenantId: user.tenantId,
        userId: user.id,
        eventType: 'NEW_DEVICE_LOGIN',
        severity: 'WARNING',
        ipAddress: ctx.ipAddress,
        userAgent: ctx.userAgent,
        metadata: this.metadata(ctx, geo?.label),
      });
    }

    return { isNewDevice, deviceId: ctx.deviceId };
  }

  /**
   * Marks the device as trusted after a successful MFA verification (login or
   * step-up). This is what makes a device "known" for future logins.
   */
  async trustAfterMfa(user: DeviceOwner, ctx?: DeviceContext): Promise<void> {
    if (!ctx?.deviceId) return;
    const geo = await this.geoip.lookup(ctx.ipAddress);
    await this.prisma.authDevice.upsert({
      where: { userId_deviceId: { userId: user.id, deviceId: ctx.deviceId } },
      create: {
        userId: user.id,
        deviceId: ctx.deviceId,
        deviceModel: ctx.deviceModel,
        platform: ctx.platform,
        osVersion: ctx.osVersion,
        lastIp: ctx.ipAddress,
        lastLocation: geo?.label,
        lastLatitude: geo?.latitude,
        lastLongitude: geo?.longitude,
        trusted: true,
        mfaVerifiedAt: new Date(),
        lastSeenAt: new Date(),
      },
      update: {
        deviceModel: ctx.deviceModel,
        platform: ctx.platform,
        osVersion: ctx.osVersion,
        lastIp: ctx.ipAddress,
        lastLocation: geo?.label,
        lastLatitude: geo?.latitude,
        lastLongitude: geo?.longitude,
        trusted: true,
        mfaVerifiedAt: new Date(),
        lastSeenAt: new Date(),
      },
    });
    await this.securityEvents.log({
      tenantId: user.tenantId,
      userId: user.id,
      eventType: 'MFA_VERIFIED',
      severity: 'INFO',
      ipAddress: ctx.ipAddress,
      userAgent: ctx.userAgent,
      metadata: this.metadata(ctx, geo?.label),
    });
  }

  /** Records the device that completed MFA enrollment, and trusts it. */
  async recordMfaSetup(user: DeviceOwner, ctx?: DeviceContext): Promise<void> {
    const geo = await this.geoip.lookup(ctx?.ipAddress);
    if (ctx?.deviceId) {
      await this.prisma.authDevice.upsert({
        where: { userId_deviceId: { userId: user.id, deviceId: ctx.deviceId } },
        create: {
          userId: user.id,
          deviceId: ctx.deviceId,
          deviceModel: ctx.deviceModel,
          platform: ctx.platform,
          osVersion: ctx.osVersion,
          lastIp: ctx.ipAddress,
          lastLocation: geo?.label,
          lastLatitude: geo?.latitude,
          lastLongitude: geo?.longitude,
          trusted: true,
          mfaVerifiedAt: new Date(),
          lastSeenAt: new Date(),
        },
        update: {
          deviceModel: ctx.deviceModel,
          platform: ctx.platform,
          osVersion: ctx.osVersion,
          lastIp: ctx.ipAddress,
          lastLocation: geo?.label,
          lastLatitude: geo?.latitude,
          lastLongitude: geo?.longitude,
          trusted: true,
          mfaVerifiedAt: new Date(),
          lastSeenAt: new Date(),
        },
      });
    }
    await this.securityEvents.log({
      tenantId: user.tenantId,
      userId: user.id,
      eventType: 'MFA_ENROLLED',
      severity: 'INFO',
      ipAddress: ctx?.ipAddress,
      userAgent: ctx?.userAgent,
      metadata: this.metadata(ctx, geo?.label),
    });
  }

  async listForUser(userId: string) {
    return this.prisma.authDevice.findMany({
      where: { userId },
      orderBy: { lastSeenAt: 'desc' },
      select: {
        id: true,
        deviceModel: true,
        platform: true,
        osVersion: true,
        trusted: true,
        lastIp: true,
        lastLocation: true,
        firstSeenAt: true,
        lastSeenAt: true,
        mfaVerifiedAt: true,
      },
    });
  }

  private metadata(
    ctx?: DeviceContext,
    location?: string,
  ): Record<string, unknown> {
    return {
      deviceId: ctx?.deviceId,
      deviceModel: ctx?.deviceModel,
      platform: ctx?.platform,
      osVersion: ctx?.osVersion,
      ip: ctx?.ipAddress,
      location: location ?? null,
    };
  }
}
