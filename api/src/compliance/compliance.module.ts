import { Module } from '@nestjs/common';
import { AuditModule } from '../audit/audit.module';
import { SecurityModule } from '../security/security.module';
import { AdminComplianceController } from './admin-compliance.controller';
import { ComplianceController } from './compliance.controller';
import { ComplianceService } from './compliance.service';
import { PrivacyNoticeService } from './privacy-notice.service';
import { PrivacyRightsService } from './privacy-rights.service';
import { UserComplianceController } from './user-compliance.controller';
import { UserPrivacyController } from './user-privacy.controller';

@Module({
  imports: [SecurityModule, AuditModule],
  controllers: [
    ComplianceController,
    UserComplianceController,
    UserPrivacyController,
    AdminComplianceController,
  ],
  providers: [ComplianceService, PrivacyNoticeService, PrivacyRightsService],
  exports: [ComplianceService, PrivacyNoticeService, PrivacyRightsService],
})
export class ComplianceModule {}
