import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { randomInt } from 'crypto';
import {
  MarketplaceAuthorizationStatus,
  MarketplaceConsentType,
  MarketplaceLocationType,
  MarketplaceUrgency,
  Prisma,
} from '../../generated/prisma/client';
import { AuditService } from '../audit/audit.service';
import { PhiAuditService } from '../audit/phi-audit.service';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.service';
import { calculateAgeRange } from './marketplace-age-range.util';
import {
  ANONYMOUS_MARKETPLACE_CONSENT_TEXT,
  MARKETPLACE_CONSENT_VERSION,
  SHARE_IDENTIFIABLE_INFO_CONSENT_TEMPLATE,
} from './marketplace.constants';
import {
  deriveConcernTagsFromScreening,
  mapTherapyTypeToServiceCategory,
  toPublicMarketplaceRequest,
} from './marketplace-privacy.util';
import {
  haversineMiles,
  jitterMapPin,
  zipToApproxCentroid,
} from './marketplace-zip.util';

type RequestContext = {
  ipAddress?: string;
  userAgent?: string;
  deviceInfo?: string;
};

@Injectable()
export class MarketplaceService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly phiAudit: PhiAuditService,
    private readonly notifications: NotificationsService,
  ) {}

  async createMarketplaceRequestForParent(
    userId: string,
    childId: string,
    input: {
      screeningResponseId?: string;
      anonymousConsentGranted: boolean;
      locationType: MarketplaceLocationType;
      preferredSchedule?: Record<string, unknown>;
      languagePreference?: string;
      urgency?: MarketplaceUrgency;
      publicDescription?: string;
    },
    ctx: RequestContext,
  ) {
    if (!input.anonymousConsentGranted) {
      throw new BadRequestException(
        'Explicit anonymous marketplace consent is required before posting.',
      );
    }

    const parent = await this.requireParent(userId);
    const child = await this.requireParentChild(parent.id, childId);

    if (!child.zipCode?.trim()) {
      throw new BadRequestException(
        'ZIP code is required to create an anonymous marketplace request.',
      );
    }

    let screening = null as Awaited<
      ReturnType<typeof this.prisma.screeningResponse.findFirst>
    >;
    if (input.screeningResponseId) {
      screening = await this.prisma.screeningResponse.findFirst({
        where: {
          id: input.screeningResponseId,
          childId: child.id,
          parentId: parent.id,
          isDraft: false,
        },
      });
      if (!screening) {
        throw new NotFoundException('Completed screening not found for child');
      }
      if (!screening.disclaimerAccepted) {
        throw new BadRequestException(
          'Screening disclaimer must be accepted before creating a marketplace request.',
        );
      }
    }

    const ageRange = calculateAgeRange(child.dateOfBirth);
    await this.prisma.child.update({
      where: { id: child.id },
      data: { ageRange },
    });

    const serviceCategories = this.extractServiceCategories(screening);
    const concernTags = this.extractConcernTags(screening);
    const centroid = zipToApproxCentroid(child.zipCode);
    const jitter = jitterMapPin(centroid.lat, centroid.lng, child.id);
    const anonymousPublicId = await this.generateAnonymousPublicId();

    const request = await this.prisma.marketplaceRequest.create({
      data: {
        tenantId: parent.tenantId,
        childId: child.id,
        parentUserId: userId,
        screeningResponseId: screening?.id,
        anonymousPublicId,
        status: 'ACTIVE',
        serviceCategories,
        concernTags,
        ageRange,
        zipCode: child.zipCode.slice(0, 5),
        city: child.city ?? parent.city,
        state: child.state ?? parent.state,
        zipCentroidLat: centroid.lat,
        zipCentroidLng: centroid.lng,
        mapPinJitterLat: jitter.lat,
        mapPinJitterLng: jitter.lng,
        locationType: input.locationType,
        preferredSchedule: (input.preferredSchedule ??
          {}) as Prisma.InputJsonValue,
        languagePreference:
          input.languagePreference ?? child.primaryLanguage ?? undefined,
        authorizationStatus: screening?.evaluationRequestedAt
          ? 'EVALUATION_NEEDED'
          : 'PARENT_SCREENING_ONLY',
        urgency: input.urgency ?? 'ROUTINE',
        publicDescription: input.publicDescription,
      },
    });

    await this.recordConsent({
      tenantId: parent.tenantId,
      parentUserId: userId,
      childId: child.id,
      marketplaceRequestId: request.id,
      consentType: 'ANONYMOUS_MARKETPLACE_POSTING',
      consentText: ANONYMOUS_MARKETPLACE_CONSENT_TEXT,
      ctx,
    });

    await this.audit.log({
      tenantId: parent.tenantId,
      actorId: userId,
      actorRole: 'PARENT',
      action: 'CREATE',
      resourceType: 'MarketplaceRequest',
      resourceId: request.id,
      patientId: child.id,
      ipAddress: ctx.ipAddress,
      userAgent: ctx.userAgent,
      metadata: { anonymousPublicId },
    });

    return request;
  }

  async listParentRequests(userId: string) {
    await this.requireParent(userId);
    const rows = await this.prisma.marketplaceRequest.findMany({
      where: { parentUserId: userId, removedAt: null },
      orderBy: { createdAt: 'desc' },
      include: {
        _count: { select: { interests: true } },
      },
    });
    return rows.map((row) => ({
      ...toPublicMarketplaceRequest(row),
      interestCount: row._count.interests,
      childId: row.childId,
    }));
  }

  async listRequestInterestsForParent(userId: string, requestId: string) {
    await this.requireParentRequest(userId, requestId);
    const interests = await this.prisma.marketplaceInterest.findMany({
      where: { marketplaceRequestId: requestId },
      include: { providerProfile: true },
      orderBy: { createdAt: 'desc' },
    });
    return interests.map((row) => ({
      id: row.id,
      status: row.status,
      message: row.message,
      availability: row.availability,
      createdAt: row.createdAt,
      provider: {
        id: row.providerProfile.id,
        displayName: row.providerProfile.displayName,
        accountType: row.providerProfile.accountType,
        serviceCategories: row.providerProfile.serviceCategories,
        languages: row.providerProfile.languages,
        verifiedStatus: row.providerProfile.verifiedStatus,
      },
    }));
  }

  async browsePublicRequestsForProvider(
    userId: string,
    filters: {
      zipCode?: string;
      radiusMiles?: number;
      serviceCategory?: string;
      ageRange?: string;
      language?: string;
      locationType?: MarketplaceLocationType;
      authorizationStatus?: MarketplaceAuthorizationStatus;
      urgency?: MarketplaceUrgency;
      page?: number;
      pageSize?: number;
    },
    ctx: RequestContext,
  ) {
    const profile = await this.requireActiveProviderProfile(userId);
    const page = Math.max(1, filters.page ?? 1);
    const pageSize = Math.min(50, Math.max(1, filters.pageSize ?? 20));
    const skip = (page - 1) * pageSize;

    const rows = await this.prisma.marketplaceRequest.findMany({
      where: {
        tenantId: profile.tenantId,
        status: 'ACTIVE',
        removedAt: null,
        ...(filters.ageRange ? { ageRange: filters.ageRange as never } : {}),
        ...(filters.language
          ? {
              languagePreference: {
                contains: filters.language,
                mode: 'insensitive',
              },
            }
          : {}),
        ...(filters.locationType ? { locationType: filters.locationType } : {}),
        ...(filters.authorizationStatus
          ? { authorizationStatus: filters.authorizationStatus }
          : {}),
        ...(filters.urgency ? { urgency: filters.urgency } : {}),
        ...(filters.zipCode
          ? { zipCode: filters.zipCode.slice(0, 5) }
          : this.coverageZipFilter(profile.coverageZipCodes)),
      },
      orderBy: { createdAt: 'desc' },
      skip,
      take: pageSize,
    });

    const providerCentroid = this.providerCentroid(profile.coverageZipCodes);
    const ranked = rows
      .map((row) => {
        const distanceMiles = providerCentroid
          ? haversineMiles(
              providerCentroid.lat,
              providerCentroid.lng,
              Number(row.zipCentroidLat),
              Number(row.zipCentroidLng),
            )
          : undefined;
        const score = this.rankRequest(profile, row, distanceMiles);
        return {
          ...toPublicMarketplaceRequest(row, { distanceMiles }),
          matchScore: score,
        };
      })
      .filter((row) => {
        if (
          filters.serviceCategory &&
          !row.serviceCategories.includes(filters.serviceCategory)
        ) {
          return false;
        }
        if (
          filters.radiusMiles &&
          row.distanceMiles !== undefined &&
          row.distanceMiles > filters.radiusMiles
        ) {
          return false;
        }
        return true;
      })
      .sort((a, b) => (b.matchScore ?? 0) - (a.matchScore ?? 0));

    for (const row of ranked) {
      await this.audit.log({
        tenantId: profile.tenantId,
        actorId: userId,
        actorRole: profile.accountType,
        action: 'MARKETPLACE_REQUEST_VIEWED',
        resourceType: 'MarketplaceRequest',
        resourceId: row.id,
        ipAddress: ctx.ipAddress,
        userAgent: ctx.userAgent,
        metadata: { anonymousPublicId: row.anonymousPublicId },
      });
    }

    return { items: ranked, page, pageSize, total: ranked.length };
  }

  async getPublicRequestForProvider(
    userId: string,
    requestId: string,
    ctx: RequestContext,
  ) {
    const profile = await this.requireActiveProviderProfile(userId);
    const row = await this.prisma.marketplaceRequest.findFirst({
      where: {
        id: requestId,
        tenantId: profile.tenantId,
        status: 'ACTIVE',
        removedAt: null,
      },
    });
    if (!row) throw new NotFoundException('Marketplace request not found');

    await this.audit.log({
      tenantId: profile.tenantId,
      actorId: userId,
      actorRole: profile.accountType,
      action: 'MARKETPLACE_REQUEST_VIEWED',
      resourceType: 'MarketplaceRequest',
      resourceId: row.id,
      ipAddress: ctx.ipAddress,
      userAgent: ctx.userAgent,
      metadata: { anonymousPublicId: row.anonymousPublicId },
    });

    return toPublicMarketplaceRequest(row);
  }

  async submitProviderInterest(
    userId: string,
    requestId: string,
    input: { message?: string; availability?: Record<string, unknown> },
    ctx: RequestContext,
  ) {
    const profile = await this.requireActiveProviderProfile(userId);
    const request = await this.prisma.marketplaceRequest.findFirst({
      where: {
        id: requestId,
        tenantId: profile.tenantId,
        status: 'ACTIVE',
        removedAt: null,
      },
    });
    if (!request) throw new NotFoundException('Marketplace request not found');

    const interest = await this.prisma.marketplaceInterest.upsert({
      where: {
        marketplaceRequestId_providerProfileId: {
          marketplaceRequestId: requestId,
          providerProfileId: profile.id,
        },
      },
      create: {
        tenantId: profile.tenantId,
        marketplaceRequestId: requestId,
        providerProfileId: profile.id,
        message: input.message,
        availability: (input.availability ?? {}) as Prisma.InputJsonValue,
        status: 'PENDING_PARENT_REVIEW',
      },
      update: {
        message: input.message,
        availability: (input.availability ?? {}) as Prisma.InputJsonValue,
        status: 'PENDING_PARENT_REVIEW',
      },
    });

    await this.audit.log({
      tenantId: profile.tenantId,
      actorId: userId,
      actorRole: profile.accountType,
      action: 'MARKETPLACE_INTEREST_SUBMITTED',
      resourceType: 'MarketplaceInterest',
      resourceId: interest.id,
      patientId: request.childId,
      ipAddress: ctx.ipAddress,
      userAgent: ctx.userAgent,
    });

    await this.notifications.create({
      tenantId: profile.tenantId,
      userId: request.parentUserId,
      title: 'A provider is available in your area',
      body: `${profile.displayName} responded to your anonymous service request.`,
      actionType: 'MARKETPLACE_INTEREST',
      metadata: { marketplaceRequestId: requestId, interestId: interest.id },
    });

    return interest;
  }

  async grantShareConsent(
    userId: string,
    requestId: string,
    providerProfileId: string,
    ctx: RequestContext,
  ) {
    const request = await this.requireParentRequest(userId, requestId);
    const provider = await this.prisma.providerMarketplaceProfile.findFirst({
      where: { id: providerProfileId, tenantId: request.tenantId },
    });
    if (!provider) throw new NotFoundException('Provider profile not found');

    const consentText = SHARE_IDENTIFIABLE_INFO_CONSENT_TEMPLATE.replace(
      '{providerName}',
      provider.displayName,
    );

    await this.recordConsent({
      tenantId: request.tenantId,
      parentUserId: userId,
      childId: request.childId,
      marketplaceRequestId: request.id,
      providerProfileId: provider.id,
      consentType: 'SHARE_IDENTIFIABLE_INFO',
      consentText,
      ctx,
    });

    await this.prisma.marketplaceInterest.updateMany({
      where: {
        marketplaceRequestId: requestId,
        providerProfileId,
      },
      data: { status: 'ACCEPTED' },
    });

    await this.audit.log({
      tenantId: request.tenantId,
      actorId: userId,
      actorRole: 'PARENT',
      action: 'MARKETPLACE_IDENTIFIABLE_SHARED',
      resourceType: 'MarketplaceRequest',
      resourceId: request.id,
      patientId: request.childId,
      ipAddress: ctx.ipAddress,
      userAgent: ctx.userAgent,
      metadata: { providerProfileId },
    });

    await this.phiAudit.logPhiAccess({
      tenantId: request.tenantId,
      actorId: userId,
      action: 'READ',
      resourceType: 'Child',
      resourceId: request.childId,
      patientId: request.childId,
      ipAddress: ctx.ipAddress,
      userAgent: ctx.userAgent,
    });

    await this.notifications.create({
      tenantId: request.tenantId,
      userId: provider.userId,
      title: 'Parent approved sharing child details',
      body: 'You may now view authorized child details for care coordination.',
      actionType: 'MARKETPLACE_CONSENT_GRANTED',
      metadata: { marketplaceRequestId: requestId },
    });

    return { granted: true };
  }

  async revokeConsent(
    userId: string,
    requestId: string,
    providerProfileId: string,
    ctx: RequestContext,
  ) {
    const request = await this.requireParentRequest(userId, requestId);
    const active = await this.prisma.marketplaceConsentRecord.findFirst({
      where: {
        marketplaceRequestId: requestId,
        providerProfileId,
        consentType: 'SHARE_IDENTIFIABLE_INFO',
        granted: true,
        revokedAt: null,
      },
      orderBy: { createdAt: 'desc' },
    });
    if (!active) throw new NotFoundException('Active consent not found');

    await this.prisma.marketplaceConsentRecord.update({
      where: { id: active.id },
      data: { granted: false, revokedAt: new Date() },
    });

    await this.recordConsent({
      tenantId: request.tenantId,
      parentUserId: userId,
      childId: request.childId,
      marketplaceRequestId: request.id,
      providerProfileId,
      consentType: 'REVOKE_CONSENT',
      consentText:
        'Parent revoked consent to share identifiable child information.',
      ctx,
      granted: false,
    });

    await this.prisma.marketplaceInterest.updateMany({
      where: { marketplaceRequestId: requestId, providerProfileId },
      data: { status: 'REJECTED' },
    });

    const provider = await this.prisma.providerMarketplaceProfile.findUnique({
      where: { id: providerProfileId },
    });
    if (provider) {
      await this.notifications.create({
        tenantId: request.tenantId,
        userId: provider.userId,
        title: 'Parent revoked consent',
        body: 'Access to identifiable child details has been removed.',
        actionType: 'MARKETPLACE_CONSENT_REVOKED',
        metadata: { marketplaceRequestId: requestId },
      });
    }

    return { revoked: true };
  }

  async getAuthorizedChildDetailsForProvider(
    userId: string,
    requestId: string,
    ctx: RequestContext,
  ) {
    const profile = await this.requireActiveProviderProfile(userId);
    const request = await this.prisma.marketplaceRequest.findFirst({
      where: { id: requestId, tenantId: profile.tenantId },
    });
    if (!request) throw new NotFoundException('Marketplace request not found');

    const consent = await this.prisma.marketplaceConsentRecord.findFirst({
      where: {
        marketplaceRequestId: requestId,
        providerProfileId: profile.id,
        consentType: 'SHARE_IDENTIFIABLE_INFO',
        granted: true,
        revokedAt: null,
      },
    });
    if (!consent) {
      throw new ForbiddenException(
        'Parent consent is required before viewing identifiable child details.',
      );
    }

    const child = await this.prisma.child.findUnique({
      where: { id: request.childId },
      include: { parent: { include: { user: true } } },
    });
    if (!child) throw new NotFoundException('Child not found');

    await this.phiAudit.logPhiAccess({
      tenantId: profile.tenantId,
      actorId: userId,
      action: 'READ',
      resourceType: 'Child',
      resourceId: child.id,
      patientId: child.id,
      ipAddress: ctx.ipAddress,
      userAgent: ctx.userAgent,
    });

    return {
      child: {
        id: child.id,
        firstName: child.firstName,
        lastName: child.lastName,
        dateOfBirth: child.dateOfBirth,
        gender: child.gender,
        primaryLanguage: child.primaryLanguage,
        zipCode: child.zipCode,
        city: child.city,
        state: child.state,
        guardianName: child.guardianName,
        guardianPhone: child.guardianPhone,
        guardianEmail: child.guardianEmail,
      },
      parentContact: {
        name: `${child.parent.user.firstName} ${child.parent.user.lastName}`,
        email: child.parent.user.email,
        phone: child.parent.user.phone,
      },
      marketplaceRequestId: request.id,
      anonymousPublicId: request.anonymousPublicId,
    };
  }

  async getProviderProfile(userId: string) {
    return this.prisma.providerMarketplaceProfile.findUnique({
      where: { userId },
    });
  }

  async upsertProviderProfile(
    userId: string,
    tenantId: string,
    input: {
      accountType: 'THERAPIST' | 'AGENCY';
      legalName: string;
      displayName: string;
      licenseNumber?: string;
      npi?: string;
      serviceCategories: string[];
      coverageZipCodes: string[];
      languages: string[];
      availability?: Record<string, unknown>;
      confidentialityTermsAccepted: boolean;
    },
  ) {
    if (!input.confidentialityTermsAccepted) {
      throw new BadRequestException(
        'Marketplace confidentiality terms must be accepted.',
      );
    }

    const therapist = await this.prisma.therapist.findUnique({
      where: { userId },
    });
    const agency = await this.prisma.agency.findFirst({
      where: { tenantId },
    });

    return this.prisma.providerMarketplaceProfile.upsert({
      where: { userId },
      create: {
        tenantId,
        userId,
        accountType: input.accountType,
        therapistId: therapist?.id,
        agencyId: input.accountType === 'AGENCY' ? agency?.id : undefined,
        legalName: input.legalName,
        displayName: input.displayName,
        licenseNumber: input.licenseNumber,
        npi: input.npi,
        serviceCategories: input.serviceCategories,
        coverageZipCodes: input.coverageZipCodes,
        languages: input.languages,
        availability: (input.availability ?? {}) as Prisma.InputJsonValue,
        confidentialityTermsAccepted: true,
        confidentialityAcceptedAt: new Date(),
        verifiedStatus: therapist?.isVerified ? 'VERIFIED' : 'PENDING',
      },
      update: {
        legalName: input.legalName,
        displayName: input.displayName,
        licenseNumber: input.licenseNumber,
        npi: input.npi,
        serviceCategories: input.serviceCategories,
        coverageZipCodes: input.coverageZipCodes,
        languages: input.languages,
        availability: (input.availability ?? {}) as Prisma.InputJsonValue,
        confidentialityTermsAccepted: true,
        confidentialityAcceptedAt: new Date(),
      },
    });
  }

  async adminListRequests(tenantId: string) {
    const rows = await this.prisma.marketplaceRequest.findMany({
      where: { tenantId },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
    return rows.map((row) => toPublicMarketplaceRequest(row));
  }

  async listConsentHistoryForParent(userId: string, requestId: string) {
    await this.requireParentRequest(userId, requestId);
    const records = await this.prisma.marketplaceConsentRecord.findMany({
      where: { marketplaceRequestId: requestId, parentUserId: userId },
      orderBy: { createdAt: 'desc' },
      include: {
        providerProfile: {
          select: { id: true, displayName: true, accountType: true },
        },
      },
    });
    return records.map((row) => ({
      id: row.id,
      consentType: row.consentType,
      consentTextVersion: row.consentTextVersion,
      granted: row.granted,
      revokedAt: row.revokedAt,
      createdAt: row.createdAt,
      provider: row.providerProfile
        ? {
            id: row.providerProfile.id,
            displayName: row.providerProfile.displayName,
            accountType: row.providerProfile.accountType,
          }
        : null,
    }));
  }

  async reportListing(
    reporterUserId: string,
    requestId: string,
    input: { reason: string; details?: string; reportedUserId?: string },
  ) {
    const request = await this.prisma.marketplaceRequest.findUnique({
      where: { id: requestId },
    });
    if (!request) throw new NotFoundException('Marketplace request not found');

    return this.prisma.marketplaceReport.create({
      data: {
        tenantId: request.tenantId,
        reporterUserId,
        marketplaceRequestId: requestId,
        reportedUserId: input.reportedUserId,
        reason: input.reason,
        details: input.details,
      },
    });
  }

  async adminSuspendUser(
    adminUserId: string,
    targetUserId: string,
    reason?: string,
  ) {
    const profile = await this.prisma.providerMarketplaceProfile.findUnique({
      where: { userId: targetUserId },
    });
    if (!profile) {
      throw new NotFoundException('Provider marketplace profile not found');
    }

    await this.audit.log({
      tenantId: profile.tenantId,
      actorId: adminUserId,
      actorRole: 'PLATFORM_ADMIN',
      action: 'USER_DISABLED',
      resourceType: 'ProviderMarketplaceProfile',
      resourceId: profile.id,
      metadata: { reason: reason ?? 'Suspended by admin' },
    });

    return this.prisma.providerMarketplaceProfile.update({
      where: { id: profile.id },
      data: {
        verifiedStatus: 'SUSPENDED',
        suspendedAt: new Date(),
      },
    });
  }

  async adminVerifyProvider(adminUserId: string, profileId: string) {
    const profile = await this.prisma.providerMarketplaceProfile.findUnique({
      where: { id: profileId },
    });
    if (!profile) throw new NotFoundException('Provider profile not found');

    await this.audit.log({
      tenantId: profile.tenantId,
      actorId: adminUserId,
      actorRole: 'PLATFORM_ADMIN',
      action: 'UPDATE',
      resourceType: 'ProviderMarketplaceProfile',
      resourceId: profile.id,
    });

    return this.prisma.providerMarketplaceProfile.update({
      where: { id: profileId },
      data: { verifiedStatus: 'VERIFIED' },
    });
  }

  async adminMarketplaceAuditLogs(tenantId: string) {
    return this.prisma.auditLog.findMany({
      where: {
        tenantId,
        action: {
          in: [
            'MARKETPLACE_REQUEST_VIEWED',
            'MARKETPLACE_INTEREST_SUBMITTED',
            'MARKETPLACE_IDENTIFIABLE_SHARED',
            'CONSENT_GRANTED',
            'CONSENT_REVOKED',
          ],
        },
      },
      orderBy: { createdAt: 'desc' },
      take: 200,
    });
  }

  async adminRemoveListing(
    adminUserId: string,
    requestId: string,
    reason: string,
  ) {
    const row = await this.prisma.marketplaceRequest.findUnique({
      where: { id: requestId },
    });
    if (!row) throw new NotFoundException('Listing not found');
    return this.prisma.marketplaceRequest.update({
      where: { id: requestId },
      data: {
        status: 'CLOSED',
        removedAt: new Date(),
        removedReason: reason,
      },
    });
  }

  async pauseRequest(userId: string, requestId: string) {
    const request = await this.requireParentRequest(userId, requestId);
    return this.prisma.marketplaceRequest.update({
      where: { id: request.id },
      data: { status: 'PAUSED' },
    });
  }

  async closeRequest(userId: string, requestId: string) {
    const request = await this.requireParentRequest(userId, requestId);
    return this.prisma.marketplaceRequest.update({
      where: { id: request.id },
      data: { status: 'CLOSED' },
    });
  }

  private async recordConsent(data: {
    tenantId: string;
    parentUserId: string;
    childId: string;
    marketplaceRequestId: string;
    providerProfileId?: string;
    consentType: MarketplaceConsentType;
    consentText: string;
    ctx: RequestContext;
    granted?: boolean;
  }) {
    const record = await this.prisma.marketplaceConsentRecord.create({
      data: {
        tenantId: data.tenantId,
        parentUserId: data.parentUserId,
        childId: data.childId,
        marketplaceRequestId: data.marketplaceRequestId,
        providerProfileId: data.providerProfileId,
        consentType: data.consentType,
        consentTextVersion: MARKETPLACE_CONSENT_VERSION,
        consentTextSnapshot: data.consentText,
        granted: data.granted ?? true,
        ipAddress: data.ctx.ipAddress,
        deviceInfo: data.ctx.deviceInfo ?? data.ctx.userAgent,
      },
    });

    await this.audit.log({
      tenantId: data.tenantId,
      actorId: data.parentUserId,
      actorRole: 'PARENT',
      action: data.granted === false ? 'CONSENT_REVOKED' : 'CONSENT_GRANTED',
      resourceType: 'MarketplaceConsentRecord',
      resourceId: record.id,
      patientId: data.childId,
      ipAddress: data.ctx.ipAddress,
      userAgent: data.ctx.userAgent,
      metadata: {
        consentType: data.consentType,
        marketplaceRequestId: data.marketplaceRequestId,
        providerProfileId: data.providerProfileId,
      },
    });

    return record;
  }

  private async requireParent(userId: string) {
    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (!parent) throw new ForbiddenException('Parent profile required');
    return parent;
  }

  private async requireParentChild(parentId: string, childId: string) {
    const child = await this.prisma.child.findFirst({
      where: { id: childId, parentId },
      include: { parent: true },
    });
    if (!child) throw new NotFoundException('Child not found');
    return child;
  }

  private async requireParentRequest(userId: string, requestId: string) {
    const request = await this.prisma.marketplaceRequest.findFirst({
      where: { id: requestId, parentUserId: userId },
    });
    if (!request) throw new NotFoundException('Marketplace request not found');
    return request;
  }

  private async requireActiveProviderProfile(userId: string) {
    const profile = await this.prisma.providerMarketplaceProfile.findUnique({
      where: { userId },
    });
    if (!profile) {
      throw new ForbiddenException(
        'Complete marketplace onboarding before accessing requests.',
      );
    }
    if (!profile.confidentialityTermsAccepted) {
      throw new ForbiddenException('Accept marketplace confidentiality terms.');
    }
    if (profile.verifiedStatus === 'SUSPENDED') {
      throw new ForbiddenException('Marketplace access suspended.');
    }
    return profile;
  }

  private extractServiceCategories(
    screening: {
      recommendations: unknown;
      suggestedServiceCategories?: unknown;
    } | null,
  ): string[] {
    if (screening?.suggestedServiceCategories) {
      const arr = screening.suggestedServiceCategories;
      if (Array.isArray(arr) && arr.length > 0) {
        return arr.map((v) => String(v));
      }
    }
    if (!screening || !Array.isArray(screening.recommendations))
      return ['EVALUATION'];
    return [
      ...new Set(
        screening.recommendations.map((rec: { code?: string }) =>
          mapTherapyTypeToServiceCategory(rec.code ?? 'OTHER'),
        ),
      ),
    ];
  }

  private extractConcernTags(
    screening: {
      recommendations: unknown;
      concernTags?: unknown;
      responses?: unknown;
    } | null,
  ): string[] {
    if (screening?.concernTags && Array.isArray(screening.concernTags)) {
      return screening.concernTags.map((t) => String(t));
    }
    if (!screening || !Array.isArray(screening.recommendations)) {
      return ['general developmental concerns'];
    }
    return deriveConcernTagsFromScreening(
      screening.recommendations as Array<{
        code?: string;
        explanation?: string;
      }>,
    );
  }

  private coverageZipFilter(
    coverageZipCodes: unknown,
  ): { zipCode: { in: string[] } } | undefined {
    if (!Array.isArray(coverageZipCodes) || coverageZipCodes.length === 0) {
      return undefined;
    }
    return {
      zipCode: {
        in: coverageZipCodes.map((z) => String(z).slice(0, 5)),
      },
    };
  }

  private providerCentroid(coverageZipCodes: unknown) {
    if (!Array.isArray(coverageZipCodes) || coverageZipCodes.length === 0) {
      return null;
    }
    return zipToApproxCentroid(String(coverageZipCodes[0]));
  }

  private rankRequest(
    profile: {
      serviceCategories: unknown;
      languages: unknown;
      verifiedStatus: string;
    },
    row: { serviceCategories: unknown; languagePreference?: string | null },
    distanceMiles?: number,
  ): number {
    let score = 0;
    const providerCats = Array.isArray(profile.serviceCategories)
      ? profile.serviceCategories.map(String)
      : [];
    const requestCats = Array.isArray(row.serviceCategories)
      ? row.serviceCategories.map(String)
      : [];
    const overlap = requestCats.filter((c) => providerCats.includes(c)).length;
    score += overlap * 25;
    if (distanceMiles !== undefined) {
      score += Math.max(0, 40 - distanceMiles);
    }
    const langs = Array.isArray(profile.languages)
      ? profile.languages.map((l) => String(l).toLowerCase())
      : [];
    if (
      row.languagePreference &&
      langs.includes(row.languagePreference.toLowerCase())
    ) {
      score += 15;
    }
    if (profile.verifiedStatus === 'VERIFIED') score += 10;
    return Number(score.toFixed(2));
  }

  private async generateAnonymousPublicId(): Promise<string> {
    for (let i = 0; i < 8; i++) {
      const id = `SR-${randomInt(10000, 99999)}`;
      const exists = await this.prisma.marketplaceRequest.findUnique({
        where: { anonymousPublicId: id },
      });
      if (!exists) return id;
    }
    throw new BadRequestException('Could not allocate anonymous request id');
  }
}
