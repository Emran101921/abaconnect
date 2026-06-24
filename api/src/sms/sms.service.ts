import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class SmsService {
  private readonly logger = new Logger(SmsService.name);

  constructor(private readonly config: ConfigService) {}

  isConfigured(): boolean {
    return Boolean(
      this.config.get<string>('TWILIO_ACCOUNT_SID') &&
        this.config.get<string>('TWILIO_AUTH_TOKEN') &&
        this.config.get<string>('TWILIO_PHONE_NUMBER'),
    );
  }

  async sendSms(options: {
    to: string;
    body: string;
  }): Promise<{ sent: boolean; mode: 'twilio' | 'log' }> {
    const sid = this.config.get<string>('TWILIO_ACCOUNT_SID');
    const token = this.config.get<string>('TWILIO_AUTH_TOKEN');
    const from = this.config.get<string>('TWILIO_PHONE_NUMBER');

    if (!sid || !token || !from) {
      this.logger.log(
        `[sms:dev] to=${options.to} body="${options.body.slice(0, 80)}${options.body.length > 80 ? '…' : ''}"`,
      );
      return { sent: false, mode: 'log' };
    }

    const to = options.to.replace(/[^\d+]/g, '');
    const url = `https://api.twilio.com/2010-04-01/Accounts/${sid}/Messages.json`;
    const auth = Buffer.from(`${sid}:${token}`).toString('base64');

    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          Authorization: `Basic ${auth}`,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: new URLSearchParams({
          To: to,
          From: from,
          Body: options.body,
        }),
      });
      if (!response.ok) {
        this.logger.warn(`Twilio HTTP ${response.status} for ${to}`);
        return { sent: false, mode: 'twilio' };
      }
      return { sent: true, mode: 'twilio' };
    } catch (err) {
      this.logger.warn(`Twilio send failed: ${err}`);
      return { sent: false, mode: 'twilio' };
    }
  }
}
