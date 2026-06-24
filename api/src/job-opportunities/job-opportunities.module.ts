import { Module } from '@nestjs/common';
import { JobOpportunitiesController } from './job-opportunities.controller';
import { JobOpportunitiesService } from './job-opportunities.service';

@Module({
  controllers: [JobOpportunitiesController],
  providers: [JobOpportunitiesService],
  exports: [JobOpportunitiesService],
})
export class JobOpportunitiesModule {}
