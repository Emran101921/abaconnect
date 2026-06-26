import { Module } from '@nestjs/common';
import { AgenciesModule } from '../agencies/agencies.module';
import { AuditModule } from '../audit/audit.module';
import { AgencyPlatformService } from './agency-platform.service';

@Module({
  imports: [AgenciesModule, AuditModule],
  providers: [AgencyPlatformService],
  exports: [AgencyPlatformService],
})
export class AgencyPlatformModule {}
