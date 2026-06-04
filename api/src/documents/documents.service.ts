import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { createReadStream, existsSync, mkdirSync, writeFileSync } from 'fs';
import { join } from 'path';
import { Readable } from 'stream';
import { DocumentType } from '../../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class DocumentsService {
  private readonly uploadRoot =
    process.env.UPLOAD_DIR ?? join(process.cwd(), 'uploads');

  constructor(private readonly prisma: PrismaService) {
    if (!existsSync(this.uploadRoot)) {
      mkdirSync(this.uploadRoot, { recursive: true });
    }
  }

  async listForUser(userId: string) {
    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (parent) {
      return this.prisma.document.findMany({
        where: {
          OR: [{ child: { parentId: parent.id } }, { tenantId: parent.tenantId, childId: null }],
        },
        orderBy: { uploadedAt: 'desc' },
        take: 50,
      });
    }
    const therapist = await this.prisma.therapist.findUnique({ where: { userId } });
    if (therapist) {
      return this.prisma.document.findMany({
        where: { therapistId: therapist.id },
        orderBy: { uploadedAt: 'desc' },
        take: 50,
      });
    }
    return [];
  }

  async registerUpload(
    userId: string,
    data: {
      title: string;
      fileName: string;
      mimeType: string;
      fileSize: number;
      type: DocumentType;
      childId?: string;
    },
  ) {
    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    const therapist = await this.prisma.therapist.findUnique({ where: { userId } });
    const tenantId = parent?.tenantId ?? therapist?.tenantId;
    if (!tenantId) {
      throw new BadRequestException('Profile not found');
    }

    if (data.childId && parent) {
      const child = await this.prisma.child.findFirst({
        where: { id: data.childId, parentId: parent.id },
      });
      if (!child) throw new NotFoundException('Child not found');
    }

    const storageKey = `tenants/${tenantId}/docs/${Date.now()}_${data.fileName}`;
    const doc = await this.prisma.document.create({
      data: {
        tenantId,
        childId: data.childId,
        therapistId: therapist?.id,
        type: data.type,
        title: data.title,
        fileName: data.fileName,
        mimeType: data.mimeType,
        fileSize: data.fileSize,
        storageKey,
      },
    });

    await this.prisma.documentAccessLog.create({
      data: {
        documentId: doc.id,
        userId,
        action: 'CREATE',
      },
    });

    return doc;
  }

  async saveUploadedFile(
    userId: string,
    file: Express.Multer.File,
    data: {
      title: string;
      type: DocumentType;
      childId?: string;
    },
  ) {
    const doc = await this.registerUpload(userId, {
      title: data.title,
      fileName: file.originalname,
      mimeType: file.mimetype || 'application/octet-stream',
      fileSize: file.size,
      type: data.type,
      childId: data.childId,
    });

    const absolutePath = this.resolveAbsolutePath(doc.storageKey);
    const dir = join(absolutePath, '..');
    if (!existsSync(dir)) {
      mkdirSync(dir, { recursive: true });
    }
    writeFileSync(absolutePath, file.buffer);

    return doc;
  }

  async openFileStream(userId: string, documentId: string) {
    const doc = await this.logAccess(userId, documentId);
    const absolutePath = this.resolveAbsolutePath(doc.storageKey);
    if (!existsSync(absolutePath)) {
      throw new NotFoundException('File content not found on server');
    }
    return { doc, stream: createReadStream(absolutePath) as Readable };
  }

  private resolveAbsolutePath(storageKey: string): string {
    return join(this.uploadRoot, storageKey.replace(/^tenants\//, ''));
  }

  async logAccess(userId: string, documentId: string) {
    const doc = await this.findAccessible(userId, documentId);
    await this.prisma.documentAccessLog.create({
      data: { documentId: doc.id, userId, action: 'READ' },
    });
    return doc;
  }

  private async findAccessible(userId: string, documentId: string) {
    const doc = await this.prisma.document.findUnique({
      where: { id: documentId },
      include: { child: { include: { parent: true } } },
    });
    if (!doc) throw new NotFoundException('Document not found');

    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (parent && (doc.child?.parentId === parent.id || doc.tenantId === parent.tenantId)) {
      return doc;
    }
    const therapist = await this.prisma.therapist.findUnique({ where: { userId } });
    if (therapist && doc.therapistId === therapist.id) {
      return doc;
    }
    throw new BadRequestException('Not authorized');
  }

  async create(data: Record<string, unknown>) {
    void data;
    throw new BadRequestException('Use GraphQL registerDocument');
  }

  async findAll() {
    return this.prisma.document.findMany({ take: 20 });
  }

  async findOne(id: string) {
    const doc = await this.prisma.document.findUnique({ where: { id } });
    if (!doc) throw new NotFoundException('Document not found');
    return doc;
  }

  async update(id: string, data: Record<string, unknown>) {
    await this.findOne(id);
    return this.prisma.document.update({
      where: { id },
      data: data as Parameters<typeof this.prisma.document.update>[0]['data'],
    });
  }

  async remove(id: string) {
    await this.findOne(id);
    await this.prisma.document.delete({ where: { id } });
    return { id, deleted: true };
  }
}
