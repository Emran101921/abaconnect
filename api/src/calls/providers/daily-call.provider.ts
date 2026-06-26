import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  CALL_TOKEN_TTL_SECONDS,
  CallProvider,
  CallRoomToken,
  CreateCallRoomInput,
} from '../call-provider.interface';
import { StubCallProvider } from './stub-call.provider';

@Injectable()
export class DailyCallProvider implements CallProvider {
  readonly name = 'daily';
  private readonly logger = new Logger(DailyCallProvider.name);

  constructor(
    private readonly config: ConfigService,
    private readonly stub: StubCallProvider,
  ) {}

  async createParticipantToken(
    input: CreateCallRoomInput,
  ): Promise<CallRoomToken> {
    const apiKey = this.config.get<string>('DAILY_API_KEY');
    if (!apiKey) {
      return this.stub.createParticipantToken(input);
    }

    const roomName = input.roomId.slice(0, 64);
    await this.ensureRoom(apiKey, roomName, input.enableRecording === true);

    const exp = Math.floor(Date.now() / 1000) + CALL_TOKEN_TTL_SECONDS;
    const tokenRes = await fetch('https://api.daily.co/v1/meeting-tokens', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        properties: {
          room_name: roomName,
          user_name: input.userDisplayName,
          is_owner: input.isOwner ?? false,
          exp,
          enable_screenshare: input.callType === 'VIDEO',
          start_video_off: input.callType === 'AUDIO',
          start_audio_off: false,
        },
      }),
    });

    if (!tokenRes.ok) {
      const err = await tokenRes.text();
      this.logger.warn(`Daily token failed: ${err}`);
      return this.stub.createParticipantToken(input);
    }

    const data = (await tokenRes.json()) as { token?: string };
    const token = data.token;
    if (!token) {
      return this.stub.createParticipantToken(input);
    }

    const domain = this.config.get<string>('DAILY_DOMAIN');
    const joinUrl = domain
      ? `https://${domain}.daily.co/${roomName}?t=${token}`
      : `https://daily.co/${roomName}?t=${token}`;

    return {
      providerName: this.name,
      roomId: roomName,
      joinUrl,
      token,
      expiresAt: new Date(exp * 1000),
    };
  }

  async endRoom(roomId: string): Promise<void> {
    const apiKey = this.config.get<string>('DAILY_API_KEY');
    if (!apiKey) return;
    await fetch(`https://api.daily.co/v1/rooms/${roomId.slice(0, 64)}`, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${apiKey}` },
    }).catch(() => undefined);
  }

  private async ensureRoom(
    apiKey: string,
    roomName: string,
    enableRecording = false,
  ) {
    const res = await fetch('https://api.daily.co/v1/rooms', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        name: roomName,
        privacy: 'private',
        properties: {
          exp: Math.floor(Date.now() / 1000) + 86400,
          enable_recording: enableRecording ? 'cloud' : false,
        },
      }),
    });
    if (!res.ok && res.status !== 409) {
      const err = await res.text();
      this.logger.warn(`Daily room create failed: ${err}`);
    }
  }
}
