import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  Post,
  Res,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { Response } from 'express';
import { DocumentType } from '../../generated/prisma/client';
import { AuthUser, CurrentUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { DocumentsService } from './documents.service';

@Controller('documents')
@Roles('PARENT', 'THERAPIST')
export class UserDocumentsController {
  constructor(private readonly documentsService: DocumentsService) {}

  @Post('upload')
  @UseInterceptors(
    FileInterceptor('file', {
      limits: { fileSize: 10 * 1024 * 1024 },
    }),
  )
  async upload(
    @CurrentUser() user: AuthUser,
    @UploadedFile() file: Express.Multer.File,
    @Body('title') title?: string,
    @Body('type') type?: string,
    @Body('childId') childId?: string,
  ) {
    if (!file) {
      throw new BadRequestException('File is required');
    }
    const allowed = Object.values(DocumentType) as string[];
    const docType =
      type && allowed.includes(type) ? (type as DocumentType) : DocumentType.OTHER;
    return this.documentsService.saveUploadedFile(user.id, file, {
      title: title?.trim() || file.originalname,
      type: docType,
      childId: childId || undefined,
    });
  }

  @Get(':id/file')
  async downloadFile(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Res() res: Response,
  ): Promise<void> {
    const { doc, stream } = await this.documentsService.openFileStream(user.id, id);
    res.setHeader('Content-Type', doc.mimeType);
    res.setHeader(
      'Content-Disposition',
      `attachment; filename="${encodeURIComponent(doc.fileName)}"`,
    );
    stream.pipe(res);
  }
}
