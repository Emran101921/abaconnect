import { Module } from '@nestjs/common';
import { AuditModule } from '../audit/audit.module';
import { DocumentsController } from './documents.controller';
import { DocumentsService } from './documents.service';
import { S3DocumentStorage } from './s3-document.storage';
import { UserDocumentsController } from './user-documents.controller';

@Module({
  imports: [AuditModule],
  controllers: [DocumentsController, UserDocumentsController],
  providers: [DocumentsService, S3DocumentStorage],
  exports: [DocumentsService],
})
export class DocumentsModule {}
