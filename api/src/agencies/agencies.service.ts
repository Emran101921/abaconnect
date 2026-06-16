import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import {
  existsSync,
  mkdirSync,
  writeFileSync,
} from 'fs';
import { join } from 'path';
import {
  AgencyDocumentType,
  AgencyTherapistStatus,
} from '../../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';

export interface UpdateAgencyProfileData {
  name?: string;
  ein?: string;
  phone?: string;
  addressLine1?: string;
  addressLine2?: string;
  city?: string;
  state?: string;
  zipCode?: string;
  email?: string;
  website?: string;
}

export interface CreateAgencyStaffData {
  email: string;
  password: string;
  firstName: string;
  lastName: string;
  phone?: string;
  licenseNumber?: string;
  licenseState?: string;
  npi?: string;
}

@Injectable()
export class AgenciesService {
  private readonly uploadRoot =
    process.env.UPLOAD_DIR ?? join(process.cwd(), 'uploads');

  constructor(private readonly prisma: PrismaService) {
    if (!existsSync(this.uploadRoot)) {
      mkdirSync(this.uploadRoot, { recursive: true });
    }
  }

  async resolveAgencyForAdmin(userId: string, tenantId: string) {
    const user = await this.prisma.user.findFirst({
      where: { id: userId, tenantId, role: 'AGENCY_ADMIN' },
      include: { agency: true },
    });
    if (!user) {
      throw new NotFoundException('Agency admin not found');
    }
    if (user.agencyId && user.agency) {
      return user.agency;
    }
    const fallback = await this.prisma.agency.findFirst({
      where: { tenantId },
      orderBy: { createdAt: 'asc' },
    });
    if (!fallback) {
      throw new NotFoundException('Agency not found');
    }
    return fallback;
  }

  async getAgencyProfile(agencyId: string, tenantId: string) {
    const agency = await this.prisma.agency.findFirst({
      where: { id: agencyId, tenantId },
      include: {
        documents: { orderBy: { uploadedAt: 'desc' } },
      },
    });
    if (!agency) {
      throw new NotFoundException('Agency not found');
    }
    return agency;
  }

  async updateAgencyProfile(
    agencyId: string,
    tenantId: string,
    data: UpdateAgencyProfileData,
  ) {
    await this.getAgencyProfile(agencyId, tenantId);
    return this.prisma.agency.update({
      where: { id: agencyId },
      data: {
        name: data.name?.trim(),
        ein: data.ein?.trim(),
        phone: data.phone?.trim(),
        addressLine1: data.addressLine1?.trim(),
        addressLine2: data.addressLine2?.trim(),
        city: data.city?.trim(),
        state: data.state?.trim(),
        zipCode: data.zipCode?.trim(),
        email: data.email?.trim(),
        website: data.website?.trim(),
      },
    });
  }

  async getAgencyOnboardingStatus(agencyId: string, tenantId: string) {
    const agency = await this.getAgencyProfile(agencyId, tenantId);
    const docs = await this.prisma.agencyDocument.findMany({
      where: { agencyId },
      select: { type: true },
    });
    const uploadedTypes = new Set(docs.map((d) => d.type));
    const requiredDocs: AgencyDocumentType[] = ['BAA', 'BUSINESS_LICENSE'];
    const missingDocuments = requiredDocs.filter(
      (t) => !uploadedTypes.has(t),
    );
    const profileComplete = Boolean(agency.name?.trim());
    const documentsComplete = missingDocuments.length === 0;
    const canComplete = profileComplete && documentsComplete;
    return {
      profileComplete,
      documentsComplete,
      onboardingComplete: agency.onboardingComplete,
      missingDocuments,
      canComplete,
      uploadedDocumentTypes: [...uploadedTypes],
    };
  }

  async completeAgencyOnboarding(agencyId: string, tenantId: string) {
    const status = await this.getAgencyOnboardingStatus(agencyId, tenantId);
    if (!status.canComplete) {
      throw new BadRequestException(
        'Agency profile and required documents must be complete before submitting',
      );
    }
    return this.prisma.agency.update({
      where: { id: agencyId },
      data: { onboardingComplete: true },
    });
  }

