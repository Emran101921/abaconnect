import { Module } from '@nestjs/common';
import { AuditModule } from '../audit/audit.module';
import { EiBillingModule } from '../ei-billing/ei-billing.module';
import { InsuranceModule } from '../insurance/insurance.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { ServiceLogsController } from './service-logs.controller';
import { ServiceLogService } from './service-log.service';
import { SessionsController } from './sessions.controller';
import { SessionsService } from './sessions.service';

@Module({
  imports: [AuditModule, NotificationsModule, InsuranceModule, EiBillingModule],
  controllers: [SessionsController, ServiceLogsController],
  providers: [SessionsService, ServiceLogService],
  exports: [SessionsService, ServiceLogService],
})
export class SessionsModule {}
