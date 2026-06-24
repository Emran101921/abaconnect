import { Injectable, NotFoundException } from '@nestjs/common';
import { AuditAction, Prisma } from '../../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import {
  assertEiBillingRole,
  EiBillingActor,
  resolveAgencyIdForActor,
} from './ei-billing-access.util';
import { EiBillingAuditService } from './ei-billing-audit.service';

@Injectable()
export class EiBillingCaseService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: EiBillingAuditService,
  ) {}

  async getCaseProfile(
    actor: EiBillingActor,
    childId: string,
    agencyId?: string,
  ) {
    const resolvedAgencyId = await resolveAgencyIdForActor(
      this.prisma,
      actor,
      agencyId,
    );
    return this.prisma.eiCaseBillingProfile.findUnique({
      where: {
        agencyId_childId: { agencyId: resolvedAgencyId, childId },
      },
      include: { child: { select: { firstName: true, lastName: true } } },
    });
  }

  async upsertCaseProfile(
    actor: EiBillingActor,
    input: {
      agencyId?: string;
      childId: string;
      eiCaseId?: string;
      municipality?: string;
      scReferenceNumber?: string;
      ifspAuthorizationNumber?: string;
      serviceType?: string;
      frequencyPerWeek?: number;
      durationMinutes?: number;
      authorizationStartDate?: Date;
      authorizationEndDate?: Date;
      placeOfService?: string;
      medicaidCin?: string;
      consentStatus?: string;
      consentSignedAt?: Date;
    },
  ) {
    assertEiBillingRole(actor, [
      'AGENCY_ADMIN',
      'PLATFORM_ADMIN',
      'BILLING_STAFF',
      'SERVICE_COORDINATOR',
    ]);
    const agencyId = await resolveAgencyIdForActor(
      this.prisma,
      actor,
      input.agencyId,
    );

    const caseload = await this.prisma.agencyCaseloadChild.findUnique({
      where: { agencyId_childId: { agencyId, childId: input.childId } },
    });
    if (!caseload && actor.role === 'SERVICE_COORDINATOR') {
      const assignment =
        await this.prisma.childServiceCoordinatorAssignment.findFirst({
          where: {
            childId: input.childId,
            serviceCoordinator: { id: actor.id },
            status: 'ACTIVE',
          },
        });
      if (!assignment) {
        throw new NotFoundException('Child not assigned to service coordinator');
      }
    }

    const profile = await this.prisma.eiCaseBillingProfile.upsert({
      where: {
        agencyId_childId: { agencyId, childId: input.childId },
      },
      create: {
        agencyId,
        childId: input.childId,
        eiCaseId: input.eiCaseId,
        municipality: input.municipality,
        scReferenceNumber: input.scReferenceNumber,
        ifspAuthorizationNumber: input.ifspAuthorizationNumber,
        serviceType: input.serviceType,
        frequencyPerWeek: input.frequencyPerWeek,
        durationMinutes: input.durationMinutes,
        authorizationStartDate: input.authorizationStartDate,
        authorizationEndDate: input.authorizationEndDate,
        placeOfService: input.placeOfService,
        medicaidCin: input.medicaidCin,
        consentStatus:
          (input.consentStatus as Prisma.EiCaseBillingProfileCreateInput['consentStatus']) ??
          'PENDING',
        consentSignedAt: input.consentSignedAt,
      },
      update: {
        eiCaseId: input.eiCaseId,
        municipality: input.municipality,
        scReferenceNumber: input.scReferenceNumber,
        ifspAuthorizationNumber: input.ifspAuthorizationNumber,
        serviceType: input.serviceType,
        frequencyPerWeek: input.frequencyPerWeek,
        durationMinutes: input.durationMinutes,
        authorizationStartDate: input.authorizationStartDate,
        authorizationEndDate: input.authorizationEndDate,
        placeOfService: input.placeOfService,
        medicaidCin: input.medicaidCin,
        ...(input.consentStatus
          ? {
              consentStatus:
                input.consentStatus as Prisma.EiCaseBillingProfileUpdateInput['consentStatus'],
            }
          : {}),
        consentSignedAt: input.consentSignedAt,
      },
    });

    await this.audit.log(
      actor.tenantId,
      actor.id,
      actor.role,
      AuditAction.EI_BILLING_PROFILE_UPDATED,
      'EiCaseBillingProfile',
      profile.id,
      { agencyId, childId: input.childId },
      input.childId,
    );

    return profile;
  }
}
