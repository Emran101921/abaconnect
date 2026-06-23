import { Module } from '@nestjs/common';
import { AuditModule } from '../audit/audit.module';
import { PrismaModule } from '../prisma/prisma.module';
import { AuthorizedApiAdapter } from './adapters/ei-billing-adapters';
import {
  CsvExportAdapter,
  Edi837pExportAdapter,
  StubEiHubAdapter,
  StubEmednyAdapter,
  StubStateFiscalAgentAdapter,
} from './adapters/ei-billing-adapters';
import { EiBillingAdapterRegistry } from './adapters/ei-billing-adapter.registry';
import { EiBillingAuditService } from './ei-billing-audit.service';
import { EiBillingCaseService } from './ei-billing-case.service';
import { EiBillingClearinghouseService } from './ei-billing-clearinghouse.service';
import { EiBillingController } from './ei-billing.controller';
import { EiBillingDenialService } from './ei-billing-denial.service';
import { EiBillingEnrollmentService } from './ei-billing-enrollment.service';
import { EiBillingPaymentService } from './ei-billing-payment.service';
import { EiBillingQueueService } from './ei-billing-queue.service';
import { EiBillingRecordService } from './ei-billing-record.service';
import { EiBillingValidationService } from './ei-billing-validation.service';

@Module({
  imports: [PrismaModule, AuditModule],
  controllers: [EiBillingController],
  providers: [
    EiBillingValidationService,
    EiBillingQueueService,
    EiBillingEnrollmentService,
    EiBillingCaseService,
    EiBillingRecordService,
    EiBillingDenialService,
    EiBillingPaymentService,
    EiBillingAuditService,
    EiBillingClearinghouseService,
    StubEiHubAdapter,
    StubStateFiscalAgentAdapter,
    StubEmednyAdapter,
    Edi837pExportAdapter,
    CsvExportAdapter,
    AuthorizedApiAdapter,
    EiBillingAdapterRegistry,
  ],
  exports: [
    EiBillingValidationService,
    EiBillingEnrollmentService,
    EiBillingCaseService,
    EiBillingRecordService,
    EiBillingDenialService,
    EiBillingPaymentService,
    EiBillingAuditService,
    EiBillingClearinghouseService,
  ],
})
export class EiBillingModule {}
