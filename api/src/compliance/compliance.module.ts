import { Module } from '@nestjs/common';
import { SecurityModule } from '../security/security.module';
import { ComplianceController } from './compliance.controller';
import { ComplianceService } from './compliance.service';
import { UserComplianceController } from './user-compliance.controller';

@Module({
  imports: [SecurityModule],
  controllers: [ComplianceController, UserComplianceController],
  providers: [ComplianceService],
  exports: [ComplianceService],
})
export class ComplianceModule {}
