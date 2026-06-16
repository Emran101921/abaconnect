import { Module } from '@nestjs/common';
import { ServiceCoordinatorsService } from './service-coordinators.service';

@Module({
  providers: [ServiceCoordinatorsService],
  exports: [ServiceCoordinatorsService],
})
export class ServiceCoordinatorsModule {}
