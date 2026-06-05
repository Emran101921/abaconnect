import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

export interface TelehealthRoomLinks {
  vendor: 'daily' | 'twilio' | 'local';
  roomId: string;
  providerUrl: string;
  patientUrl: string;
}

@Injectable()
export class TelehealthVendorService {
  private readonly logger = new Logger(TelehealthVendorService.name);

  constructor(private readonly config: ConfigService) {}

  getVendorMode(): 'daily' | 'twilio' | 'local' {
    const mode = (this.config.get<string>('TELEHEALTH_VENDOR') ?? 'local')
      .toLowerCase()
      .trim();
    if (mode === 'daily' && this.config.get<string>('DAILY_API_KEY')) {
      return 'daily';
    }
    if (
      mode === 'twilio' &&
      this.config.get<string>('TWILIO_ACCOUNT_SID') &&
      this.config.get<string>('TWILIO_API_KEY_SECRET')
    ) {
      return 'twilio';
    }
    return 'local';
  }

  async createRoomLinks(
    roomId: string,
    labels?: { providerName?: string; patientName?: string },
  ): Promise<TelehealthRoomLinks> {
    const vendor = this.getVendorMode();

    if (vendor === 'daily') {
      return this.createDailyLinks(roomId, labels);
    }
    if (vendor === 'twilio') {
      return this.createTwilioLinks(roomId);
    }
    return this.createLocalLinks(roomId);
  }

  private createLocalLinks(roomId: string): TelehealthRoomLinks {
    const base =
      this.config.get<string>('TELEHEALTH_BASE_URL') ??
      'https://meet.abaconnect.local';
    return {
      vendor: 'local',
      roomId,
      providerUrl: `${base}/${roomId}?role=provider`,
      patientUrl: `${base}/${roomId}?role=patient`,
    };
  }

  private async createDailyLinks(
    roomId: string,
    labels?: { providerName?: string; patientName?: string },
  ): Promise<TelehealthRoomLinks> {
    const apiKey = this.config.get<string>('DAILY_API_KEY')!;
    const domain = this.config.get<string>('DAILY_DOMAIN');

    const roomRes = await fetch('https://api.daily.co/v1/rooms', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        name: roomId.slice(0, 64),
        privacy: 'private',
        properties: { exp: Math.floor(Date.now() / 1000) + 86400 },
      }),
    });

    if (!roomRes.ok) {
      const err = await roomRes.text();
      this.logger.warn(`Daily room create failed: ${err}`);
      return this.createLocalLinks(roomId);
    }

    const room = (await roomRes.json()) as { url?: string; name?: string };
    const roomUrl =
      room.url ?? `https://${domain}.daily.co/${room.name ?? roomId}`;

    const providerToken = await this.dailyMeetingToken(
      apiKey,
      room.name ?? roomId,
      {
        user_name: labels?.providerName ?? 'Provider',
        is_owner: true,
      },
    );
    const patientToken = await this.dailyMeetingToken(
      apiKey,
      room.name ?? roomId,
      {
        user_name: labels?.patientName ?? 'Patient',
        is_owner: false,
      },
    );

    return {
      vendor: 'daily',
      roomId: room.name ?? roomId,
      providerUrl: providerToken ? `${roomUrl}?t=${providerToken}` : roomUrl,
      patientUrl: patientToken ? `${roomUrl}?t=${patientToken}` : roomUrl,
    };
  }

  private async dailyMeetingToken(
    apiKey: string,
    roomName: string,
    props: Record<string, unknown>,
  ): Promise<string | null> {
    const res = await fetch('https://api.daily.co/v1/meeting-tokens', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        properties: { room_name: roomName, ...props },
      }),
    });
    if (!res.ok) {
      return null;
    }
    const data = (await res.json()) as { token?: string };
    return data.token ?? null;
  }

  private async createTwilioLinks(
    roomId: string,
  ): Promise<TelehealthRoomLinks> {
    const accountSid = this.config.get<string>('TWILIO_ACCOUNT_SID')!;
    const apiKeySecret = this.config.get<string>('TWILIO_API_KEY_SECRET')!;
    const auth = Buffer.from(`${accountSid}:${apiKeySecret}`).toString(
      'base64',
    );

    const res = await fetch('https://video.twilio.com/v1/Rooms', {
      method: 'POST',
      headers: {
        Authorization: `Basic ${auth}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        UniqueName: roomId.slice(0, 64),
        Type: 'go',
        RecordParticipantsOnConnect: 'false',
      }),
    });

    if (!res.ok) {
      const err = await res.text();
      this.logger.warn(`Twilio room create failed: ${err}`);
      return this.createLocalLinks(roomId);
    }

    const room = (await res.json()) as { sid?: string };
    const base =
      this.config.get<string>('TELEHEALTH_BASE_URL') ??
      'https://meet.abaconnect.local';
    const joinBase = `${base}/twilio/${room.sid ?? roomId}`;

    return {
      vendor: 'twilio',
      roomId: room.sid ?? roomId,
      providerUrl: `${joinBase}?role=provider`,
      patientUrl: `${joinBase}?role=patient`,
    };
  }
}
