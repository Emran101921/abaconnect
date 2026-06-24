import {
  BadRequestException,
  Controller,
  Post,
  UploadedFile,
  UseInterceptors,
  Body,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { AgencyDocumentType } from '../../generated/prisma/client';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { AgenciesService } from './agencies.service';

@Controller('agencies/documents')
@Roles('AGENCY_ADMIN')
export class AgencyDocumentsController {
  constructor(private readonly agenciesService: AgenciesService) {}

  @Post('upload')
  @UseInterceptors(
    FileInterceptor('file', {
      limits: { fileSize: 10 * 1024 * 1024 },
    }),
  )
  async upload(
    @CurrentUser() user: AuthUser,
    @UploadedFile() file: Express.Multer.File,
    @Body('type') type?: string,
    @Body('title') title?: string,
  ) {
    if (!user.tenantId) {
      throw new BadRequestException('Tenant required');
    }
    const allowed = Object.values(AgencyDocumentType) as string[];
    const docType =
      type && allowed.includes(type)
        ? (type as AgencyDocumentType)
        : AgencyDocumentType.OTHER;

    const agency = await this.agenciesService.resolveAgencyForAdmin(
      user.id,
      user.tenantId,
    );

    return this.agenciesService.uploadAgencyDocument(
      agency.id,
      user.tenantId,
      user.id,
      file,
      docType,
      title,
    );
  }
}
