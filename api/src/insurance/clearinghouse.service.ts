import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

export interface ClearinghouseSubmitResult {
  externalId: string;
  status: 'ACCEPTED' | 'REJECTED';
  message: string;
}

export interface Clearinghouse835Result {
  externalId: string;
  status: 'PAID' | 'DENIED' | 'PENDING';
  paidAmount: number;
  message: string;
  traceNumber: string;
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

  /** Stub 835 remittance: simulates payer posting after 837 acceptance. */
  async poll835Remittance(
    claimId: string,
    externalId: string,
    billedAmount: number,
  ): Promise<Clearinghouse835Result> {
    const vendor = this.config.get<string>('CLEARINGHOUSE_VENDOR') ?? 'stub';
    const traceNumber = `835-${claimId.slice(0, 8).toUpperCase()}`;

    if (vendor === 'stub') {
      const paidAmount = Number((billedAmount * 0.85).toFixed(2));
      this.logger.log(
        `[stub-835] claim=${claimId} external=${externalId} paid=${paidAmount}`,
      );
      return {
        externalId,
        status: 'PAID',
        paidAmount,
        message: '835 remittance posted (stub clearinghouse)',
        traceNumber,
      };
    }

    const endpoint = this.config.get<string>('CLEARINGHOUSE_835_ENDPOINT');
    if (!endpoint) {
      return {
        externalId,
        status: 'PENDING',
        paidAmount: 0,
        message: '835 endpoint not configured',
        traceNumber,
      };
    }

    try {
      const response = await fetch(`${endpoint}/835/${externalId}`);
      if (!response.ok) {
        return {
          externalId,
          status: 'PENDING',
          paidAmount: 0,
          message: `835 poll HTTP ${response.status}`,
          traceNumber,
        };
      }
      const data = (await response.json()) as {
        status?: string;
        paidAmount?: number;
        message?: string;
      };
      return {
        externalId,
        status: data.status === 'PAID' ? 'PAID' : 'DENIED',
        paidAmount: Number(data.paidAmount ?? billedAmount),
        message: data.message ?? '835 remittance received',
        traceNumber,
      };
    } catch (err) {
      return {
        externalId,
        status: 'PENDING',
        paidAmount: 0,
        message: `835 poll error: ${err}`,
        traceNumber,
      };
    }
  }
}
