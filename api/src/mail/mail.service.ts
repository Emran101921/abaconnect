import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as nodemailer from 'nodemailer';

@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);
  private transporter: nodemailer.Transporter | null = null;

  constructor(private readonly config: ConfigService) {
    const host = this.config.get<string>('SMTP_HOST');
    const port = this.config.get<number>('SMTP_PORT') ?? 587;
    const user = this.config.get<string>('SMTP_USER');
    const pass = this.config.get<string>('SMTP_PASS');

    if (host && user && pass) {
      this.transporter = nodemailer.createTransport({
        host,
        port,
        secure: port === 465,
        auth: { user, pass },
      });
    }
  }

  isConfigured(): boolean {
    return this.transporter !== null;
  }

  async sendMail(options: {
    to: string;
    subject: string;
    text: string;
    html?: string;
  }): Promise<{ sent: boolean; mode: 'smtp' | 'log' }> {
    if (this.transporter) {
      await this.transporter.sendMail({
        from:
          this.config.get<string>('SMTP_FROM') ??
          'BloomOra <noreply@abaconnect.local>',
        to: options.to,
        subject: options.subject,
        text: options.text,
        html: options.html ?? options.text.replace(/\n/g, '<br>'),
      });
      return { sent: true, mode: 'smtp' };
    }

    this.logger.log(
      `[mail:dev] queued subject="${options.subject}" (${options.text.length} chars)`,
    );
    return { sent: false, mode: 'log' };
  }

  async sendPasswordResetEmail(
    email: string,
    resetUrl: string,
  ): Promise<{ sent: boolean; mode: 'smtp' | 'log' }> {
    return this.sendMail({
      to: email,
      subject: 'Reset your BloomOra password',
      text: [
        'You requested a password reset for BloomOra.',
        '',
        `Reset your password (link expires in 1 hour):`,
        resetUrl,
        '',
        'If you did not request this, ignore this email.',
      ].join('\n'),
    });
  }
}
