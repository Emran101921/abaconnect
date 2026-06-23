/**
 * Provider abstraction for HIPAA-eligible call vendors (Daily, Twilio, Agora, etc.).
 * UI and business logic must never import vendor SDKs directly.
 */
export interface CallRoomToken {
  providerName: string;
  roomId: string;
  joinUrl?: string;
  token: string;
  expiresAt: Date;
}

export interface CreateCallRoomInput {
  roomId: string;
  callType: 'AUDIO' | 'VIDEO';
  userDisplayName: string;
  isOwner?: boolean;
}

export interface CallProvider {
  readonly name: string;

  /** Creates or reuses a provider room and returns a short-lived join token. */
  createParticipantToken(input: CreateCallRoomInput): Promise<CallRoomToken>;

  /** Optional cleanup when a session ends. */
  endRoom?(roomId: string): Promise<void>;
}

export const CALL_TOKEN_TTL_SECONDS = 300;
