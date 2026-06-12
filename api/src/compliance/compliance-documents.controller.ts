import { Body, Controller, Get, Param, Post } from '@nestjs/common';
import { ComplianceDocumentType } from '../../generated/prisma/client';
import { Public } from '../common/decorators/public.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { ComplianceDocumentsService } from './compliance-documents.service';

@Controller('compliance/documents')
export class ComplianceDocumentsController {
  constructor(private readonly documents: ComplianceDocumentsService) {}

  @Get('me/pending')
  listPending(@CurrentUser() user: AuthUser) {
    return this.documents.listActiveForUser(user.id, user.tenantId ?? '');
  }

  @Get(':type')
  @Public()
  getActive(@Param('type') type: ComplianceDocumentType) {
    return this.documents.getActiveDocument(type);
  }

  @Post(':id/accept')
  accept(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() body: { userAgent?: string },
  ) {
    return this.documents.acceptDocument(
      user.id,
      user.tenantId ?? '',
      id,
      undefined,
      body.userAgent,
    );
  }
}
