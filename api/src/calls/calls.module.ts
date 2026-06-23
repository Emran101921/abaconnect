import { Module } from '@nestjs/common';
import { NotificationsModule } from '../notifications/notifications.module';
import { CallProviderFactory } from './call-provider.factory';
import { CallsAuditService } from './calls-audit.service';
import { CallsPermissionsService } from './calls-permissions.service';
import { CallsService } from './calls.service';
import { DailyCallProvider } from './providers/daily-call.provider';
import { StubCallProvider } from './providers/stub-call.provider';

@Module({
  imports: [NotificationsModule],
  providers: [
    CallsService,
    CallsPermissionsService,
    CallsAuditService,
    CallProviderFactory,
    DailyCallProvider,
    StubCallProvider,
  ],
  exports: [CallsService, CallsPermissionsService, CallsAuditService],
})
export class CallsModule {}
