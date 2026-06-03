import { Module } from '@nestjs/common';
import { ClinicalService } from './clinical.service';

@Module({
  providers: [ClinicalService],
  exports: [ClinicalService],
})
export class ClinicalModule {}
