import { Module } from '@nestjs/common';
import { AuditModule } from '../audit/audit.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { EarlyInterventionScoringService } from './early-intervention-scoring.service';
import { ScreeningsController } from './screenings.controller';
import { ScreeningsService } from './screenings.service';

@Module({
  imports: [AuditModule, NotificationsModule],
  controllers: [ScreeningsController],
  providers: [ScreeningsService, EarlyInterventionScoringService],
  exports: [ScreeningsService, EarlyInterventionScoringService],
})
export class ScreeningsModule {}
