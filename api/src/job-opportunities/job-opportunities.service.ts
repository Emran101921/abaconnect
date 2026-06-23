import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  AgencyTherapistStatus,
  JobApplicationStatus,
  JobOpportunityStatus,
  Prisma,
} from '../../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { JOB_MARKETPLACE_EVENT_TYPES } from './job-opportunity.constants';
import {
  buildJobOpportunityTitle,
  buildLocationAreaLabel,
  scanJobOpportunityPublicText,
} from './job-opportunity-phi.util';
import { toPublicJobOpportunity } from './job-opportunity-privacy.util';
import {
  haversineMiles,
  zipToApproxCentroid,
} from './job-opportunity-zip.util';

type BrowseFilters = {
  zipCode?: string;
  radiusMiles?: number;
  serviceType?: string;
  employmentType?: string;
  locationModality?: string;
  language?: string;
  page?: number;
  pageSize?: number;
};

@Injectable()
export class JobOpportunitiesService {
  constructor(private readonly prisma: PrismaService) {}

  async createChildServiceNeed(
    userId: string,
    tenantId: string,
    input: {
      childId: string;
      serviceType: string;
      internalNotes?: string;
      internalSchedule?: Record<string, unknown>;
    },
  ) {
    const agency = await this.resolveAgencyForAdmin(userId, tenantId);
    await this.assertChildInAgencyCaseload(agency.id, input.childId);

    const need = await this.prisma.childServiceNeed.create({
      data: {
        agencyId: agency.id,
        childId: input.childId,
        serviceType: input.serviceType as never,
        internalNotes: input.internalNotes,
        internalSchedule: (input.internalSchedule ??
          {}) as Prisma.InputJsonValue,
        createdByUserId: userId,
      },
      include: {
        child: { select: { firstName: true, lastName: true, zipCode: true } },
      },
    });

    await this.logAudit(tenantId, {
      eventType: JOB_MARKETPLACE_EVENT_TYPES.CHILD_SERVICE_NEED_CREATED,
      entityType: 'ChildServiceNeed',
      entityId: need.id,
      actorUserId: userId,
      metadata: { serviceType: input.serviceType },
    });

    return need;
  }

  async generateJobOpportunityFromNeed(
    userId: string,
    tenantId: string,
    childServiceNeedId: string,
  ) {
    const agency = await this.resolveAgencyForAdmin(userId, tenantId);
    const need = await this.prisma.childServiceNeed.findFirst({
      where: { id: childServiceNeedId, agencyId: agency.id },
      include: { child: true, jobOpportunity: true },
    });
    if (!need) {
      throw new NotFoundException('Service need not found');
    }
    if (need.jobOpportunity) {
      throw new BadRequestException(
        'A job opportunity already exists for this service need',
      );
    }

    const zipFromChild = need.child.zipCode?.replace(/\D/g, '').slice(0, 5);
    const zipFromAgency = agency.zipCode?.replace(/\D/g, '').slice(0, 5);
    const zipCode =
      zipFromChild && zipFromChild.length >= 5 ? zipFromChild : zipFromAgency;
    if (!zipCode || zipCode.length < 5) {
      throw new BadRequestException(
        'Add a ZIP code on the child profile or agency profile before creating a posting',
      );
    }

    const centroid = zipToApproxCentroid(zipCode);
    const locationLabel = buildLocationAreaLabel(null, null, zipCode);
    const title = buildJobOpportunityTitle(need.serviceType, locationLabel);

    const opportunity = await this.prisma.$transaction(async (tx) => {
      const row = await tx.jobOpportunity.create({
        data: {
          tenantId,
          agencyId: agency.id,
          childServiceNeedId: need.id,
          title,
          serviceType: need.serviceType,
          status: 'DRAFT',
          zipCode,
          zipCentroidLat: centroid.lat,
          zipCentroidLng: centroid.lng,
          schedule: need.internalSchedule as Prisma.InputJsonValue,
          serviceRadiusMiles: 15,
        },
        include: { agency: true },
      });
      await tx.childServiceNeed.update({
        where: { id: need.id },
        data: { status: 'JOB_POSTED' },
      });
      return row;
    });

    await this.logAudit(tenantId, {
      eventType: JOB_MARKETPLACE_EVENT_TYPES.JOB_OPPORTUNITY_GENERATED,
      entityType: 'JobOpportunity',
      entityId: opportunity.id,
      actorUserId: userId,
      metadata: { childServiceNeedId: need.id },
    });

    return opportunity;
  }

