import { Process, Processor } from '@nestjs/bull';
import { Logger } from '@nestjs/common';
import type { Job } from 'bull';
import { PushPayload, PushService } from './push.service';

@Processor('push')
export class PushProcessor {
  private readonly logger = new Logger(PushProcessor.name);

  constructor(private readonly pushService: PushService) {}

  @Process('send')
  async handleSend(job: Job<PushPayload>) {
    const result = await this.pushService.sendToUser(job.data);
    this.logger.debug(
      `Push job ${job.id} user=${job.data.userId} sent=${result.sent} failed=${result.failed}`,
    );
    return result;
  }
}
