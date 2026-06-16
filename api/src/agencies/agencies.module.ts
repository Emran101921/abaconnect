import { Module } from '@nestjs/common';
import { AgenciesController } from './agencies.controller';
import { AgencyDocumentsController } from './agency-documents.controller';
import { AgenciesService } from './agencies.service';

@Module({
  controllers: [AgenciesController, AgencyDocumentsController],
  providers: [AgenciesService],
  exports: [AgenciesService],
})
export class AgenciesModule {}
