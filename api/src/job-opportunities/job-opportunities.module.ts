import { Module } from '@nestjs/common';
import { CallsModule } from '../calls/calls.module';
import { DocumentsModule } from '../documents/documents.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { JobOpportunitiesController } from './job-opportunities.controller';
import { JobOpportunitiesService } from './job-opportunities.service';

@Module({
  imports: [NotificationsModule, CallsModule, DocumentsModule],
  controllers: [JobOpportunitiesController],
  providers: [JobOpportunitiesService],
  exports: [JobOpportunitiesService],
})
export class JobOpportunitiesModule {}