  async uploadAgencyDocument(
    agencyId: string,
    tenantId: string,
    userId: string,
    file: Express.Multer.File,
    type: AgencyDocumentType,
    title?: string,
  ) {
    await this.getAgencyProfile(agencyId, tenantId);
    if (!file) {
      throw new BadRequestException('File is required');
    }
    const storageKey = `tenants/${tenantId}/agency-docs/${agencyId}/${Date.now()}_${file.originalname}`;
    const absolutePath = join(this.uploadRoot, storageKey);
    const dir = join(this.uploadRoot, `tenants/${tenantId}/agency-docs/${agencyId}`);
    if (!existsSync(dir)) {
      mkdirSync(dir, { recursive: true });
    }
    writeFileSync(absolutePath, file.buffer);

    const doc = await this.prisma.agencyDocument.create({
      data: {
        agencyId,
        type,
        title: title?.trim() || file.originalname,
        fileName: file.originalname,
        mimeType: file.mimetype || 'application/octet-stream',
        storageKey,
        uploadedById: userId,
      },
    });

    if (type === 'BAA') {
      await this.prisma.agency.update({
        where: { id: agencyId },
        data: {
          baaDocumentKey: storageKey,
          baaSignedAt: new Date(),
        },
      });
    }

    await this.prisma.auditLog.create({
      data: {
        tenantId,
        actorId: userId,
        action: 'FILE_UPLOADED',
        entityType: 'agency_document',
        entityId: doc.id,
        metadata: { agencyId, type },
      },
    });

    return doc;
  }

  async createAgencyStaff(
    agencyId: string,
    tenantId: string,
    adminUserId: string,
    input: CreateAgencyStaffData,
  ) {
    await this.getAgencyProfile(agencyId, tenantId);
    const existing = await this.prisma.user.findUnique({
      where: { tenantId_email: { tenantId, email: input.email.trim() } },
    });
    if (existing) {
      throw new ConflictException('Email already registered');
    }
    if (input.password.length < 8) {
      throw new BadRequestException('Password must be at least 8 characters');
    }

    const passwordHash = await bcrypt.hash(input.password, 10);

    const result = await this.prisma.$transaction(async (tx) => {
      const user = await tx.user.create({
        data: {
          tenantId,
          email: input.email.trim(),
          passwordHash,
          role: 'THERAPIST',
          firstName: input.firstName.trim(),
          lastName: input.lastName.trim(),
          phone: input.phone?.trim(),
        },
      });
      const therapist = await tx.therapist.create({
        data: {
          userId: user.id,
          tenantId,
          licenseNumber: input.licenseNumber?.trim(),
          licenseState: input.licenseState?.trim(),
          npi: input.npi?.trim(),
          onboardingStatus: 'PENDING',
          phiAccessApproved: false,
        },
      });
      await tx.agencyTherapist.create({
        data: {
          agencyId,
          therapistId: therapist.id,
          status: 'PENDING',
        },
      });
      return { user, therapist };
    });

    await this.prisma.auditLog.create({
      data: {
        tenantId,
        actorId: adminUserId,
        action: 'USER_INVITED',
        entityType: 'therapist',
        entityId: result.therapist.id,
        metadata: { agencyId, email: input.email, created: true },
      },
    });

    return result;
  }

