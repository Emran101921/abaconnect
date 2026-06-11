import { ForbiddenException, Injectable } from '@nestjs/common';
import {
  ProviderOnboardingStatus,
  UserRole,
} from '../../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';

export interface ProviderOnboardingChecklist {
  identityComplete: boolean;
  licenseComplete: boolean;
  npiComplete: boolean;
  taxIdComplete: boolean;
  backgroundCheckComplete: boolean;
  hipaaTrainingComplete: boolean;
  confidentialityAgreementComplete: boolean;
  agencyApprovalComplete: boolean;
  isActive: boolean;
  phiAccessApproved: boolean;
  onboardingStatus: ProviderOnboardingStatus;
}

@Injectable()
export class ProviderOnboardingService {
  constructor(private readonly prisma: PrismaService) {}

  async getChecklist(userId: string): Promise<ProviderOnboardingChecklist | null> {
    const therapist = await this.prisma.therapist.findUnique({
      where: { userId },
      include: { user: true },
    });
    if (!therapist) return null;

    return {
      identityComplete: Boolean(
        therapist.user.firstName && therapist.user.lastName,
      ),
      licenseComplete: Boolean(
        therapist.licenseNumber && therapist.licenseState,
      ),
      npiComplete: Boolean(therapist.npi),
      taxIdComplete: Boolean(therapist.taxId),
      backgroundCheckComplete:
        therapist.backgroundCheckStatus === 'PASSED' ||
        Boolean(therapist.backgroundCheckCompletedAt),
      hipaaTrainingComplete: Boolean(therapist.hipaaTrainingAttestedAt),
      confidentialityAgreementComplete: Boolean(
        therapist.confidentialityAgreementSignedAt,
      ),
      agencyApprovalComplete: Boolean(therapist.agencyApprovedAt),
      isActive: therapist.onboardingStatus !== ProviderOnboardingStatus.INACTIVE,
      phiAccessApproved: therapist.phiAccessApproved,
      onboardingStatus: therapist.onboardingStatus,
    };
  }

  isChecklistComplete(checklist: ProviderOnboardingChecklist): boolean {
    return (
      checklist.identityComplete &&
      checklist.licenseComplete &&
      checklist.npiComplete &&
      checklist.hipaaTrainingComplete &&
      checklist.confidentialityAgreementComplete
    );
  }

  isReadyForAdminReview(checklist: ProviderOnboardingChecklist): boolean {
    return (
      this.isChecklistComplete(checklist) &&
      checklist.onboardingStatus === ProviderOnboardingStatus.IN_REVIEW
    );
  }

  async assertPhiAccess(userId: string, roles: string[]): Promise<void> {
    if (!roles.includes(UserRole.THERAPIST)) return;

    const therapist = await this.prisma.therapist.findUnique({
      where: { userId },
    });
    if (!therapist) {
      throw new ForbiddenException('Provider profile not found');
    }
    if (!therapist.phiAccessApproved) {
      throw new ForbiddenException(
        'Provider PHI access is disabled until onboarding and admin approval are complete',
      );
    }
    if (therapist.onboardingStatus !== ProviderOnboardingStatus.APPROVED) {
      throw new ForbiddenException(
        'Provider onboarding must be approved before accessing client PHI',
      );
    }
  }

  async attestHipaaTraining(userId: string) {
    return this.prisma.therapist.update({
      where: { userId },
      data: { hipaaTrainingAttestedAt: new Date() },
    });
  }

  async attestConfidentialityAgreement(userId: string) {
    return this.prisma.therapist.update({
      where: { userId },
      data: { confidentialityAgreementSignedAt: new Date() },
    });
  }

  async submitForReview(userId: string) {
    const checklist = await this.getChecklist(userId);
    if (!checklist) {
      throw new ForbiddenException('Provider profile not found');
    }
    if (!checklist.licenseComplete || !checklist.npiComplete) {
      throw new ForbiddenException(
        'NPI and license information are required before submitting for review',
      );
    }
    if (!checklist.hipaaTrainingComplete || !checklist.confidentialityAgreementComplete) {
      throw new ForbiddenException(
        'HIPAA training and confidentiality agreement attestations are required',
      );
    }
    return this.prisma.therapist.update({
      where: { userId },
      data: { onboardingStatus: ProviderOnboardingStatus.IN_REVIEW },
    });
  }

  async listPendingApproval(tenantId: string) {
    return this.prisma.therapist.findMany({
      where: {
        tenantId,
        phiAccessApproved: false,
        onboardingStatus: {
          in: [
            ProviderOnboardingStatus.IN_REVIEW,
            ProviderOnboardingStatus.PENDING,
          ],
        },
      },
      include: { user: true },
      orderBy: { updatedAt: 'desc' },
      take: 50,
    });
  }

  async approveProvider(
    therapistId: string,
    approvedById: string,
    tenantId: string,
  ) {
    const therapist = await this.prisma.therapist.findFirst({
      where: { id: therapistId, tenantId },
    });
    if (!therapist) return null;

    const checklist = await this.getChecklist(therapist.userId);
    if (!checklist || !this.isReadyForAdminReview(checklist)) {
      throw new ForbiddenException(
        'Provider must complete onboarding and submit for review before approval',
      );
    }

    return this.prisma.therapist.update({
      where: { id: therapistId },
      data: {
        onboardingStatus: ProviderOnboardingStatus.APPROVED,
        phiAccessApproved: true,
        isVerified: true,
        agencyApprovedAt: new Date(),
        agencyApprovedById: approvedById,
      },
      include: { user: true },
    });
  }
}