  async updateJobOpportunityDraft(
    userId: string,
    tenantId: string,
    jobOpportunityId: string,
    input: {
      title?: string;
      publicDescription?: string;
      zipCode?: string;
      borough?: string;
      county?: string;
      serviceRadiusMiles?: number;
      schedule?: Record<string, unknown>;
      languageRequirement?: string;
      employmentType?: string;
      payRateMin?: number;
      payRateMax?: number;
      payRateDisplay?: string;
      locationModality?: string;
      requiredCredentials?: unknown[];
      requiredExperience?: string;
      preferredStartDate?: Date;
    },
  ) {
    const agency = await this.resolveAgencyForAdmin(userId, tenantId);
    const existing = await this.requireAgencyJobOpportunity(
      agency.id,
      jobOpportunityId,
    );
    if (!['DRAFT', 'PAUSED', 'PENDING_REVIEW'].includes(existing.status)) {
      throw new BadRequestException(
        'Only draft or paused postings can be edited',
      );
    }

    let zipUpdate: { zipCentroidLat: number; zipCentroidLng: number } | undefined;
    if (input.zipCode) {
      const zip = input.zipCode.replace(/\D/g, '').slice(0, 5);
      const centroid = zipToApproxCentroid(zip);
      zipUpdate = { zipCentroidLat: centroid.lat, zipCentroidLng: centroid.lng };
    }

    const updated = await this.prisma.jobOpportunity.update({
      where: { id: jobOpportunityId },
      data: {
        title: input.title,
        publicDescription: input.publicDescription,
        zipCode: input.zipCode?.replace(/\D/g, '').slice(0, 5),
        borough: input.borough,
        county: input.county,
        serviceRadiusMiles: input.serviceRadiusMiles,
        schedule: input.schedule as Prisma.InputJsonValue | undefined,
        languageRequirement: input.languageRequirement,
        employmentType: input.employmentType as never,
        payRateMin: input.payRateMin,
        payRateMax: input.payRateMax,
        payRateDisplay: input.payRateDisplay,
        locationModality: input.locationModality as never,
        requiredCredentials: input.requiredCredentials as
          | Prisma.InputJsonValue
          | undefined,
        requiredExperience: input.requiredExperience,
        preferredStartDate: input.preferredStartDate,
        ...(zipUpdate ?? {}),
        phiScanPassed: false,
        phiScanFlags: [],
      },
      include: { agency: true, _count: { select: { applications: true } } },
    });

    await this.logAudit(tenantId, {
      eventType: JOB_MARKETPLACE_EVENT_TYPES.JOB_OPPORTUNITY_DRAFT_UPDATED,
      entityType: 'JobOpportunity',
      entityId: updated.id,
      actorUserId: userId,
    });

    return updated;
  }

  async publishJobOpportunity(
    userId: string,
    tenantId: string,
    jobOpportunityId: string,
  ) {
    const agency = await this.resolveAgencyForAdmin(userId, tenantId);
    const existing = await this.requireAgencyJobOpportunity(
      agency.id,
      jobOpportunityId,
    );

    const scan = scanJobOpportunityPublicText(
      existing.title,
      existing.publicDescription,
      existing.requiredExperience,
      existing.payRateDisplay,
    );

    if (!scan.passed) {
      await this.prisma.jobOpportunity.update({
        where: { id: jobOpportunityId },
        data: {
          status: 'BLOCKED',
          phiScanPassed: false,
          phiScanFlags: scan.flags as Prisma.InputJsonValue,
          moderationNote: scan.blockedMessage,
        },
      });
      await this.logAudit(tenantId, {
        eventType: JOB_MARKETPLACE_EVENT_TYPES.JOB_OPPORTUNITY_PUBLISH_BLOCKED,
        entityType: 'JobOpportunity',
        entityId: jobOpportunityId,
        actorUserId: userId,
        metadata: { flags: scan.flags },
      });
      throw new BadRequestException(scan.blockedMessage);
    }

    const published = await this.prisma.jobOpportunity.update({
      where: { id: jobOpportunityId },
      data: {
        status: 'PUBLISHED',
        phiScanPassed: true,
        phiScanFlags: scan.flags as Prisma.InputJsonValue,
        publishedAt: new Date(),
        moderationNote: null,
      },
      include: { agency: true, _count: { select: { applications: true } } },
    });

    await this.logAudit(tenantId, {
      eventType: JOB_MARKETPLACE_EVENT_TYPES.JOB_OPPORTUNITY_PUBLISHED,
      entityType: 'JobOpportunity',
      entityId: published.id,
      actorUserId: userId,
    });

    return published;
  }

