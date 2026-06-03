import { Module } from '@nestjs/common';
import { TelehealthController } from './telehealth.controller';
import { TelehealthService } from './telehealth.service';

@Module({
  controllers: [TelehealthController],
  providers: [TelehealthService],
  exports: [TelehealthService],
})
export class TelehealthModule {}
