import { Module } from '@nestjs/common';
import { ClearinghouseService } from './clearinghouse.service';
import { Edi837Service } from './edi837.service';
import { InsuranceController } from './insurance.controller';
import { InsuranceService } from './insurance.service';

@Module({
  controllers: [InsuranceController],
  providers: [InsuranceService, Edi837Service, ClearinghouseService],
  exports: [InsuranceService],
})
export class InsuranceModule {}
