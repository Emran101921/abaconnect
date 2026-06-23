import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { CallProvider } from './call-provider.interface';
import { DailyCallProvider } from './providers/daily-call.provider';
import { StubCallProvider } from './providers/stub-call.provider';

/**
 * Selects the active call vendor from environment configuration.
 * Secrets remain server-side only; clients receive short-lived tokens.
 */
@Injectable()
export class CallProviderFactory {
  constructor(
    private readonly config: ConfigService,
    private readonly daily: DailyCallProvider,
    private readonly stub: StubCallProvider,
  ) {}

  getProvider(): CallProvider {
    const mode = (this.config.get<string>('CALL_VENDOR') ??
      this.config.get<string>('TELEHEALTH_VENDOR') ??
      'stub')
      .toLowerCase()
      .trim();

    if (mode === 'daily' && this.config.get<string>('DAILY_API_KEY')) {
      return this.daily;
    }
    return this.stub;
  }
}
