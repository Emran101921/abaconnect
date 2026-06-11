import { Module } from '@nestjs/common';
import { AuditModule } from '../audit/audit.module';
import { ClearinghouseService } from './clearinghouse.service';
import { ClaimSecurityService } from './claim-security.service';
import { Edi837Service } from './edi837.service';
import { InsuranceController } from './insurance.controller';
import { InsuranceService } from './insurance.service';

@Module({
  imports: [AuditModule],
  controllers: [InsuranceController],
  providers: [
    InsuranceService,
    ClaimSecurityService,
    Edi837Service,
    ClearinghouseService,
  ],
  exports: [InsuranceService, ClaimSecurityService],
})
export class InsuranceModule {}
