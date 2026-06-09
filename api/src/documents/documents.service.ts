import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  decryptBuffer,
  encryptBuffer,
} from '../common/crypto/field-crypto.util';
import {
  createReadStream,
  existsSync,
  mkdirSync,
  readFileSync,
  unlinkSync,
  writeFileSync,
} from 'fs';
import { join } from 'path';
import { Readable } from 'stream';
import { DocumentType } from '../../generated/prisma/client';
import { PhiAuditService } from '../audit/phi-audit.service';
import { PrismaService } from '../prisma/prisma.service';
import { S3DocumentStorage } from './s3-document.storage';

@Injectable()
export class DocumentsService {
  private readonly uploadRoot =
    process.env.UPLOAD_DIR ?? join(process.cwd(), 'uploads');

  private encryptionKey(): string | null {
    const key = process.env.PHI_ENCRYPTION_KEY?.trim();
    return key || null;
  }

  constructor(
    private readonly prisma: PrismaService,
    private readonly s3: S3DocumentStorage,
    private readonly phiAudit: PhiAuditService,
  ) {
    if (!this.s3.isEnabled() && !existsSync(this.uploadRoot)) {
      mkdirSync(this.uploadRoot, { recursive: true });
    }
  }

  private useS3(): boolean {
    return this.s3.isEnabled();
  }

  private preparePayload(buffer: Buffer): Buffer {
    if (!this.encryptionKey()) {
      return buffer;
    }
    return encryptBuffer(buffer, this.encryptionKey()!);
  }

  private revealPayload(buffer: Buffer): Buffer {
    if (!this.encryptionKey()) {
      return buffer;
    }
    return decryptBuffer(buffer, this.encryptionKey()!);
  }

  async listForUser(userId: string) {
    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (parent) {
      return this.prisma.document.findMany({
        where: { child: { parentId: parent.id } },
        orderBy: { uploadedAt: 'desc' },
        take: 50,
      });
    }
    const therapist = await this.prisma.therapist.findUnique({
      where: { userId },
    });
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
    const therapist = await this.prisma.therapist.findUnique({
      where: { userId },
    });
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

    const payload = this.preparePayload(file.buffer);
    if (this.useS3()) {
      await this.s3.putObject(doc.storageKey, payload);
    } else {
      const absolutePath = this.resolveAbsolutePath(doc.storageKey);
      const dir = join(absolutePath, '..');
      if (!existsSync(dir)) {
        mkdirSync(dir, { recursive: true });
      }
      writeFileSync(absolutePath, payload);
    }

    return doc;
  }

  async openFileStream(userId: string, documentId: string) {
    const doc = await this.logAccess(userId, documentId);
    const buffer = this.useS3()
      ? await this.s3.getObjectBuffer(doc.storageKey)
      : readFileSync(this.resolveAbsolutePath(doc.storageKey));
    const stream = Readable.from(this.revealPayload(buffer));
    return { doc, stream };
  }

  private resolveAbsolutePath(storageKey: string): string {
    return join(this.uploadRoot, storageKey.replace(/^tenants\//, ''));
  }

  async logAccess(userId: string, documentId: string) {
    const doc = await this.findAccessible(userId, documentId);
    await this.prisma.documentAccessLog.create({
      data: { documentId: doc.id, userId, action: 'READ' },
    });
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (user) {
      await this.phiAudit.logPhiAccess({
        tenantId: user.tenantId,
        actorId: userId,
        action: 'READ',
        resourceType: 'document',
        resourceId: doc.id,
      });
    }
    return doc;
  }

  async deleteForUser(userId: string, documentId: string) {
    const doc = await this.findAccessible(userId, documentId);
    if (this.useS3()) {
      await this.s3.deleteObject(doc.storageKey);
    } else {
      const absolutePath = this.resolveAbsolutePath(doc.storageKey);
      if (existsSync(absolutePath)) {
        unlinkSync(absolutePath);
      }
    }
    await this.prisma.documentAccessLog.create({
      data: { documentId: doc.id, userId, action: 'DELETE' },
    });
    await this.prisma.document.delete({ where: { id: documentId } });
    return { id: documentId, deleted: true };
  }

  private async findAccessible(userId: string, documentId: string) {
    const doc = await this.prisma.document.findUnique({
      where: { id: documentId },
      include: { child: { include: { parent: true } } },
    });
    if (!doc) throw new NotFoundException('Document not found');

    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (parent && doc.child?.parentId === parent.id) {
      return doc;
    }
    const therapist = await this.prisma.therapist.findUnique({
      where: { userId },
    });
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
