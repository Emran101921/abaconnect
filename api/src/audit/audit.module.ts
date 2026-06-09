import { Module } from '@nestjs/common';
import { AuditController } from './audit.controller';
import { AuditService } from './audit.service';
import { PhiAuditService } from './phi-audit.service';

@Module({
  controllers: [AuditController],
  providers: [AuditService, PhiAuditService],
  exports: [AuditService, PhiAuditService],
})
export class AuditModule {}
