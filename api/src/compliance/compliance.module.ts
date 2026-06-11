import { Module } from '@nestjs/common';
import { AuditModule } from '../audit/audit.module';
import { SecurityModule } from '../security/security.module';
import { AdminComplianceController } from './admin-compliance.controller';
import { AdminSecurityController } from './admin-security.controller';
import { ComplianceController } from './compliance.controller';
import { ComplianceDocumentsController } from './compliance-documents.controller';
import { ComplianceService } from './compliance.service';
import { ComplianceDocumentsService } from './compliance-documents.service';
import { AdminSecurityService } from './admin-security.service';
import { ProviderOnboardingService } from './provider-onboarding.service';
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
    AdminSecurityController,
    ComplianceDocumentsController,
  ],
  providers: [
    ComplianceService,
    PrivacyNoticeService,
    PrivacyRightsService,
    ComplianceDocumentsService,
    AdminSecurityService,
    ProviderOnboardingService,
  ],
  exports: [
    ComplianceService,
    PrivacyNoticeService,
    PrivacyRightsService,
    ComplianceDocumentsService,
    ProviderOnboardingService,
  ],
})
export class ComplianceModule {}
