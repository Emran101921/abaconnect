import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  AuditAction,
  ComplianceDocumentType,
  Prisma,
} from '../../generated/prisma/client';
import { AuditService } from '../audit/audit.service';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ComplianceDocumentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  async getActiveDocument(
    documentType: ComplianceDocumentType,
    tenantId?: string | null,
  ) {
    return this.prisma.complianceDocument.findFirst({
      where: {
        documentType,
        isActive: true,
        OR: [{ tenantId: tenantId ?? null }, { tenantId: null }],
      },
      orderBy: { effectiveDate: 'desc' },
    });
  }

  async listActiveForUser(userId: string, tenantId: string) {
    const types = Object.values(ComplianceDocumentType);
    const docs = await Promise.all(
      types.map((t) => this.getActiveDocument(t, tenantId)),
    );
    const acceptances = await this.prisma.complianceDocumentAcceptance.findMany({
      where: { userId },
    });
    const acceptedIds = new Set(acceptances.map((a) => a.documentId));

    return docs
      .filter(Boolean)
      .map((doc) => ({
        ...doc!,
        accepted: acceptedIds.has(doc!.id),
      }));
  }

  async acceptDocument(
    userId: string,
    tenantId: string,
    documentId: string,
    ipAddress?: string,
    userAgent?: string,
  ) {
    const doc = await this.prisma.complianceDocument.findFirst({
      where: {
        id: documentId,
        OR: [{ tenantId }, { tenantId: null }],
      },
    });
    if (!doc) throw new NotFoundException('Document not found');
    if (!doc.isActive) {
      throw new BadRequestException('Document version is not active');
    }

    const acceptance = await this.prisma.complianceDocumentAcceptance.upsert({
      where: { userId_documentId: { userId, documentId } },
      create: {
        userId,
        tenantId,
        documentId,
        ipAddress,
        userAgent,
      },
      update: { acceptedAt: new Date(), ipAddress, userAgent },
    });

    await this.audit.log({
      tenantId,
      actorId: userId,
      action: AuditAction.CONSENT_GRANTED,
      resourceType: 'ComplianceDocument',
      resourceId: documentId,
      ipAddress,
      userAgent,
      metadata: {
        documentType: doc.documentType,
        version: doc.version,
      },
    });

    return acceptance;
  }

  async createVersion(
    createdById: string,
    tenantId: string | null,
    data: {
      documentType: ComplianceDocumentType;
      version: string;
      title: string;
      content: string;
      effectiveDate?: Date;
      publish?: boolean;
    },
  ) {
    const doc = await this.prisma.complianceDocument.create({
      data: {
        tenantId,
        documentType: data.documentType,
        version: data.version,
        title: data.title,
        content: data.content,
        effectiveDate: data.effectiveDate ?? new Date(),
        isActive: false,
        createdById,
      },
    });

    if (data.publish) {
      return this.publishVersion(createdById, doc.id, tenantId);
    }
    return doc;
  }

  async publishVersion(
    actorId: string,
    documentId: string,
    tenantId: string | null,
  ) {
    const doc = await this.prisma.complianceDocument.findFirst({
      where: {
        id: documentId,
        OR: tenantId ? [{ tenantId }, { tenantId: null }] : [{ tenantId: null }],
      },
    });
    if (!doc) throw new NotFoundException('Document not found');

    await this.prisma.complianceDocument.updateMany({
      where: {
        documentType: doc.documentType,
        tenantId: doc.tenantId,
        isActive: true,
      },
      data: { isActive: false },
    });

    const published = await this.prisma.complianceDocument.update({
      where: { id: documentId },
      data: { isActive: true, publishedAt: new Date() },
    });

    await this.audit.log({
      tenantId: tenantId ?? doc.tenantId ?? '',
      actorId,
      action: AuditAction.UPDATE,
      resourceType: 'ComplianceDocument',
      resourceId: documentId,
      metadata: {
        documentType: doc.documentType,
        version: doc.version,
        published: true,
      },
    });

    return published;
  }

  async seedDefaultDocuments(tenantId: string, createdById?: string) {
    const defaults: Array<{
      type: ComplianceDocumentType;
      title: string;
      content: string;
    }> = [
      {
        type: ComplianceDocumentType.PRIVACY_POLICY,
        title: 'Privacy Policy',
        content:
          'This Privacy Policy describes how BloomOra collects, uses, and protects your information in accordance with applicable privacy laws.',
      },
      {
        type: ComplianceDocumentType.TERMS_OF_USE,
        title: 'Terms of Use',
        content:
          'By using BloomOra you agree to these Terms of Use governing access to the platform and clinical services.',
      },
      {
        type: ComplianceDocumentType.HIPAA_NOTICE,
        title: 'HIPAA Notice of Privacy Practices',
        content:
          'This Notice describes how medical information about you may be used and disclosed and how you can get access to this information.',
      },
      {
        type: ComplianceDocumentType.DATA_RETENTION_POLICY,
        title: 'Data Retention Policy',
        content:
          'Clinical records are retained for seven (7) years; billing records for six (6) years unless a longer period is required by law.',
      },
      {
        type: ComplianceDocumentType.BREACH_NOTIFICATION_POLICY,
        title: 'Breach Notification Policy',
        content:
          'In the event of a breach of unsecured PHI, affected individuals and HHS will be notified as required by 45 CFR §§ 164.400–414.',
      },
      {
        type: ComplianceDocumentType.CONTACT_COMPLIANCE_OFFICER,
        title: 'Contact the Compliance Officer',
        content:
          'Privacy and security concerns may be reported to privacy@bloomora.health or through the in-app Privacy Center.',
      },
    ];

    for (const item of defaults) {
      const existing = await this.getActiveDocument(item.type, tenantId);
      if (existing) continue;
      await this.createVersion(createdById ?? '', tenantId, {
        documentType: item.type,
        version: '1.0',
        title: item.title,
        content: item.content,
        publish: true,
      });
    }
  }
}