  async browseJobOpportunitiesForTherapist(
    userId: string,
    tenantId: string,
    filters: BrowseFilters,
  ) {
    const therapist = await this.requireTherapist(userId, tenantId);
    const page = filters.page ?? 1;
    const pageSize = Math.min(filters.pageSize ?? 20, 50);

    const rows = await this.prisma.jobOpportunity.findMany({
      where: {
        tenantId,
        status: 'PUBLISHED',
        ...(filters.serviceType
          ? { serviceType: filters.serviceType as never }
          : {}),
        ...(filters.employmentType
          ? { employmentType: filters.employmentType as never }
          : {}),
        ...(filters.locationModality
          ? { locationModality: filters.locationModality as never }
          : {}),
        ...(filters.language
          ? {
              languageRequirement: {
                contains: filters.language,
                mode: 'insensitive',
              },
            }
          : {}),
      },
      include: {
        agency: true,
        _count: { select: { applications: true } },
      },
      orderBy: { publishedAt: 'desc' },
      skip: (page - 1) * pageSize,
      take: pageSize,
    });

    let originLat: number | undefined;
    let originLng: number | undefined;
    if (filters.zipCode) {
      const centroid = zipToApproxCentroid(filters.zipCode);
      originLat = centroid.lat;
      originLng = centroid.lng;
    } else if (therapist.zipCode) {
      const centroid = zipToApproxCentroid(therapist.zipCode);
      originLat = centroid.lat;
      originLng = centroid.lng;
    }

    const radius = filters.radiusMiles ?? 50;
    const items = rows
      .map((row) => {
        let distanceMiles: number | undefined;
        if (
          originLat != null &&
          originLng != null &&
          row.zipCentroidLat != null &&
          row.zipCentroidLng != null
        ) {
          distanceMiles = haversineMiles(
            originLat,
            originLng,
            Number(row.zipCentroidLat),
            Number(row.zipCentroidLng),
          );
        }
        return toPublicJobOpportunity(row, { distanceMiles });
      })
      .filter((item) =>
        originLat != null && item.distanceMiles != null
          ? item.distanceMiles <= radius
          : true,
      );

    return { items, page, pageSize, total: items.length };
  }

  async applyToJobOpportunity(
    userId: string,
    tenantId: string,
    jobOpportunityId: string,
    message?: string,
  ) {
    const therapist = await this.requireTherapist(userId, tenantId);
    const opportunity = await this.prisma.jobOpportunity.findFirst({
      where: { id: jobOpportunityId, tenantId, status: 'PUBLISHED' },
    });
    if (!opportunity) {
      throw new NotFoundException('Published job opportunity not found');
    }

    const wallet = await this.prisma.therapistCredentialWallet.findUnique({
      where: { therapistId: therapist.id },
    });

    const application = await this.prisma.jobOpportunityApplication.upsert({
      where: {
        jobOpportunityId_therapistId: {
          jobOpportunityId,
          therapistId: therapist.id,
        },
      },
      update: {
        status: 'NEW_APPLICANT',
        message,
        credentialSnapshot: (wallet?.documents ??
          []) as Prisma.InputJsonValue,
      },
      create: {
        jobOpportunityId,
        therapistId: therapist.id,
        applicantUserId: userId,
        message,
        credentialSnapshot: (wallet?.documents ??
          []) as Prisma.InputJsonValue,
      },
      include: {
        therapist: { include: { user: true } },
        jobOpportunity: { include: { agency: true } },
      },
    });

    await this.logAudit(tenantId, {
      eventType: JOB_MARKETPLACE_EVENT_TYPES.JOB_APPLICATION_SUBMITTED,
      entityType: 'JobOpportunityApplication',
      entityId: application.id,
      actorUserId: userId,
      metadata: { jobOpportunityId },
    });

    return application;
  }

