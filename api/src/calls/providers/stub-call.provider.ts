import { Injectable } from '@nestjs/common';
import { createHash, randomBytes } from 'crypto';
import {
  CALL_TOKEN_TTL_SECONDS,
  CallProvider,
  CallRoomToken,
  CreateCallRoomInput,
} from '../call-provider.interface';

/** Local/dev provider — in-app native UI; no external browser URL. */
@Injectable()
export class StubCallProvider implements CallProvider {
  readonly name = 'stub';

  async createParticipantToken(
    input: CreateCallRoomInput,
  ): Promise<CallRoomToken> {
    const token = randomBytes(24).toString('hex');
    const expiresAt = new Date(Date.now() + CALL_TOKEN_TTL_SECONDS * 1000);

    return {
      providerName: this.name,
      roomId: input.roomId,
      joinUrl: undefined,
      token,
      expiresAt,
    };
  }
}

export function stubTokenHash(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}
