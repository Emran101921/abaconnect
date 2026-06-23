import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { AuditAction, Prisma } from '../../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import {
  assertEiBillingRole,
  EiBillingActor,
  resolveAgencyIdForActor,
} from './ei-billing-access.util';
import { EiBillingAuditService } from './ei-billing-audit.service';

@Injectable()
export class EiBillingEnrollmentService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: EiBillingAuditService,
  ) {}

  async getAgencyProfile(actor: EiBillingActor, agencyId?: string) {
    const resolvedAgencyId = await resolveAgencyIdForActor(
      this.prisma,
      actor,
      agencyId,
    );
    return this.prisma.eiAgencyBillingProfile.findUnique({
      where: { agencyId: resolvedAgencyId },
    });
  }

  async upsertAgencyProfile(
    actor: EiBillingActor,
    input: {
      agencyId?: string;
      legalName: string;
      npi?: string;
      medicaidProviderId?: string;
      ein?: string;
      etin?: string;
      eiHubReferenceId?: string;
      eftEnrollmentStatus?: string;
      baaSignedAt?: Date;
      baaDocumentKey?: string;
      baaSignerName?: string;
      enrollmentComplete?: boolean;
      addressLine1?: string;
      city?: string;
      state?: string;
      zipCode?: string;
      phone?: string;
    },
  ) {
    assertEiBillingRole(actor, ['AGENCY_ADMIN', 'PLATFORM_ADMIN', 'BILLING_STAFF']);
    const agencyId = await resolveAgencyIdForActor(
      this.prisma,
      actor,
      input.agencyId,
    );

    const profile = await this.prisma.eiAgencyBillingProfile.upsert({
      where: { agencyId },
      create: {
        tenantId: actor.tenantId,
        agencyId,
        legalName: input.legalName,
        npi: input.npi,
        medicaidProviderId: input.medicaidProviderId,
        ein: input.ein,
        etin: input.etin,
        eiHubReferenceId: input.eiHubReferenceId,
        eftEnrollmentStatus:
          (input.eftEnrollmentStatus as Prisma.EiAgencyBillingProfileCreateInput['eftEnrollmentStatus']) ??
          'NOT_STARTED',
        baaSignedAt: input.baaSignedAt,
        baaDocumentKey: input.baaDocumentKey,
        baaSignerName: input.baaSignerName,
        enrollmentComplete: input.enrollmentComplete ?? false,
        addressLine1: input.addressLine1,
        city: input.city,
        state: input.state ?? 'NY',
        zipCode: input.zipCode,
        phone: input.phone,
      },
      update: {
        legalName: input.legalName,
        npi: input.npi,
        medicaidProviderId: input.medicaidProviderId,
        ein: input.ein,
        etin: input.etin,
        eiHubReferenceId: input.eiHubReferenceId,
        ...(input.eftEnrollmentStatus
          ? {
              eftEnrollmentStatus:
                input.eftEnrollmentStatus as Prisma.EiAgencyBillingProfileUpdateInput['eftEnrollmentStatus'],
            }
          : {}),
        baaSignedAt: input.baaSignedAt,
        baaDocumentKey: input.baaDocumentKey,
        baaSignerName: input.baaSignerName,
        enrollmentComplete: input.enrollmentComplete,
        addressLine1: input.addressLine1,
        city: input.city,
        state: input.state,
        zipCode: input.zipCode,
        phone: input.phone,
      },
    });

    await this.audit.log(
      actor.tenantId,
      actor.id,
      actor.role,
      AuditAction.EI_BILLING_PROFILE_UPDATED,
      'EiAgencyBillingProfile',
      profile.id,
      { agencyId },
    );

    return profile;
  }

  async listProviderEnrollments(actor: EiBillingActor, agencyId?: string) {
    const resolvedAgencyId = await resolveAgencyIdForActor(
      this.prisma,
      actor,
      agencyId,
    );
    return this.prisma.eiProviderEnrollment.findMany({
      where: { agencyId: resolvedAgencyId },
      include: {
        therapist: {
          include: {
            user: { select: { firstName: true, lastName: true, email: true } },
          },
        },
      },
      orderBy: { updatedAt: 'desc' },
    });
  }

  async upsertProviderEnrollment(
    actor: EiBillingActor,
    input: {
      agencyId?: string;
      therapistId: string;
      renderingNpi?: string;
      licenseNumber?: string;
      licenseState?: string;
      licenseExpiry?: Date;
      discipline?: string;
      eiCategory?: string;
      medicaidEnrollmentStatus?: string;
      credentialStatus?: string;
      scrClearanceDate?: Date;
      scrClearanceExpiry?: Date;
      complianceDocs?: Prisma.InputJsonValue;
      isActive?: boolean;
    },
  ) {
    assertEiBillingRole(actor, ['AGENCY_ADMIN', 'PLATFORM_ADMIN', 'BILLING_STAFF']);
    const agencyId = await resolveAgencyIdForActor(
      this.prisma,
      actor,
      input.agencyId,
    );

    const link = await this.prisma.agencyTherapist.findUnique({
      where: {
        agencyId_therapistId: {
          agencyId,
          therapistId: input.therapistId,
        },
      },
    });
    if (!link) {
      throw new NotFoundException('Therapist is not linked to this agency');
    }

    const enrollment = await this.prisma.eiProviderEnrollment.upsert({
      where: {
        agencyId_therapistId: {
          agencyId,
          therapistId: input.therapistId,
        },
      },
      create: {
        agencyId,
        therapistId: input.therapistId,
        renderingNpi: input.renderingNpi,
        licenseNumber: input.licenseNumber,
        licenseState: input.licenseState,
        licenseExpiry: input.licenseExpiry,
        discipline: input.discipline,
        eiCategory: input.eiCategory,
        medicaidEnrollmentStatus:
          (input.medicaidEnrollmentStatus as Prisma.EiProviderEnrollmentCreateInput['medicaidEnrollmentStatus']) ??
          'NOT_ENROLLED',
        credentialStatus:
          (input.credentialStatus as Prisma.EiProviderEnrollmentCreateInput['credentialStatus']) ??
          'PENDING',
        scrClearanceDate: input.scrClearanceDate,
        scrClearanceExpiry: input.scrClearanceExpiry,
        complianceDocs: input.complianceDocs ?? [],
        isActive: input.isActive ?? true,
      },
      update: {
        renderingNpi: input.renderingNpi,
        licenseNumber: input.licenseNumber,
        licenseState: input.licenseState,
        licenseExpiry: input.licenseExpiry,
        discipline: input.discipline,
        eiCategory: input.eiCategory,
        ...(input.medicaidEnrollmentStatus
          ? {
              medicaidEnrollmentStatus:
                input.medicaidEnrollmentStatus as Prisma.EiProviderEnrollmentUpdateInput['medicaidEnrollmentStatus'],
            }
          : {}),
        ...(input.credentialStatus
          ? {
              credentialStatus:
                input.credentialStatus as Prisma.EiProviderEnrollmentUpdateInput['credentialStatus'],
            }
          : {}),
        scrClearanceDate: input.scrClearanceDate,
        scrClearanceExpiry: input.scrClearanceExpiry,
        complianceDocs: input.complianceDocs,
        isActive: input.isActive,
      },
    });

    await this.audit.log(
      actor.tenantId,
      actor.id,
      actor.role,
      AuditAction.EI_BILLING_ENROLLMENT_UPDATED,
      'EiProviderEnrollment',
      enrollment.id,
      { agencyId, therapistId: input.therapistId },
    );

    return enrollment;
  }
}