  async withdrawApplication(
    userId: string,
    tenantId: string,
    applicationId: string,
  ) {
    const therapist = await this.requireTherapist(userId, tenantId);
    const application = await this.prisma.jobOpportunityApplication.findFirst({
      where: { id: applicationId, therapistId: therapist.id },
    });
    if (!application) {
      throw new NotFoundException('Application not found');
    }
    if (application.status === 'HIRED_CONTRACTED') {
      throw new BadRequestException('Cannot withdraw a hired application');
    }

    const updated = await this.prisma.$transaction(async (tx) => {
      const row = await tx.jobOpportunityApplication.update({
        where: { id: applicationId },
        data: { status: 'WITHDRAWN' },
      });
      await tx.applicationStatusHistory.create({
        data: {
          applicationId,
          fromStatus: application.status,
          toStatus: 'WITHDRAWN',
          changedByUserId: userId,
          note: 'Applicant withdrew',
        },
      });
      return row;
    });

    await this.logAudit(tenantId, {
      eventType: JOB_MARKETPLACE_EVENT_TYPES.JOB_APPLICATION_WITHDRAWN,
      entityType: 'JobOpportunityApplication',
      entityId: applicationId,
      actorUserId: userId,
    });

    return updated;
  }

  async agencyListApplications(
    userId: string,
    tenantId: string,
    jobOpportunityId?: string,
  ) {
    const agency = await this.resolveAgencyForAdmin(userId, tenantId);
    return this.prisma.jobOpportunityApplication.findMany({
      where: {
        jobOpportunity: {
          agencyId: agency.id,
          ...(jobOpportunityId ? { id: jobOpportunityId } : {}),
        },
      },
      include: {
        therapist: { include: { user: true } },
        jobOpportunity: true,
        statusHistory: { orderBy: { createdAt: 'desc' }, take: 5 },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async updateApplicationStatus(
    userId: string,
    tenantId: string,
    applicationId: string,
    status: JobApplicationStatus,
    note?: string,
  ) {
    const agency = await this.resolveAgencyForAdmin(userId, tenantId);
    const application = await this.prisma.jobOpportunityApplication.findFirst({
      where: {
        id: applicationId,
        jobOpportunity: { agencyId: agency.id },
      },
    });
    if (!application) {
      throw new NotFoundException('Application not found');
    }

    const updated = await this.prisma.$transaction(async (tx) => {
      const row = await tx.jobOpportunityApplication.update({
        where: { id: applicationId },
        data: { status },
        include: {
          therapist: { include: { user: true } },
          jobOpportunity: true,
        },
      });
      await tx.applicationStatusHistory.create({
        data: {
          applicationId,
          fromStatus: application.status,
          toStatus: status,
          changedByUserId: userId,
          note,
        },
      });
      return row;
    });

    await this.logAudit(tenantId, {
      eventType: JOB_MARKETPLACE_EVENT_TYPES.JOB_APPLICATION_STATUS_CHANGED,
      entityType: 'JobOpportunityApplication',
      entityId: applicationId,
      actorUserId: userId,
      metadata: { fromStatus: application.status, toStatus: status, note },
    });

    return updated;
  }

  async requestDocuments(
    userId: string,
    tenantId: string,
    applicationId: string,
    note?: string,
  ) {
    const updated = await this.updateApplicationStatus(
      userId,
      tenantId,
      applicationId,
      'CREDENTIAL_REVIEW',
      note ?? 'Additional documents requested',
    );

    await this.logAudit(tenantId, {
      eventType: JOB_MARKETPLACE_EVENT_TYPES.DOCUMENTS_REQUESTED,
      entityType: 'JobOpportunityApplication',
      entityId: applicationId,
      actorUserId: userId,
    });

    return updated;
  }

  async markHiredContracted(
    userId: string,
    tenantId: string,
    applicationId: string,
    note?: string,
  ) {
    const updated = await this.updateApplicationStatus(
      userId,
      tenantId,
      applicationId,
      'HIRED_CONTRACTED',
      note ?? 'Marked hired/contracted',
    );

    await this.logAudit(tenantId, {
      eventType: JOB_MARKETPLACE_EVENT_TYPES.THERAPIST_HIRED_CONTRACTED,
      entityType: 'JobOpportunityApplication',
      entityId: applicationId,
      actorUserId: userId,
    });

    return updated;
  }

  async addTherapistToAgencyRosterFromApplication(
    userId: string,
    tenantId: string,
    applicationId: string,
  ) {
    const agency = await this.resolveAgencyForAdmin(userId, tenantId);
    const application = await this.prisma.jobOpportunityApplication.findFirst({
      where: {
        id: applicationId,
        status: 'HIRED_CONTRACTED',
        jobOpportunity: { agencyId: agency.id },
      },
      include: { therapist: true, jobOpportunity: true },
    });
    if (!application) {
      throw new BadRequestException(
        'Application must be HIRED_CONTRACTED before adding to roster',
      );
    }

    const link = await this.prisma.agencyTherapist.upsert({
      where: {
        agencyId_therapistId: {
          agencyId: agency.id,
          therapistId: application.therapistId,
        },
      },
      update: {
        status: 'ACTIVE' satisfies AgencyTherapistStatus,
        joinedAt: new Date(),
      },
      create: {
        agencyId: agency.id,
        therapistId: application.therapistId,
        status: 'ACTIVE',
        joinedAt: new Date(),
      },
      include: { therapist: { include: { user: true } } },
    });

    await this.prisma.childServiceNeed.update({
      where: { id: application.jobOpportunity.childServiceNeedId },
      data: { status: 'FILLED' },
    });

    await this.logAudit(tenantId, {
      eventType: JOB_MARKETPLACE_EVENT_TYPES.THERAPIST_ADDED_TO_ROSTER,
      entityType: 'AgencyTherapist',
      entityId: link.id,
      actorUserId: userId,
      metadata: { applicationId, therapistId: application.therapistId },
    });

    return link;
  }

  async listChildServiceNeeds(userId: string, tenantId: string) {
    const agency = await this.resolveAgencyForAdmin(userId, tenantId);
    return this.prisma.childServiceNeed.findMany({
      where: { agencyId: agency.id },
      include: {
        child: { select: { id: true, firstName: true, lastName: true } },
        jobOpportunity: { select: { id: true, status: true, title: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async listAgencyJobOpportunities(userId: string, tenantId: string) {
    const agency = await this.resolveAgencyForAdmin(userId, tenantId);
    return this.prisma.jobOpportunity.findMany({
      where: { agencyId: agency.id },
      include: {
        agency: true,
        _count: { select: { applications: true } },
      },
      orderBy: { updatedAt: 'desc' },
    });
  }

  async listTherapistApplications(userId: string, tenantId: string) {
    const therapist = await this.requireTherapist(userId, tenantId);
    return this.prisma.jobOpportunityApplication.findMany({
      where: { therapistId: therapist.id },
      include: {
        jobOpportunity: { include: { agency: true } },
        statusHistory: { orderBy: { createdAt: 'desc' }, take: 3 },
      },
      orderBy: { updatedAt: 'desc' },
    });
  }

  async listSavedJobOpportunities(userId: string, tenantId: string) {
    const therapist = await this.requireTherapist(userId, tenantId);
    const saved = await this.prisma.savedJobOpportunity.findMany({
      where: { therapistId: therapist.id },
      include: {
        jobOpportunity: {
          include: { agency: true, _count: { select: { applications: true } } },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
    return saved.map((row) => row.jobOpportunity);
  }

  async adminListJobOpportunities(tenantId: string) {
    return this.prisma.jobOpportunity.findMany({
      where: { tenantId },
      include: {
        agency: true,
        _count: { select: { applications: true, moderationFlags: true } },
      },
      orderBy: { updatedAt: 'desc' },
    });
  }

  async adminListApplications(tenantId: string) {
    return this.prisma.jobOpportunityApplication.findMany({
      where: { jobOpportunity: { tenantId } },
      include: {
        therapist: { include: { user: true } },
        jobOpportunity: { include: { agency: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: 200,
    });
  }

  async adminMarketplaceAuditLogs(tenantId: string) {
    return this.prisma.marketplaceAuditLog.findMany({
      where: { tenantId },
      include: { actor: true },
      orderBy: { createdAt: 'desc' },
      take: 200,
    });
  }

  async adminPauseJobOpportunity(
    adminUserId: string,
    tenantId: string,
    jobOpportunityId: string,
    reason?: string,
  ) {
    const row = await this.prisma.jobOpportunity.findFirst({
      where: { id: jobOpportunityId, tenantId },
    });
    if (!row) throw new NotFoundException('Job opportunity not found');

    const updated = await this.prisma.jobOpportunity.update({
      where: { id: jobOpportunityId },
      data: {
        status: 'PAUSED',
        moderationNote: reason ?? 'Paused by platform admin',
      },
      include: { agency: true },
    });

    await this.logAudit(tenantId, {
      eventType: JOB_MARKETPLACE_EVENT_TYPES.JOB_OPPORTUNITY_PAUSED,
      entityType: 'JobOpportunity',
      entityId: jobOpportunityId,
      actorUserId: adminUserId,
      metadata: { reason },
    });

    return updated;
  }

  async adminRemoveJobOpportunity(
    adminUserId: string,
    tenantId: string,
    jobOpportunityId: string,
    reason: string,
  ) {
    const row = await this.prisma.jobOpportunity.findFirst({
      where: { id: jobOpportunityId, tenantId },
    });
    if (!row) throw new NotFoundException('Job opportunity not found');

    const updated = await this.prisma.jobOpportunity.update({
      where: { id: jobOpportunityId },
      data: {
        status: 'REMOVED',
        moderationNote: reason,
      },
      include: { agency: true },
    });

    await this.logAudit(tenantId, {
      eventType: JOB_MARKETPLACE_EVENT_TYPES.JOB_OPPORTUNITY_REMOVED,
      entityType: 'JobOpportunity',
      entityId: jobOpportunityId,
      actorUserId: adminUserId,
      metadata: { reason },
    });

    return updated;
  }

  mapPublicJob(row: Parameters<typeof toPublicJobOpportunity>[0]) {
    return toPublicJobOpportunity(row);
  }

  private async resolveAgencyForAdmin(userId: string, tenantId: string) {
    const user = await this.prisma.user.findFirst({
      where: { id: userId, tenantId, role: 'AGENCY_ADMIN' },
      include: { agency: true },
    });
    if (!user) {
      throw new ForbiddenException('Agency admin access required');
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

  private async requireTherapist(userId: string, tenantId: string) {
    const therapist = await this.prisma.therapist.findFirst({
      where: { userId, tenantId },
    });
    if (!therapist) {
      throw new ForbiddenException('Therapist profile required');
    }
    return therapist;
  }

  private async requireAgencyJobOpportunity(
    agencyId: string,
    jobOpportunityId: string,
  ) {
    const row = await this.prisma.jobOpportunity.findFirst({
      where: { id: jobOpportunityId, agencyId },
      include: { agency: true },
    });
    if (!row) {
      throw new NotFoundException('Job opportunity not found');
    }
    return row;
  }

  private async assertChildInAgencyCaseload(agencyId: string, childId: string) {
    const [scAssignment, appointment, enrollment] = await Promise.all([
      this.prisma.childServiceCoordinatorAssignment.findFirst({
        where: {
          agencyId,
          childId,
          status: 'ACTIVE',
          removedAt: null,
        },
      }),
      this.prisma.appointment.findFirst({
        where: { agencyId, childId },
      }),
      this.prisma.agencyCaseloadChild.findFirst({
        where: { agencyId, childId },
      }),
    ]);
    if (!scAssignment && !appointment && !enrollment) {
      throw new ForbiddenException(
        'Child must be on agency caseload or have an active SC assignment',
      );
    }
  }

  private async logAudit(
    tenantId: string,
    input: {
      eventType: string;
      entityType: string;
      entityId: string;
      actorUserId?: string;
      metadata?: Record<string, unknown>;
    },
  ) {
    await this.prisma.marketplaceAuditLog.create({
      data: {
        tenantId,
        eventType: input.eventType,
        entityType: input.entityType,
        entityId: input.entityId,
        actorUserId: input.actorUserId,
        metadata: (input.metadata ?? {}) as Prisma.InputJsonValue,
      },
    });
  }
}
