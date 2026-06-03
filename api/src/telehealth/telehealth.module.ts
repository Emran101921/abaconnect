import { Module } from '@nestjs/common';
import { TelehealthController } from './telehealth.controller';
import { TelehealthService } from './telehealth.service';
import { TelehealthVendorService } from './telehealth-vendor.service';

@Module({
  controllers: [TelehealthController],
  providers: [TelehealthService, TelehealthVendorService],
  exports: [TelehealthService],
})
export class TelehealthModule {}
