import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';

export interface PushPayload {
  userId: string;
  title: string;
  body: string;
  data?: Record<string, unknown>;
}

@Injectable()
export class PushService {
  private readonly logger = new Logger(PushService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  async sendToUser(
    payload: PushPayload,
  ): Promise<{ sent: number; failed: number }> {
    const devices = await this.prisma.userDevice.findMany({
      where: { userId: payload.userId },
      orderBy: { lastSeenAt: 'desc' },
      take: 20,
    });
    if (devices.length === 0) {
      return { sent: 0, failed: 0 };
    }

    const serverKey = this.config.get<string>('FCM_SERVER_KEY');
    let sent = 0;
    let failed = 0;

    for (const device of devices) {
      const ok = serverKey
        ? await this.sendFcm(serverKey, device.deviceToken, payload)
        : this.logDevPush(device, payload);
      if (ok) sent++;
      else failed++;
    }

    return { sent, failed };
  }

  private logDevPush(
    device: { platform: string; deviceToken: string },
    payload: PushPayload,
  ): boolean {
    this.logger.log(
      `[dev-push] ${device.platform} ${device.deviceToken.slice(0, 24)}… → ${payload.title}`,
    );
    return true;
  }

  private async sendFcm(
    serverKey: string,
    token: string,
    payload: PushPayload,
  ): Promise<boolean> {
    try {
      const response = await fetch('https://fcm.googleapis.com/fcm/send', {
        method: 'POST',
        headers: {
          Authorization: `key=${serverKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          to: token,
          notification: {
            title: payload.title,
            body: payload.body,
          },
          data: this.stringifyData(payload.data),
          priority: 'high',
        }),
      });
      if (!response.ok) {
        this.logger.warn(
          `FCM HTTP ${response.status} for token ${token.slice(0, 12)}…`,
        );
        return false;
      }
      const result = (await response.json()) as {
        failure?: number;
        results?: unknown[];
      };
      if (result.failure && result.failure > 0) {
        await this.prisma.userDevice.deleteMany({
          where: { deviceToken: token },
        });
        return false;
      }
      return true;
    } catch (err) {
      this.logger.warn(`FCM send failed: ${err}`);
      return false;
    }
  }

  private stringifyData(
    data?: Record<string, unknown>,
  ): Record<string, string> | undefined {
    if (!data) return undefined;
    const out: Record<string, string> = {};
    for (const [key, value] of Object.entries(data)) {
      if (value != null) out[key] = String(value);
    }
    return out;
  }
}
