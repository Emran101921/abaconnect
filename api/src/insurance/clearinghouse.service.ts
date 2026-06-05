import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

export interface ClearinghouseSubmitResult {
  externalId: string;
  status: 'ACCEPTED' | 'REJECTED';
  message: string;
}

@Injectable()
export class ClearinghouseService {
  private readonly logger = new Logger(ClearinghouseService.name);

  constructor(private readonly config: ConfigService) {}

  async submit837(
    claimId: string,
    ediPayload: Record<string, unknown>,
  ): Promise<ClearinghouseSubmitResult> {
    const vendor = this.config.get<string>('CLEARINGHOUSE_VENDOR') ?? 'stub';
    const endpoint = this.config.get<string>('CLEARINGHOUSE_ENDPOINT');

    if (vendor === 'stub' || !endpoint) {
      const externalId = `STUB-${claimId.slice(0, 8).toUpperCase()}`;
      this.logger.log(
        `[stub-clearinghouse] claim=${claimId} segments=${(ediPayload.segments as string[])?.length ?? 0}`,
      );
      return {
        externalId,
        status: 'ACCEPTED',
        message: 'Claim accepted by stub clearinghouse',
      };
    }

    try {
      const response = await fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ claimId, payload: ediPayload }),
      });
      if (!response.ok) {
        return {
          externalId: '',
          status: 'REJECTED',
          message: `Clearinghouse HTTP ${response.status}`,
        };
      }
      const data = (await response.json()) as {
        externalId?: string;
        status?: string;
        message?: string;
      };
      return {
        externalId: data.externalId ?? `EXT-${claimId.slice(0, 8)}`,
        status: data.status === 'REJECTED' ? 'REJECTED' : 'ACCEPTED',
        message: data.message ?? 'Submitted',
      };
    } catch (err) {
      return {
        externalId: '',
        status: 'REJECTED',
        message: `Clearinghouse error: ${err}`,
      };
    }
  }
}