  async approveAgencyStaff(
    agencyId: string,
    tenantId: string,
    therapistId: string,
    adminUserId: string,
  ) {
    await this.getAgencyProfile(agencyId, tenantId);
    const link = await this.prisma.agencyTherapist.findUnique({
      where: {
        agencyId_therapistId: { agencyId, therapistId },
      },
      include: { therapist: { include: { user: true } } },
    });
    if (!link) {
      throw new NotFoundException('Staff member not found on agency roster');
    }

    const [updatedLink] = await this.prisma.$transaction([
      this.prisma.agencyTherapist.update({
        where: { id: link.id },
        data: { status: 'ACTIVE', joinedAt: new Date() },
        include: { therapist: { include: { user: true } } },
      }),
      this.prisma.therapist.update({
        where: { id: therapistId },
        data: {
          agencyApprovedAt: new Date(),
          agencyApprovedById: adminUserId,
          phiAccessApproved: true,
          onboardingStatus: 'APPROVED',
        },
      }),
    ]);

    await this.prisma.auditLog.create({
      data: {
        tenantId,
        actorId: adminUserId,
        action: 'UPDATE',
        entityType: 'therapist',
        entityId: therapistId,
        metadata: { event: 'agency_staff_approved', agencyId },
      },
    });

    return updatedLink;
  }

  private async agencyTherapistIds(agencyId: string): Promise<string[]> {
    const links = await this.prisma.agencyTherapist.findMany({
      where: {
        agencyId,
        status: { in: ['ACTIVE', 'PENDING'] },
      },
      select: { therapistId: true },
    });
    return links.map((l) => l.therapistId);
  }

  async getDashboardForAgency(agencyId: string, tenantId: string) {
    const therapistIds = await this.agencyTherapistIds(agencyId);
    const start = new Date();
    start.setHours(0, 0, 0, 0);
    const end = new Date(start);
    end.setHours(23, 59, 59, 999);
    const evvSince = new Date();
    evvSince.setDate(evvSince.getDate() - 14);

    const therapistFilter =
      therapistIds.length > 0 ? { in: therapistIds } : { in: [''] };

    const [
      therapistCount,
      activeClients,
      appointmentsToday,
      pendingTherapists,
      missingEvvCount,
      draftClaimsCount,
      cancellationsToday,
      pendingTherapistRows,
      draftClaims,
    ] = await Promise.all([
      this.prisma.agencyTherapist.count({
        where: {
          agencyId,
          status: { in: ['ACTIVE', 'PENDING'] },
        },
      }),
      this.prisma.appointment.findMany({
        where: { tenantId, agencyId, therapistId: therapistFilter },
        select: { childId: true },
        distinct: ['childId'],
      }).then((rows) => rows.length),
      this.prisma.appointment.count({
        where: {
          tenantId,
          agencyId,
          therapistId: therapistFilter,
          scheduledStart: { gte: start, lte: end },
        },
      }),
      this.prisma.therapist.count({
        where: {
          id: therapistFilter,
          tenantId,
          OR: [{ isVerified: false }, { onboardingStatus: 'PENDING' }],
        },
      }),
      this.prisma.session.count({
        where: {
          tenantId,
          therapistId: therapistFilter,
          status: 'COMPLETED',
          evvVerified: false,
          checkOutAt: { gte: evvSince },
        },
      }),
      this.prisma.insuranceClaim.count({
        where: { tenantId, therapistId: therapistFilter, status: 'DRAFT' },
      }),
      this.prisma.appointment.count({
        where: {
          tenantId,
          agencyId,
          therapistId: therapistFilter,
          status: 'CANCELLED',
          updatedAt: { gte: start, lte: end },
        },
      }),
      this.prisma.therapist.findMany({
        where: {
          id: therapistFilter,
          tenantId,
          OR: [{ isVerified: false }, { onboardingStatus: 'PENDING' }],
        },
        take: 3,
        include: { user: true },
      }),
      this.prisma.insuranceClaim.findMany({
        where: { tenantId, therapistId: therapistFilter, status: 'DRAFT' },
        take: 3,
        include: { child: true },
      }),
    ]);

    const actionItems = [];
    if (pendingTherapists > 0) {
      actionItems.push({
        id: 'pending-therapists',
        title: 'Therapists awaiting verification',
        subtitle: `${pendingTherapists} pending`,
        actionType: 'VERIFICATION',
        priority: 0,
      });
    }
    if (missingEvvCount > 0) {
      actionItems.push({
        id: 'missing-evv',
        title: 'Sessions missing EVV',
        subtitle: `${missingEvvCount} in last 14 days`,
        actionType: 'EVV',
        priority: 1,
      });
    }
    for (const claim of draftClaims) {
      actionItems.push({
        id: `claim-${claim.id}`,
        title: 'Draft insurance claim',
        subtitle: claim.child
          ? `${claim.child.firstName} ${claim.child.lastName}`
          : claim.payerName,
        actionType: 'CLAIM',
        claimId: claim.id,
        priority: 2,
      });
    }
    for (const t of pendingTherapistRows) {
      actionItems.push({
        id: `therapist-${t.id}`,
        title: 'Verify therapist',
        subtitle: `${t.user.firstName} ${t.user.lastName}`,
        actionType: 'VERIFICATION',
        priority: 3,
      });
    }

    return {
      therapistCount,
      activeClients,
      appointmentsToday,
      pendingTherapists,
      missingEvvCount,
      draftClaimsCount,
      cancellationsToday,
      actionItems,
    };
  }

