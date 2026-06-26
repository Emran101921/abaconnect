import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  AgencyTherapistStatus,
  JobApplicationStatus,
  JobLocationModality,
  JobServiceType,
  LocationType,
  Prisma,
  TherapyType,
} from '../../generated/prisma/client';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.service';
import { CallsService } from '../calls/calls.service';
import { DocumentsService } from '../documents/documents.service';
import {
  applyHireOnboardingStep,
  buildHireOnboardingView,
  canAgencyUpdateStep,
  canTherapistUpdateStep,
  defaultHireOnboardingState,
  HireOnboardingStepKey,
  markFirstSessionScheduled,
  parseHireOnboardingState,
} from './hire-onboarding.util';
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
  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
    private readonly calls: CallsService,
    private readonly documents: DocumentsService,
  ) {}

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
    if (
      !['DRAFT', 'PAUSED', 'PENDING_REVIEW', 'BLOCKED'].includes(
        existing.status,
      )
    ) {
      throw new BadRequestException(
        'Only draft, paused, or blocked postings can be edited',
      );
    }

    let zipUpdate:
      | { zipCentroidLat: number; zipCentroidLng: number }
      | undefined;
    if (input.zipCode) {
      const zip = input.zipCode.replace(/\D/g, '').slice(0, 5);
      const centroid = zipToApproxCentroid(zip);
      zipUpdate = {
        zipCentroidLat: centroid.lat,
        zipCentroidLng: centroid.lng,
      };
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

  async getPublishedJobOpportunityForTherapist(
    userId: string,
    tenantId: string,
    jobOpportunityId: string,
  ) {
    const therapist = await this.requireTherapist(userId, tenantId);
    const existingApplication =
      await this.prisma.jobOpportunityApplication.findFirst({
        where: {
          jobOpportunityId,
          therapistId: therapist.id,
          status: { not: 'WITHDRAWN' },
        },
      });
    const row = await this.prisma.jobOpportunity.findFirst({
      where: {
        id: jobOpportunityId,
        tenantId,
        ...(existingApplication ? {} : { status: 'PUBLISHED' }),
      },
      include: {
        agency: true,
        _count: { select: { applications: true } },
      },
    });
    if (!row) {
      throw new NotFoundException('Published job opportunity not found');
    }

    let distanceMiles: number | undefined;
    if (
      therapist.zipCode &&
      row.zipCentroidLat != null &&
      row.zipCentroidLng != null
    ) {
      const centroid = zipToApproxCentroid(therapist.zipCode);
      distanceMiles = haversineMiles(
        centroid.lat,
        centroid.lng,
        Number(row.zipCentroidLat),
        Number(row.zipCentroidLng),
      );
    }

    const saved = await this.prisma.savedJobOpportunity.findUnique({
      where: {
        therapistId_jobOpportunityId: {
          therapistId: therapist.id,
          jobOpportunityId,
        },
      },
    });

    return {
      ...toPublicJobOpportunity(row, { distanceMiles }),
      isSaved: saved != null,
      myApplicationId: existingApplication?.id,
      myApplicationStatus: existingApplication?.status,
    };
  }

  async saveJobOpportunity(
    userId: string,
    tenantId: string,
    jobOpportunityId: string,
  ) {
    const therapist = await this.requireTherapist(userId, tenantId);
    const opportunity = await this.prisma.jobOpportunity.findFirst({
      where: { id: jobOpportunityId, tenantId, status: 'PUBLISHED' },
      include: {
        agency: true,
        _count: { select: { applications: true } },
      },
    });
    if (!opportunity) {
      throw new NotFoundException('Published job opportunity not found');
    }

    await this.prisma.savedJobOpportunity.upsert({
      where: {
        therapistId_jobOpportunityId: {
          therapistId: therapist.id,
          jobOpportunityId,
        },
      },
      create: {
        therapistId: therapist.id,
        jobOpportunityId,
      },
      update: {},
    });

    return {
      ...toPublicJobOpportunity(opportunity),
      isSaved: true,
    };
  }

  async unsaveJobOpportunity(
    userId: string,
    tenantId: string,
    jobOpportunityId: string,
  ) {
    const therapist = await this.requireTherapist(userId, tenantId);
    await this.prisma.savedJobOpportunity.deleteMany({
      where: {
        therapistId: therapist.id,
        jobOpportunityId,
      },
    });
    return true;
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
      const closed = await this.prisma.jobOpportunity.findFirst({
        where: { id: jobOpportunityId, tenantId },
        select: { status: true },
      });
      if (closed && closed.status !== 'PUBLISHED') {
        throw new BadRequestException(
          'This job is no longer accepting applications',
        );
      }
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
        credentialSnapshot: (wallet?.documents ?? []) as Prisma.InputJsonValue,
      },
      create: {
        jobOpportunityId,
        therapistId: therapist.id,
        applicantUserId: userId,
        message,
        credentialSnapshot: (wallet?.documents ?? []) as Prisma.InputJsonValue,
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

    const therapistName =
      application.therapist.user.firstName?.trim() || 'A therapist';
    await this.notifyAgencyAdmins(application.jobOpportunity.agencyId, {
      title: 'New job application',
      body: `${therapistName} applied for ${application.jobOpportunity.title}.`,
      data: {
        type: 'JOB_APPLICATION_SUBMITTED',
        jobOpportunityId: application.jobOpportunityId,
      },
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
        statusHistory: {
          orderBy: { createdAt: 'desc' },
          take: 5,
          include: {
            changedBy: { select: { firstName: true, lastName: true } },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async approveApplicationCredentials(
    userId: string,
    tenantId: string,
    applicationId: string,
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
    if (application.status !== 'CREDENTIAL_REVIEW') {
      throw new BadRequestException(
        'Application is not awaiting credential review',
      );
    }

    return this.updateApplicationStatus(
      userId,
      tenantId,
      applicationId,
      'UNDER_REVIEW',
      note ?? 'Credentials verified',
    );
  }

  async sendJobOffer(
    userId: string,
    tenantId: string,
    input: {
      applicationId: string;
      compensationRate?: string;
      startDate?: Date;
      message?: string;
    },
  ) {
    const agency = await this.resolveAgencyForAdmin(userId, tenantId);
    const application = await this.prisma.jobOpportunityApplication.findFirst({
      where: {
        id: input.applicationId,
        jobOpportunity: { agencyId: agency.id },
      },
      include: {
        therapist: { include: { user: true } },
        jobOpportunity: true,
        interview: true,
      },
    });
    if (!application) {
      throw new NotFoundException('Application not found');
    }

    const offerReady =
      ['INTERVIEW_REQUESTED', 'UNDER_REVIEW', 'CREDENTIAL_REVIEW'].includes(
        application.status,
      ) || application.interview?.status === 'COMPLETED';
    if (!offerReady) {
      throw new BadRequestException(
        'Complete the interview or credential review before sending an offer',
      );
    }
    if (
      application.status === 'OFFER_SENT' ||
      application.status === 'APPROVED'
    ) {
      throw new BadRequestException('An offer has already been sent');
    }

    const note = this.formatJobOfferNote(input);
    const updated = await this.prisma.$transaction(async (tx) => {
      const row = await tx.jobOpportunityApplication.update({
        where: { id: input.applicationId },
        data: { status: 'OFFER_SENT' },
        include: {
          therapist: { include: { user: true } },
          jobOpportunity: true,
          statusHistory: {
            orderBy: { createdAt: 'desc' },
            take: 5,
            include: {
              changedBy: { select: { firstName: true, lastName: true } },
            },
          },
        },
      });
      await tx.applicationStatusHistory.create({
        data: {
          applicationId: input.applicationId,
          fromStatus: application.status,
          toStatus: 'OFFER_SENT',
          changedByUserId: userId,
          note,
        },
      });
      return row;
    });

    await this.logAudit(tenantId, {
      eventType: JOB_MARKETPLACE_EVENT_TYPES.JOB_OFFER_SENT,
      entityType: 'JobOpportunityApplication',
      entityId: input.applicationId,
      actorUserId: userId,
      metadata: {
        compensationRate: input.compensationRate,
        startDate: input.startDate?.toISOString(),
      },
    });

    const offerPreview =
      note.split('\n\n')[0] ?? 'Review offer details in the app';
    await this.notifications.createForUser(updated.therapist.userId, {
      title: 'Job offer received',
      body: `${agency.name} sent you an offer for ${updated.jobOpportunity.title}. ${offerPreview}.`,
      data: {
        type: 'JOB_OFFER_SENT',
        jobOpportunityId: updated.jobOpportunityId,
      },
    });

    return updated;
  }

  async agencyHiringPipelineSummary(userId: string, tenantId: string) {
    const agency = await this.resolveAgencyForAdmin(userId, tenantId);
    const applications = await this.prisma.jobOpportunityApplication.findMany({
      where: { jobOpportunity: { agencyId: agency.id } },
      select: { status: true, credentialSnapshot: true },
    });

    let newApplicants = 0;
    let credentialReview = 0;
    let credentialsSubmitted = 0;
    let offersPending = 0;
    let readyToHire = 0;

    for (const application of applications) {
      switch (application.status) {
        case 'NEW_APPLICANT':
          newApplicants++;
          break;
        case 'CREDENTIAL_REVIEW':
          credentialReview++;
          if (
            this.parseCredentialDocuments(application.credentialSnapshot)
              .length > 0
          ) {
            credentialsSubmitted++;
          }
          break;
        case 'OFFER_SENT':
          offersPending++;
          break;
        case 'APPROVED':
          readyToHire++;
          break;
        default:
          break;
      }
    }

    return {
      newApplicants,
      credentialReview,
      credentialsSubmitted,
      offersPending,
      readyToHire,
      totalPendingActions: newApplicants + credentialsSubmitted + readyToHire,
    };
  }

  async agencyPendingActionsByJob(userId: string, tenantId: string) {
    const agency = await this.resolveAgencyForAdmin(userId, tenantId);
    const applications = await this.prisma.jobOpportunityApplication.findMany({
      where: { jobOpportunity: { agencyId: agency.id } },
      select: {
        jobOpportunityId: true,
        status: true,
        credentialSnapshot: true,
      },
    });

    const counts: Record<string, number> = {};
    for (const application of applications) {
      if (
        !this.applicationNeedsAgencyAction(
          application.status,
          application.credentialSnapshot,
        )
      ) {
        continue;
      }
      counts[application.jobOpportunityId] =
        (counts[application.jobOpportunityId] ?? 0) + 1;
    }
    return counts;
  }

  private applicationNeedsAgencyAction(
    status: JobApplicationStatus,
    credentialSnapshot: unknown,
  ) {
    if (status === 'NEW_APPLICANT' || status === 'APPROVED') return true;
    if (status === 'CREDENTIAL_REVIEW') {
      return this.parseCredentialDocuments(credentialSnapshot).length > 0;
    }
    return false;
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

    if (updated.therapist.userId !== userId) {
      await this.notifications.createForUser(updated.therapist.userId, {
        title: 'Application status updated',
        body: `Your application for ${updated.jobOpportunity.title} is now ${status.replace(/_/g, ' ').toLowerCase()}.`,
        data: {
          type: 'JOB_APPLICATION_STATUS_CHANGED',
          jobOpportunityId: updated.jobOpportunityId,
        },
      });
    }

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

  async syncTherapistCredentialWallet(userId: string, tenantId: string) {
    const therapist = await this.requireTherapist(userId, tenantId);
    const documents = await this.loadTherapistCredentialDocuments(therapist.id);

    await this.prisma.therapistCredentialWallet.upsert({
      where: { therapistId: therapist.id },
      create: {
        therapistId: therapist.id,
        documents: documents as Prisma.InputJsonValue,
      },
      update: {
        documents: documents as Prisma.InputJsonValue,
      },
    });

    return documents;
  }

  async refreshJobApplicationCredentials(
    userId: string,
    tenantId: string,
    applicationId: string,
  ) {
    const therapist = await this.requireTherapist(userId, tenantId);
    const application = await this.prisma.jobOpportunityApplication.findFirst({
      where: { id: applicationId, therapistId: therapist.id },
      include: {
        therapist: { include: { user: true } },
        jobOpportunity: { include: { agency: true } },
      },
    });
    if (!application) {
      throw new NotFoundException('Application not found');
    }
    if (
      !['CREDENTIAL_REVIEW', 'UNDER_REVIEW', 'INTERVIEW_REQUESTED'].includes(
        application.status,
      )
    ) {
      throw new BadRequestException(
        'Credentials can only be refreshed while the application is under review',
      );
    }

    const documents = await this.syncTherapistCredentialWallet(
      userId,
      tenantId,
    );
    const updated = await this.prisma.jobOpportunityApplication.update({
      where: { id: applicationId },
      data: {
        credentialSnapshot: documents as Prisma.InputJsonValue,
      },
      include: {
        therapist: { include: { user: true } },
        jobOpportunity: { include: { agency: true } },
      },
    });

    await this.logAudit(tenantId, {
      eventType:
        JOB_MARKETPLACE_EVENT_TYPES.JOB_APPLICATION_CREDENTIALS_UPDATED,
      entityType: 'JobOpportunityApplication',
      entityId: applicationId,
      actorUserId: userId,
      metadata: {
        documentCount: documents.length,
        jobOpportunityId: application.jobOpportunityId,
      },
    });

    const therapistName =
      `${updated.therapist.user.firstName} ${updated.therapist.user.lastName}`.trim();
    await this.notifyAgencyAdmins(updated.jobOpportunity.agencyId, {
      title: 'Credentials updated',
      body: `${therapistName} submitted updated credentials for ${updated.jobOpportunity.title}.`,
      data: {
        type: 'JOB_APPLICATION_CREDENTIALS_UPDATED',
        jobOpportunityId: updated.jobOpportunityId,
      },
    });

    return updated;
  }

  async respondToJobOffer(
    userId: string,
    tenantId: string,
    applicationId: string,
    accept: boolean,
    note?: string,
  ) {
    const therapist = await this.requireTherapist(userId, tenantId);
    const application = await this.prisma.jobOpportunityApplication.findFirst({
      where: { id: applicationId, therapistId: therapist.id },
      include: {
        therapist: { include: { user: true } },
        jobOpportunity: { include: { agency: true } },
      },
    });
    if (!application) {
      throw new NotFoundException('Application not found');
    }
    if (application.status !== 'OFFER_SENT') {
      throw new BadRequestException('No pending offer for this application');
    }

    const nextStatus: JobApplicationStatus = accept ? 'APPROVED' : 'WITHDRAWN';
    const updated = await this.prisma.$transaction(async (tx) => {
      const row = await tx.jobOpportunityApplication.update({
        where: { id: applicationId },
        data: { status: nextStatus },
        include: {
          therapist: { include: { user: true } },
          jobOpportunity: { include: { agency: true } },
        },
      });
      await tx.applicationStatusHistory.create({
        data: {
          applicationId,
          fromStatus: application.status,
          toStatus: nextStatus,
          changedByUserId: userId,
          note:
            note ??
            (accept
              ? 'Therapist accepted the offer'
              : 'Therapist declined the offer'),
        },
      });
      return row;
    });

    await this.logAudit(tenantId, {
      eventType: accept
        ? JOB_MARKETPLACE_EVENT_TYPES.JOB_OFFER_ACCEPTED
        : JOB_MARKETPLACE_EVENT_TYPES.JOB_OFFER_DECLINED,
      entityType: 'JobOpportunityApplication',
      entityId: applicationId,
      actorUserId: userId,
    });

    const therapistName =
      `${updated.therapist.user.firstName} ${updated.therapist.user.lastName}`.trim();
    await this.notifyAgencyAdmins(updated.jobOpportunity.agencyId, {
      title: accept ? 'Offer accepted' : 'Offer declined',
      body: accept
        ? `${therapistName} accepted your offer for ${updated.jobOpportunity.title}.`
        : `${therapistName} declined your offer for ${updated.jobOpportunity.title}.`,
      data: {
        type: accept ? 'JOB_OFFER_ACCEPTED' : 'JOB_OFFER_DECLINED',
        jobOpportunityId: updated.jobOpportunityId,
      },
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

    await this.notifications.createForUser(updated.therapist.userId, {
      title: 'Welcome to the team',
      body: `You are hired for ${updated.jobOpportunity.title}. The agency will finalize onboarding.`,
      data: {
        type: 'THERAPIST_HIRED_CONTRACTED',
        jobOpportunityId: updated.jobOpportunityId,
      },
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
        hireOnboarding: defaultHireOnboardingState() as Prisma.InputJsonValue,
      },
      create: {
        agencyId: agency.id,
        therapistId: application.therapistId,
        status: 'ACTIVE',
        joinedAt: new Date(),
        hireOnboarding: defaultHireOnboardingState() as Prisma.InputJsonValue,
      },
      include: { therapist: { include: { user: true } } },
    });

    await this.prisma.childServiceNeed.update({
      where: { id: application.jobOpportunity.childServiceNeedId },
      data: { status: 'FILLED' },
    });

    await this.prisma.jobOpportunity.update({
      where: { id: application.jobOpportunityId },
      data: { status: 'CLOSED' },
    });

    await this.logAudit(tenantId, {
      eventType: JOB_MARKETPLACE_EVENT_TYPES.JOB_OPPORTUNITY_CLOSED,
      entityType: 'JobOpportunity',
      entityId: application.jobOpportunityId,
      actorUserId: userId,
      metadata: { applicationId, reason: 'Position filled' },
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

  async openApplicationCredentialFile(
    userId: string,
    tenantId: string,
    applicationId: string,
    documentId: string,
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
    const allowed = this.parseCredentialDocuments(
      application.credentialSnapshot,
    ).some((doc) => doc.id === documentId);
    if (!allowed) {
      throw new ForbiddenException(
        'Document is not part of this application credential snapshot',
      );
    }
    return this.documents.openFileStreamWithAudit(userId, documentId);
  }

  async listAgencyHireOnboardings(userId: string, tenantId: string) {
    const agency = await this.resolveAgencyForAdmin(userId, tenantId);
    const links = await this.prisma.agencyTherapist.findMany({
      where: {
        agencyId: agency.id,
        status: 'ACTIVE',
        hireOnboarding: { not: Prisma.DbNull },
      },
      include: {
        agency: true,
        therapist: { include: { user: true } },
      },
      orderBy: { joinedAt: 'desc' },
      take: 100,
    });
    return links
      .map((link) => this.mapHireOnboardingRow(link))
      .filter((row) => !row.isComplete);
  }

  async listMyHireOnboardings(userId: string, tenantId: string) {
    const therapist = await this.prisma.therapist.findFirst({
      where: { userId, tenantId },
    });
    if (!therapist) {
      throw new NotFoundException('Therapist profile not found');
    }
    const links = await this.prisma.agencyTherapist.findMany({
      where: {
        therapistId: therapist.id,
        status: 'ACTIVE',
        hireOnboarding: { not: Prisma.DbNull },
      },
      include: {
        agency: true,
        therapist: { include: { user: true } },
      },
      orderBy: { joinedAt: 'desc' },
      take: 20,
    });
    return links
      .map((link) => this.mapHireOnboardingRow(link))
      .filter((row) => !row.isComplete);
  }

  async updateHireOnboardingStep(
    userId: string,
    tenantId: string,
    input: {
      agencyTherapistLinkId: string;
      step: HireOnboardingStepKey;
      complete: boolean;
    },
    role: 'AGENCY_ADMIN' | 'THERAPIST',
  ) {
    const link = await this.prisma.agencyTherapist.findFirst({
      where: { id: input.agencyTherapistLinkId },
      include: {
        agency: true,
        therapist: { include: { user: true } },
      },
    });
    if (!link) {
      throw new NotFoundException('Agency roster link not found');
    }
    if (role === 'AGENCY_ADMIN') {
      const agency = await this.resolveAgencyForAdmin(userId, tenantId);
      if (link.agencyId !== agency.id) {
        throw new ForbiddenException('Not authorized for this roster link');
      }
      if (!canAgencyUpdateStep(input.step)) {
        throw new BadRequestException(
          'Agency cannot update this onboarding step',
        );
      }
    } else {
      const therapist = await this.prisma.therapist.findFirst({
        where: { userId, tenantId },
      });
      if (!therapist || link.therapistId !== therapist.id) {
        throw new ForbiddenException('Not authorized for this roster link');
      }
      if (!canTherapistUpdateStep(input.step)) {
        throw new BadRequestException(
          'Therapist cannot update this onboarding step',
        );
      }
    }

    const state = parseHireOnboardingState(link.hireOnboarding);
    const next = applyHireOnboardingStep(
      state,
      input.step,
      input.complete,
      userId,
    );
    const updated = await this.prisma.agencyTherapist.update({
      where: { id: link.id },
      data: { hireOnboarding: next as Prisma.InputJsonValue },
      include: {
        agency: true,
        therapist: { include: { user: true } },
      },
    });
    return this.mapHireOnboardingRow(updated);
  }

  private mapHireOnboardingRow(link: {
    id: string;
    therapistId: string;
    hireOnboarding: unknown;
    agency: { id: string; name: string };
    therapist: {
      user: { firstName: string; lastName: string };
    };
  }) {
    const view = buildHireOnboardingView(
      parseHireOnboardingState(link.hireOnboarding),
    );
    const therapistName = `${link.therapist.user.firstName} ${link.therapist.user.lastName}`;
    return {
      agencyTherapistLinkId: link.id,
      therapistId: link.therapistId,
      therapistName,
      agencyId: link.agency.id,
      agencyName: link.agency.name,
      ...view,
    };
  }

  async scheduleFirstSessionFromHire(
    userId: string,
    tenantId: string,
    input: {
      applicationId: string;
      scheduledStart: Date;
      durationMinutes?: number;
      notes?: string;
    },
  ) {
    const agency = await this.resolveAgencyForAdmin(userId, tenantId);
    const application = await this.prisma.jobOpportunityApplication.findFirst({
      where: {
        id: input.applicationId,
        status: 'HIRED_CONTRACTED',
        jobOpportunity: { agencyId: agency.id },
      },
      include: {
        therapist: { include: { user: true } },
        jobOpportunity: {
          include: {
            childServiceNeed: {
              include: { child: { include: { parent: true } } },
            },
          },
        },
      },
    });
    if (!application) {
      throw new BadRequestException(
        'Application must be hired before scheduling the first session',
      );
    }
    if (input.scheduledStart <= new Date()) {
      throw new BadRequestException('Session must be scheduled in the future');
    }

    const need = application.jobOpportunity.childServiceNeed;
    const child = need.child;
    const durationMinutes = input.durationMinutes ?? 60;
    const scheduledEnd = new Date(
      input.scheduledStart.getTime() + durationMinutes * 60 * 1000,
    );
    const therapyType = this.mapJobServiceToTherapyType(
      application.jobOpportunity.serviceType,
    );
    const locationType = this.mapJobModalityToLocationType(
      application.jobOpportunity.locationModality,
    );

    const appointment = await this.prisma.appointment.create({
      data: {
        tenantId,
        agencyId: agency.id,
        childId: child.id,
        parentId: child.parentId,
        therapistId: application.therapistId,
        therapyType,
        scheduledStart: input.scheduledStart,
        scheduledEnd,
        locationType,
        status: 'CONFIRMED',
        confirmationStatus: 'CONFIRMED',
        parentConfirmedAt: new Date(),
        therapistConfirmedAt: new Date(),
        notes:
          input.notes ??
          `First session after hire for ${application.jobOpportunity.title}`,
      },
    });

    await this.logAudit(tenantId, {
      eventType: JOB_MARKETPLACE_EVENT_TYPES.FIRST_SESSION_SCHEDULED_FROM_HIRE,
      entityType: 'Appointment',
      entityId: appointment.id,
      actorUserId: userId,
      metadata: {
        applicationId: application.id,
        jobOpportunityId: application.jobOpportunityId,
        therapistId: application.therapistId,
        childId: child.id,
      },
    });

    const childLabel = `${child.firstName} ${child.lastName.charAt(0)}.`;
    await this.notifications.createForUser(application.therapist.userId, {
      title: 'First session scheduled',
      body: `Your first session with ${childLabel} is scheduled for ${input.scheduledStart.toLocaleString('en-US', { weekday: 'short', month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' })}.`,
      data: {
        type: 'FIRST_SESSION_SCHEDULED',
        appointmentId: appointment.id,
        jobOpportunityId: application.jobOpportunityId,
      },
    });

    if (child.parent?.userId) {
      await this.notifications.createForUser(child.parent.userId, {
        title: 'Therapist assigned',
        body: `${application.therapist.user.firstName} ${application.therapist.user.lastName} will see ${child.firstName} on ${input.scheduledStart.toLocaleString('en-US', { weekday: 'short', month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' })}.`,
        data: {
          type: 'APPOINTMENT_SCHEDULED',
          appointmentId: appointment.id,
        },
      });
    }

    const rosterLink = await this.prisma.agencyTherapist.findUnique({
      where: {
        agencyId_therapistId: {
          agencyId: agency.id,
          therapistId: application.therapistId,
        },
      },
    });
    if (rosterLink) {
      const state = parseHireOnboardingState(rosterLink.hireOnboarding);
      await this.prisma.agencyTherapist.update({
        where: { id: rosterLink.id },
        data: {
          hireOnboarding: markFirstSessionScheduled(
            state,
            userId,
          ) as Prisma.InputJsonValue,
        },
      });
    }

    return {
      appointmentId: appointment.id,
      childId: child.id,
      therapistId: application.therapistId,
      scheduledStart: appointment.scheduledStart,
      scheduledEnd: appointment.scheduledEnd,
    };
  }

  async rescheduleJobInterview(
    userId: string,
    tenantId: string,
    input: {
      interviewId: string;
      scheduledAt: Date;
      durationMinutes?: number;
      notes?: string;
    },
  ) {
    const agency = await this.resolveAgencyForAdmin(userId, tenantId);
    const interview = await this.prisma.jobInterview.findFirst({
      where: { id: input.interviewId, agencyId: agency.id },
      include: {
        application: {
          include: {
            jobOpportunity: true,
            therapist: { include: { user: true } },
          },
        },
        agency: true,
      },
    });
    if (!interview) {
      throw new NotFoundException('Interview not found');
    }
    if (!['SCHEDULED', 'CONFIRMED'].includes(interview.status)) {
      throw new BadRequestException(
        'Only active interviews can be rescheduled',
      );
    }
    if (input.scheduledAt <= new Date()) {
      throw new BadRequestException(
        'Interview must be scheduled in the future',
      );
    }

    const interviewStatus =
      interview.recordingRequested && interview.agencyRecordingConsent
        ? 'CONFIRMED'
        : 'SCHEDULED';

    const updated = await this.prisma.jobInterview.update({
      where: { id: input.interviewId },
      data: {
        scheduledAt: input.scheduledAt,
        durationMinutes: input.durationMinutes ?? interview.durationMinutes,
        notes: input.notes ?? interview.notes,
        status: interviewStatus,
        therapistRecordingConsent: interview.recordingRequested
          ? false
          : interview.therapistRecordingConsent,
      },
      include: {
        application: {
          include: {
            jobOpportunity: true,
            therapist: { include: { user: true } },
          },
        },
        agency: true,
        scheduledBy: true,
        therapistUser: true,
        callSession: true,
      },
    });

    await this.logAudit(tenantId, {
      eventType: JOB_MARKETPLACE_EVENT_TYPES.JOB_INTERVIEW_RESCHEDULED,
      entityType: 'JobInterview',
      entityId: interview.id,
      actorUserId: userId,
      metadata: { scheduledAt: input.scheduledAt.toISOString() },
    });

    await this.notifications.createForUser(interview.therapistUserId, {
      title: 'Interview rescheduled',
      body: `Your interview for ${interview.application.jobOpportunity.title} was moved to ${input.scheduledAt.toLocaleString('en-US', { weekday: 'short', month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' })}.`,
      data: {
        type: 'JOB_INTERVIEW_SCHEDULED',
        interviewId: interview.id,
        jobOpportunityId: interview.application.jobOpportunityId,
      },
    });

    return updated;
  }

  async completeJobInterviewManually(
    userId: string,
    tenantId: string,
    interviewId: string,
    note?: string,
  ) {
    const agency = await this.resolveAgencyForAdmin(userId, tenantId);
    const interview = await this.prisma.jobInterview.findFirst({
      where: { id: interviewId, agencyId: agency.id },
      include: {
        application: { include: { jobOpportunity: true } },
      },
    });
    if (!interview) {
      throw new NotFoundException('Interview not found');
    }
    if (interview.status === 'COMPLETED' || interview.status === 'CANCELLED') {
      throw new BadRequestException('Interview is already finished');
    }

    const updated = await this.prisma.jobInterview.update({
      where: { id: interviewId },
      data: {
        status: 'COMPLETED',
        notes: note
          ? [interview.notes, note].filter(Boolean).join('\n\n')
          : interview.notes,
      },
      include: {
        application: {
          include: {
            jobOpportunity: true,
            therapist: { include: { user: true } },
          },
        },
        agency: true,
        scheduledBy: true,
        therapistUser: true,
        callSession: true,
      },
    });

    await this.logAudit(tenantId, {
      eventType: JOB_MARKETPLACE_EVENT_TYPES.JOB_INTERVIEW_COMPLETED,
      entityType: 'JobInterview',
      entityId: interviewId,
      actorUserId: userId,
      metadata: { manual: true, note },
    });

    return updated;
  }

  async scheduleJobInterview(
    userId: string,
    tenantId: string,
    input: {
      applicationId: string;
      scheduledAt: Date;
      durationMinutes?: number;
      recordingRequested?: boolean;
      agencyRecordingConsent?: boolean;
      notes?: string;
    },
  ) {
    const agency = await this.resolveAgencyForAdmin(userId, tenantId);
    const application = await this.prisma.jobOpportunityApplication.findFirst({
      where: {
        id: input.applicationId,
        jobOpportunity: { agencyId: agency.id },
      },
      include: {
        therapist: { include: { user: true } },
        jobOpportunity: true,
        interview: true,
      },
    });
    if (!application) {
      throw new NotFoundException('Application not found');
    }
    if (application.interview && application.interview.status !== 'CANCELLED') {
      throw new BadRequestException(
        'An interview is already scheduled for this application',
      );
    }
    if (input.scheduledAt <= new Date()) {
      throw new BadRequestException(
        'Interview must be scheduled in the future',
      );
    }

    const recordingRequested = input.recordingRequested === true;
    const agencyRecordingConsent =
      recordingRequested && input.agencyRecordingConsent === true;
    const interviewStatus =
      recordingRequested && agencyRecordingConsent ? 'CONFIRMED' : 'SCHEDULED';

    const interview = await this.prisma.$transaction(async (tx) => {
      const row = application.interview
        ? await tx.jobInterview.update({
            where: { id: application.interview.id },
            data: {
              scheduledAt: input.scheduledAt,
              durationMinutes: input.durationMinutes ?? 30,
              recordingRequested,
              agencyRecordingConsent,
              therapistRecordingConsent: false,
              notes: input.notes,
              status: interviewStatus,
              scheduledByUserId: userId,
            },
            include: {
              application: {
                include: {
                  jobOpportunity: true,
                  therapist: { include: { user: true } },
                },
              },
              agency: true,
              scheduledBy: true,
              therapistUser: true,
            },
          })
        : await tx.jobInterview.create({
            data: {
              tenantId,
              agencyId: agency.id,
              applicationId: application.id,
              scheduledByUserId: userId,
              therapistUserId: application.therapist.userId,
              scheduledAt: input.scheduledAt,
              durationMinutes: input.durationMinutes ?? 30,
              recordingRequested,
              agencyRecordingConsent,
              notes: input.notes,
              status: interviewStatus,
            },
            include: {
              application: {
                include: {
                  jobOpportunity: true,
                  therapist: { include: { user: true } },
                },
              },
              agency: true,
              scheduledBy: true,
              therapistUser: true,
            },
          });

      if (application.status !== 'INTERVIEW_REQUESTED') {
        await tx.jobOpportunityApplication.update({
          where: { id: application.id },
          data: { status: 'INTERVIEW_REQUESTED' },
        });
        await tx.applicationStatusHistory.create({
          data: {
            applicationId: application.id,
            fromStatus: application.status,
            toStatus: 'INTERVIEW_REQUESTED',
            changedByUserId: userId,
            note: 'Video interview scheduled',
          },
        });
      }

      return row;
    });

    await this.logAudit(tenantId, {
      eventType: JOB_MARKETPLACE_EVENT_TYPES.JOB_INTERVIEW_SCHEDULED,
      entityType: 'JobInterview',
      entityId: interview.id,
      actorUserId: userId,
      metadata: {
        applicationId: application.id,
        scheduledAt: input.scheduledAt.toISOString(),
        recordingRequested,
      },
    });

    await this.notifications.createForUser(application.therapist.userId, {
      title: 'Interview scheduled',
      body: `${agency.name} scheduled a video interview for ${application.jobOpportunity.title}.`,
      data: {
        type: 'JOB_INTERVIEW_SCHEDULED',
        interviewId: interview.id,
        jobOpportunityId: application.jobOpportunityId,
        applicationId: application.id,
      },
    });

    await this.notifyInterviewStartingSoon(interview, agency.name);

    return interview;
  }

  private async notifyInterviewStartingSoon(
    interview: {
      id: string;
      scheduledAt: Date;
      therapistUserId: string;
      scheduledByUserId: string;
      application: {
        jobOpportunityId: string;
        jobOpportunity: { title: string };
        therapist?: { user?: { firstName: string; lastName: string } };
      };
    },
    agencyName: string,
  ) {
    const msUntil = interview.scheduledAt.getTime() - Date.now();
    if (msUntil <= 0 || msUntil > 60 * 60 * 1000) return;

    const therapistName = interview.application.therapist?.user
      ? `${interview.application.therapist.user.firstName} ${interview.application.therapist.user.lastName}`
      : 'the applicant';
    const jobTitle = interview.application.jobOpportunity.title;
    const when = interview.scheduledAt.toLocaleString('en-US', {
      hour: 'numeric',
      minute: '2-digit',
    });

    const payload = {
      interviewId: interview.id,
      jobOpportunityId: interview.application.jobOpportunityId,
    };

    await this.notifications.createForUser(interview.therapistUserId, {
      title: 'Interview starting soon',
      body: `Your interview with ${agencyName} for ${jobTitle} starts around ${when}.`,
      data: { type: 'JOB_INTERVIEW_STARTING_SOON', ...payload },
    });
    await this.notifications.createForUser(interview.scheduledByUserId, {
      title: 'Interview starting soon',
      body: `Your interview with ${therapistName} for ${jobTitle} starts around ${when}.`,
      data: { type: 'JOB_INTERVIEW_STARTING_SOON', ...payload },
    });
  }

  async updateJobInterviewNotes(
    userId: string,
    tenantId: string,
    interviewId: string,
    notes: string,
  ) {
    const agency = await this.resolveAgencyForAdmin(userId, tenantId);
    const interview = await this.prisma.jobInterview.findFirst({
      where: { id: interviewId, agencyId: agency.id },
      include: {
        application: {
          include: {
            jobOpportunity: true,
            therapist: { include: { user: true } },
          },
        },
        agency: true,
        scheduledBy: true,
        therapistUser: true,
        callSession: true,
      },
    });
    if (!interview) {
      throw new NotFoundException('Interview not found');
    }

    return this.prisma.jobInterview.update({
      where: { id: interviewId },
      data: { notes: notes.trim() || null },
      include: {
        application: {
          include: {
            jobOpportunity: true,
            therapist: { include: { user: true } },
          },
        },
        agency: true,
        scheduledBy: true,
        therapistUser: true,
        callSession: true,
      },
    });
  }

  async listAgencyJobInterviews(
    userId: string,
    tenantId: string,
    from?: Date,
    to?: Date,
  ) {
    const agency = await this.resolveAgencyForAdmin(userId, tenantId);
    const rangeStart = from ?? new Date();
    const rangeEnd =
      to ?? new Date(rangeStart.getTime() + 30 * 24 * 60 * 60 * 1000);

    const rows = await this.prisma.jobInterview.findMany({
      where: {
        agencyId: agency.id,
        scheduledAt: { gte: rangeStart, lte: rangeEnd },
        status: { not: 'CANCELLED' },
      },
      include: {
        application: {
          include: {
            jobOpportunity: true,
            therapist: { include: { user: true } },
          },
        },
        agency: true,
        scheduledBy: true,
        therapistUser: true,
        callSession: true,
      },
      orderBy: { scheduledAt: 'asc' },
    });

    await Promise.all(
      rows.map((row) =>
        this.maybeSendInterviewDayBeforeReminder({
          id: row.id,
          scheduledAt: row.scheduledAt,
          therapistUserId: row.therapistUserId,
          scheduledByUserId: row.scheduledByUserId,
          status: row.status,
          application: row.application,
          agency: row.agency,
        }),
      ),
    );

    return rows;
  }

  async listTherapistJobInterviews(userId: string, tenantId: string) {
    const therapist = await this.requireTherapist(userId, tenantId);
    const rows = await this.prisma.jobInterview.findMany({
      where: {
        therapistUserId: userId,
        application: { therapistId: therapist.id },
        status: { not: 'CANCELLED' },
        scheduledAt: { gte: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000) },
      },
      include: {
        application: {
          include: { jobOpportunity: { include: { agency: true } } },
        },
        agency: true,
        scheduledBy: true,
        callSession: true,
      },
      orderBy: { scheduledAt: 'asc' },
    });

    await Promise.all(
      rows.map((row) =>
        this.maybeSendInterviewDayBeforeReminder({
          id: row.id,
          scheduledAt: row.scheduledAt,
          therapistUserId: row.therapistUserId,
          scheduledByUserId: row.scheduledByUserId,
          status: row.status,
          application: row.application,
          agency: row.agency,
        }),
      ),
    );

    return rows;
  }

  async grantJobInterviewRecordingConsent(
    userId: string,
    tenantId: string,
    interviewId: string,
    consent: boolean,
  ) {
    const interview = await this.prisma.jobInterview.findFirst({
      where: { id: interviewId, tenantId },
      include: {
        application: { include: { jobOpportunity: true } },
        agency: true,
      },
    });
    if (!interview) {
      throw new NotFoundException('Interview not found');
    }
    if (!interview.recordingRequested) {
      throw new BadRequestException(
        'Recording was not requested for this interview',
      );
    }

    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');

    const isAgencyAdmin =
      user.role === 'AGENCY_ADMIN' && user.agencyId === interview.agencyId;
    const isTherapist = userId === interview.therapistUserId;
    if (!isAgencyAdmin && !isTherapist) {
      throw new ForbiddenException('Not authorized');
    }

    const data = isAgencyAdmin
      ? { agencyRecordingConsent: consent }
      : { therapistRecordingConsent: consent };

    const updated = await this.prisma.jobInterview.update({
      where: { id: interviewId },
      data,
      include: {
        application: {
          include: {
            jobOpportunity: true,
            therapist: { include: { user: true } },
          },
        },
        agency: true,
        scheduledBy: true,
        therapistUser: true,
        callSession: true,
      },
    });

    const otherUserId = isAgencyAdmin
      ? interview.therapistUserId
      : interview.scheduledByUserId;

    await this.logAudit(tenantId, {
      eventType: JOB_MARKETPLACE_EVENT_TYPES.JOB_INTERVIEW_RECORDING_CONSENT,
      entityType: 'JobInterview',
      entityId: interviewId,
      actorUserId: userId,
      metadata: { consent, role: isAgencyAdmin ? 'AGENCY_ADMIN' : 'THERAPIST' },
    });

    if (otherUserId !== userId) {
      await this.notifications.createForUser(otherUserId, {
        title: consent
          ? 'Recording consent granted'
          : 'Recording consent declined',
        body: `${user.firstName} ${user.lastName} ${consent ? 'agreed to' : 'declined'} interview recording for ${interview.application.jobOpportunity.title}.`,
        data: {
          type: 'JOB_INTERVIEW_RECORDING_CONSENT',
          interviewId,
          jobOpportunityId: interview.application.jobOpportunityId,
        },
      });
    }

    return updated;
  }

  async cancelJobInterview(
    userId: string,
    tenantId: string,
    interviewId: string,
    reason?: string,
  ) {
    const agency = await this.resolveAgencyForAdmin(userId, tenantId);
    const interview = await this.prisma.jobInterview.findFirst({
      where: { id: interviewId, agencyId: agency.id },
      include: {
        application: { include: { jobOpportunity: true } },
        callSession: true,
      },
    });
    if (!interview) {
      throw new NotFoundException('Interview not found');
    }
    if (interview.status === 'COMPLETED' || interview.status === 'CANCELLED') {
      throw new BadRequestException('Interview cannot be cancelled');
    }

    const updated = await this.prisma.jobInterview.update({
      where: { id: interviewId },
      data: { status: 'CANCELLED', notes: reason ?? interview.notes },
      include: {
        application: {
          include: {
            jobOpportunity: true,
            therapist: { include: { user: true } },
          },
        },
        agency: true,
        scheduledBy: true,
        therapistUser: true,
        callSession: true,
      },
    });

    await this.logAudit(tenantId, {
      eventType: JOB_MARKETPLACE_EVENT_TYPES.JOB_INTERVIEW_CANCELLED,
      entityType: 'JobInterview',
      entityId: interviewId,
      actorUserId: userId,
      metadata: { reason },
    });

    await this.notifications.createForUser(interview.therapistUserId, {
      title: 'Interview cancelled',
      body: `Your interview for ${interview.application.jobOpportunity.title} was cancelled.`,
      data: {
        type: 'JOB_INTERVIEW_CANCELLED',
        interviewId,
        jobOpportunityId: interview.application.jobOpportunityId,
      },
    });

    return updated;
  }

  async joinJobInterview(
    userId: string,
    tenantId: string,
    interviewId: string,
    ctx: { ipAddress?: string; userAgent?: string; deviceType?: string },
  ) {
    const interview = await this.prisma.jobInterview.findFirst({
      where: { id: interviewId, tenantId },
    });
    if (!interview) {
      throw new NotFoundException('Interview not found');
    }
    return this.calls.joinJobInterviewCall(userId, interviewId, ctx);
  }

  async getJobInterviewForApplication(
    userId: string,
    tenantId: string,
    applicationId: string,
  ) {
    const agency = await this.resolveAgencyForAdmin(userId, tenantId);
    return this.prisma.jobInterview.findFirst({
      where: {
        applicationId,
        agencyId: agency.id,
        status: { not: 'CANCELLED' },
      },
      include: {
        application: {
          include: {
            jobOpportunity: true,
            therapist: { include: { user: true } },
          },
        },
        agency: true,
        scheduledBy: true,
        therapistUser: true,
        callSession: true,
      },
    });
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
        statusHistory: {
          orderBy: { createdAt: 'desc' },
          take: 5,
          include: {
            changedBy: { select: { firstName: true, lastName: true } },
          },
        },
      },
      orderBy: { updatedAt: 'desc' },
    });
  }

  async inviteTherapistToApply(
    userId: string,
    tenantId: string,
    jobOpportunityId: string,
    therapistId: string,
  ) {
    const agency = await this.resolveAgencyForAdmin(userId, tenantId);
    const job = await this.requireAgencyJobOpportunity(
      agency.id,
      jobOpportunityId,
    );

    const therapist = await this.prisma.therapist.findFirst({
      where: { id: therapistId, tenantId },
      include: {
        agencyLinks: { where: { agencyId: agency.id } },
        user: { select: { id: true } },
      },
    });
    if (!therapist) {
      throw new NotFoundException('Therapist not found in tenant');
    }

    const onRoster = therapist.agencyLinks.length > 0;
    const verifiedInTenant = therapist.isVerified;
    if (!onRoster && !verifiedInTenant) {
      throw new BadRequestException(
        'Therapist must be on agency roster or verified in tenant',
      );
    }

    const invite = await this.prisma.agencyInviteToApply.upsert({
      where: {
        jobOpportunityId_therapistId: {
          jobOpportunityId,
          therapistId,
        },
      },
      create: {
        jobOpportunityId,
        therapistId,
        invitedByUserId: userId,
      },
      update: {
        invitedByUserId: userId,
      },
      include: {
        jobOpportunity: { include: { agency: true } },
      },
    });

    await this.logAudit(tenantId, {
      eventType: JOB_MARKETPLACE_EVENT_TYPES.THERAPIST_INVITED_TO_APPLY,
      entityType: 'AgencyInviteToApply',
      entityId: invite.id,
      actorUserId: userId,
      metadata: {
        jobOpportunityId,
        therapistId,
        agencyId: agency.id,
        jobTitle: job.title,
      },
    });

    await this.notifications.createForUser(therapist.userId, {
      title: 'Agency invited you to apply',
      body: `${agency.name} invited you to apply for ${job.title}.`,
      data: {
        type: 'JOB_INVITE_TO_APPLY',
        jobOpportunityId,
      },
    });

    return invite;
  }

  async listJobInvitesForTherapist(userId: string, tenantId: string) {
    const therapist = await this.requireTherapist(userId, tenantId);
    const invites = await this.prisma.agencyInviteToApply.findMany({
      where: { therapistId: therapist.id },
      include: {
        jobOpportunity: { include: { agency: true } },
      },
      orderBy: { createdAt: 'desc' },
    });

    return invites.map((invite) => ({
      id: invite.id,
      jobOpportunityId: invite.jobOpportunityId,
      jobTitle: invite.jobOpportunity.title,
      agencyName: invite.jobOpportunity.agency.name,
      invitedAt: invite.createdAt,
    }));
  }

  async listSavedJobOpportunities(userId: string, tenantId: string) {
    const therapist = await this.requireTherapist(userId, tenantId);
    const saved = await this.prisma.savedJobOpportunity.findMany({
      where: {
        therapistId: therapist.id,
        jobOpportunity: { status: 'PUBLISHED' },
      },
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
        statusHistory: {
          orderBy: { createdAt: 'desc' },
          take: 5,
          include: {
            changedBy: { select: { firstName: true, lastName: true } },
          },
        },
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

  private async notifyAgencyAdmins(
    agencyId: string,
    notification: {
      title: string;
      body: string;
      data: Record<string, unknown>;
    },
  ) {
    const admins = await this.prisma.user.findMany({
      where: { agencyId, role: 'AGENCY_ADMIN', isActive: true },
      select: { id: true },
    });
    await Promise.all(
      admins.map((admin) =>
        this.notifications.createForUser(admin.id, notification),
      ),
    );
  }

  private formatJobOfferNote(input: {
    compensationRate?: string;
    startDate?: Date;
    message?: string;
  }) {
    const parts: string[] = [];
    if (input.compensationRate?.trim()) {
      parts.push(`Compensation: ${input.compensationRate.trim()}`);
    }
    if (input.startDate) {
      parts.push(
        `Start date: ${input.startDate.toLocaleDateString('en-US', {
          month: 'short',
          day: 'numeric',
          year: 'numeric',
        })}`,
      );
    }
    if (input.message?.trim()) {
      parts.push(input.message.trim());
    }
    return parts.join('\n\n') || 'Job offer extended';
  }

  private async maybeSendInterviewDayBeforeReminder(interview: {
    id: string;
    scheduledAt: Date;
    status: string;
    therapistUserId: string;
    scheduledByUserId: string;
    application: {
      jobOpportunityId: string;
      jobOpportunity: { title: string };
      therapist?: { user?: { firstName: string; lastName: string } };
    };
    agency: { name: string };
  }) {
    if (!['SCHEDULED', 'CONFIRMED'].includes(interview.status)) return;

    const msUntil = interview.scheduledAt.getTime() - Date.now();
    if (msUntil <= 60 * 60 * 1000 || msUntil > 24 * 60 * 60 * 1000) return;

    const jobTitle = interview.application.jobOpportunity.title;
    const therapistName = interview.application.therapist?.user
      ? `${interview.application.therapist.user.firstName} ${interview.application.therapist.user.lastName}`
      : 'the applicant';
    const when = interview.scheduledAt.toLocaleString('en-US', {
      weekday: 'short',
      month: 'short',
      day: 'numeric',
      hour: 'numeric',
      minute: '2-digit',
    });
    const payload = {
      interviewId: interview.id,
      jobOpportunityId: interview.application.jobOpportunityId,
    };

    const notifyTherapist = !(await this.interviewReminderAlreadySent(
      interview.id,
      interview.therapistUserId,
    ));
    const notifyAgency = !(await this.interviewReminderAlreadySent(
      interview.id,
      interview.scheduledByUserId,
    ));

    if (notifyTherapist) {
      await this.notifications.createForUser(interview.therapistUserId, {
        title: 'Interview reminder',
        body: `Reminder: your interview with ${interview.agency.name} for ${jobTitle} is on ${when}.`,
        data: { type: 'JOB_INTERVIEW_REMINDER', ...payload },
      });
    }
    if (notifyAgency) {
      await this.notifications.createForUser(interview.scheduledByUserId, {
        title: 'Interview reminder',
        body: `Reminder: your interview with ${therapistName} for ${jobTitle} is on ${when}.`,
        data: { type: 'JOB_INTERVIEW_REMINDER', ...payload },
      });
    }
  }

  private mapJobServiceToTherapyType(serviceType: JobServiceType): TherapyType {
    const map: Record<JobServiceType, TherapyType> = {
      ABA: 'ABA',
      OT: 'OCCUPATIONAL',
      PT: 'PHYSICAL',
      SPEECH: 'SPEECH',
      SPECIAL_INSTRUCTION: 'EARLY_INTERVENTION',
      SOCIAL_WORK: 'EARLY_INTERVENTION',
      PSYCHOLOGY: 'DEVELOPMENTAL_EVALUATION',
      NURSING: 'EARLY_INTERVENTION',
      EVALUATION: 'DEVELOPMENTAL_EVALUATION',
      SERVICE_COORDINATION: 'EARLY_INTERVENTION',
      OTHER: 'EARLY_INTERVENTION',
    };
    return map[serviceType] ?? 'EARLY_INTERVENTION';
  }

  private mapJobModalityToLocationType(
    modality: JobLocationModality,
  ): LocationType {
    if (modality === 'TELEHEALTH') return 'TELEHEALTH';
    if (modality === 'HYBRID') return 'CLINIC';
    return 'IN_HOME';
  }

  private async interviewReminderAlreadySent(
    interviewId: string,
    userId: string,
  ) {
    const rows = await this.prisma.notification.findMany({
      where: {
        userId,
        createdAt: { gte: new Date(Date.now() - 48 * 60 * 60 * 1000) },
      },
      orderBy: { sentAt: 'desc' },
      take: 40,
    });
    return rows.some((row) => {
      const data =
        row.data && typeof row.data === 'object' && !Array.isArray(row.data)
          ? (row.data as Record<string, unknown>)
          : {};
      return (
        data.type === 'JOB_INTERVIEW_REMINDER' &&
        data.interviewId === interviewId
      );
    });
  }

  private async loadTherapistCredentialDocuments(therapistId: string) {
    const documents = await this.prisma.document.findMany({
      where: { therapistId },
      orderBy: { uploadedAt: 'desc' },
      take: 25,
    });
    return documents.map((doc) => ({
      id: doc.id,
      title: doc.title,
      fileName: doc.fileName,
      type: doc.type,
      uploadedAt: doc.uploadedAt.toISOString(),
    }));
  }

  parseCredentialDocuments(snapshot: unknown) {
    if (!Array.isArray(snapshot)) return [];
    return snapshot.flatMap((row) => {
      if (!row || typeof row !== 'object') return [];
      const doc = row as Record<string, unknown>;
      if (typeof doc.id !== 'string' || typeof doc.title !== 'string') {
        return [];
      }
      const uploadedAt =
        typeof doc.uploadedAt === 'string'
          ? new Date(doc.uploadedAt)
          : new Date();
      return [
        {
          id: doc.id,
          title: doc.title,
          fileName: typeof doc.fileName === 'string' ? doc.fileName : doc.title,
          type: typeof doc.type === 'string' ? doc.type : 'OTHER',
          uploadedAt,
        },
      ];
    });
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
