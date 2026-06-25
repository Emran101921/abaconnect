import { Module } from '@nestjs/common';
import { NotificationsModule } from '../notifications/notifications.module';
import { JobOpportunitiesController } from './job-opportunities.controller';
import { JobOpportunitiesService } from './job-opportunities.service';

@Module({
  imports: [NotificationsModule],
  controllers: [JobOpportunitiesController],
  providers: [JobOpportunitiesService],
  exports: [JobOpportunitiesService],
})
export class JobOpportunitiesModule {}