  async getDashboardForTenant(tenantId: string) {
    const agency = await this.prisma.agency.findFirst({
      where: { tenantId },
      orderBy: { createdAt: 'asc' },
    });
    if (!agency) {
      return {
        therapistCount: 0,
        activeClients: 0,
        appointmentsToday: 0,
        pendingTherapists: 0,
        missingEvvCount: 0,
        draftClaimsCount: 0,
        cancellationsToday: 0,
        actionItems: [],
      };
    }
    return this.getDashboardForAgency(agency.id, tenantId);
  }

  async listTherapistsForAgency(agencyId: string) {
    const links = await this.prisma.agencyTherapist.findMany({
      where: {
        agencyId,
        status: { in: ['ACTIVE', 'PENDING'] },
      },
      include: {
        therapist: { include: { user: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
    return links.map((l) => ({
      ...l.therapist,
      rosterStatus: l.status,
    }));
  }

  async listTherapistsForTenant(tenantId: string) {
    const agency = await this.prisma.agency.findFirst({
      where: { tenantId },
      orderBy: { createdAt: 'asc' },
    });
    if (!agency) {
      return [];
    }
    return this.listTherapistsForAgency(agency.id);
  }

  async inviteTherapistForAgency(
    agencyId: string,
    tenantId: string,
    therapistId: string,
  ) {
    await this.getAgencyProfile(agencyId, tenantId);
    const therapist = await this.prisma.therapist.findFirst({
      where: { id: therapistId, tenantId },
      include: { user: true },
    });
    if (!therapist) {
      throw new NotFoundException('Therapist not found');
    }

    return this.prisma.agencyTherapist.upsert({
      where: {
        agencyId_therapistId: {
          agencyId,
          therapistId: therapist.id,
        },
      },
      update: { status: 'PENDING' },
      create: {
        agencyId,
        therapistId: therapist.id,
        status: 'PENDING',
      },
      include: { therapist: { include: { user: true } }, agency: true },
    });
  }

  async inviteTherapistForTenant(tenantId: string, therapistId: string) {
    const agency = await this.prisma.agency.findFirst({
      where: { tenantId },
      orderBy: { createdAt: 'asc' },
    });
    if (!agency) {
      throw new NotFoundException('Agency not found for tenant');
    }
    return this.inviteTherapistForAgency(agency.id, tenantId, therapistId);
  }

  async removeTherapistFromAgency(
    tenantId: string,
    therapistId: string,
    agencyId?: string,
  ) {
    const agency =
      agencyId != null
        ? await this.prisma.agency.findFirst({ where: { id: agencyId, tenantId } })
        : await this.prisma.agency.findFirst({ where: { tenantId } });
    if (!agency) {
      throw new NotFoundException('Agency not found');
    }

    const link = await this.prisma.agencyTherapist.findUnique({
      where: {
        agencyId_therapistId: {
          agencyId: agency.id,
          therapistId,
        },
      },
      include: { therapist: { include: { user: true } } },
    });
    if (!link) {
      throw new NotFoundException('Therapist is not on this agency roster');
    }

    await this.prisma.agencyTherapist.update({
      where: { id: link.id },
      data: { status: 'INACTIVE' },
    });

    return link.therapist;
  }

  async listUpcomingAppointmentsForAgency(agencyId: string, tenantId: string, days = 14) {
    const therapistIds = await this.agencyTherapistIds(agencyId);
    const start = new Date();
    start.setHours(0, 0, 0, 0);
    const end = new Date(start);
    end.setDate(end.getDate() + days);

    return this.prisma.appointment.findMany({
      where: {
        tenantId,
        agencyId,
        therapistId: therapistIds.length ? { in: therapistIds } : { in: [''] },
        scheduledStart: { gte: start, lte: end },
        status: { notIn: ['CANCELLED', 'NO_SHOW'] },
      },
      include: {
        child: true,
        therapist: { include: { user: true } },
      },
      orderBy: { scheduledStart: 'asc' },
      take: 100,
    });
  }

  async listUpcomingAppointmentsForTenant(tenantId: string, days = 14) {
    const agency = await this.prisma.agency.findFirst({
      where: { tenantId },
      orderBy: { createdAt: 'asc' },
    });
    if (!agency) {
      return [];
    }
    return this.listUpcomingAppointmentsForAgency(agency.id, tenantId, days);
  }

  async listUnlinkedTherapistsForAgency(agencyId: string, tenantId: string) {
    const linked = await this.prisma.agencyTherapist.findMany({
      where: { agencyId },
      select: { therapistId: true },
    });
    const linkedIds = linked.map((l) => l.therapistId);
    return this.prisma.therapist.findMany({
      where: {
        tenantId,
        id: linkedIds.length ? { notIn: linkedIds } : undefined,
      },
      include: { user: true },
      take: 50,
      orderBy: { createdAt: 'desc' },
    });
  }

  async listUnlinkedTherapistsForTenant(tenantId: string) {
    const agency = await this.prisma.agency.findFirst({
      where: { tenantId },
    });
    if (!agency) {
      return [];
    }
    return this.listUnlinkedTherapistsForAgency(agency.id, tenantId);
  }

  async create(data: Record<string, unknown>) {
    const tenantId = data.tenantId as string | undefined;
    const therapistId = data.therapistId as string | undefined;
    if (tenantId && therapistId) {
      const link = await this.inviteTherapistForTenant(tenantId, therapistId);
      return {
        id: link.id,
        agencyId: link.agencyId,
        therapistId: link.therapistId,
      };
    }
    throw new BadRequestException('Provide tenantId and therapistId');
  }

  async setAgencyBaaSigned(
    tenantId: string,
    agencyId: string,
    data: { baaSignedAt: Date; baaDocumentKey?: string },
  ) {
    const agency = await this.prisma.agency.findFirst({
      where: { id: agencyId, tenantId },
    });
    if (!agency) {
      throw new NotFoundException('Agency not found');
    }
    return this.prisma.agency.update({
      where: { id: agencyId },
      data: {
        baaSignedAt: data.baaSignedAt,
        baaDocumentKey: data.baaDocumentKey,
      },
    });
  }

  async findAll() {
    return this.prisma.agency.findMany({ take: 50 });
  }

  async findOne(id: string) {
    const agency = await this.prisma.agency.findUnique({ where: { id } });
    if (!agency) {
      throw new NotFoundException('Agency not found');
    }
    return agency;
  }

  async update(id: string, data: Record<string, unknown>) {
    await this.findOne(id);
    return this.prisma.agency.update({
      where: { id },
      data: data as Parameters<typeof this.prisma.agency.update>[0]['data'],
    });
  }

  async remove(id: string) {
    await this.findOne(id);
    await this.prisma.agency.delete({ where: { id } });
    return { id, deleted: true };
  }
}

export type AgencyStaffRosterStatus = AgencyTherapistStatus;
