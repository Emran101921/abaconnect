import { Args, ID, Mutation, Query, Resolver } from '@nestjs/graphql';
import { Roles } from '../common/decorators/roles.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { PrismaService } from '../prisma/prisma.service';
import { EiBillingCaseService } from '../ei-billing/ei-billing-case.service';
import { EiBillingClearinghouseService } from '../ei-billing/ei-billing-clearinghouse.service';
import { EiBillingDenialService } from '../ei-billing/ei-billing-denial.service';
import { EiBillingEnrollmentService } from '../ei-billing/ei-billing-enrollment.service';
import { EiBillingPaymentService } from '../ei-billing/ei-billing-payment.service';
import { EiBillingRecordService } from '../ei-billing/ei-billing-record.service';
import { EiBillingAuditService } from '../ei-billing/ei-billing-audit.service';
import { resolveEiBillingActor } from '../ei-billing/ei-billing-access.util';
import {
  EiBillingQueueFilterInput,
  ExportEiBillingRecordInput,
  RecordEiDenialInput,
  RecordEiPaymentInput,
  SubmitEiBillingRecordInput,
  TransitionEiBillingQueueInput,
  UpsertEiAgencyBillingProfileInput,
  UpsertEiCaseBillingProfileInput,
  UpsertEiClearinghouseConfigInput,
  UpsertEiProviderEnrollmentInput,
} from './inputs/ei-billing.input';
import {
  EiAgencyBillingProfileType,
  EiBillingAuditLogType,
  EiBillingDashboardType,
  EiBillingExportResultType,
  EiBillingRecordType,
  EiBillingReportRowType,
  EiBillingSubmitResultType,
  EiCaseBillingProfileType,
  EiClearinghouseConfigType,
  EiClearinghouseTestResultType,
  EiDenialListItemType,
  EiDenialType,
  EiPaymentPostingType,
  EiProviderEnrollmentType,
  GqlEiBillingQueueStatus,
} from './types/ei-billing.types';

@Resolver()
export class EiBillingResolver {
  constructor(
    private readonly prisma: PrismaService,
    private readonly records: EiBillingRecordService,
    private readonly enrollment: EiBillingEnrollmentService,
    private readonly cases: EiBillingCaseService,
    private readonly denials: EiBillingDenialService,
    private readonly payments: EiBillingPaymentService,
    private readonly clearinghouse: EiBillingClearinghouseService,
    private readonly audit: EiBillingAuditService,
  ) {}

  @Query(() => EiBillingDashboardType, { name: 'eiBillingDashboard' })
  @Roles(
    'PLATFORM_ADMIN',
    'AGENCY_ADMIN',
    'BILLING_STAFF',
    'THERAPIST',
    'SERVICE_COORDINATOR',
  )
  async eiBillingDashboard(
    @CurrentUser() user: AuthUser,
    @Args('agencyId', { type: () => ID, nullable: true }) agencyId?: string,
  ) {
    const actor = await resolveEiBillingActor(
      this.prisma,
      user.id,
      user.tenantId ?? '',
    );
    return this.records.getDashboard(actor, agencyId);
  }

  @Query(() => [EiBillingRecordType], { name: 'eiBillingQueue' })
  @Roles(
    'PLATFORM_ADMIN',
    'AGENCY_ADMIN',
    'BILLING_STAFF',
    'THERAPIST',
    'SERVICE_COORDINATOR',
  )
  async eiBillingQueue(
    @CurrentUser() user: AuthUser,
    @Args('filter', { nullable: true }) filter?: EiBillingQueueFilterInput,
  ) {
    const actor = await resolveEiBillingActor(
      this.prisma,
      user.id,
      user.tenantId ?? '',
    );
    const rows = await this.records.listQueue(actor, filter);
    return rows.map((row) => this.mapRecord(row));
  }

  @Query(() => EiBillingRecordType, { name: 'eiBillingRecord' })
  @Roles(
    'PLATFORM_ADMIN',
    'AGENCY_ADMIN',
    'BILLING_STAFF',
    'THERAPIST',
    'SERVICE_COORDINATOR',
  )
  async eiBillingRecord(
    @CurrentUser() user: AuthUser,
    @Args('id', { type: () => ID }) id: string,
  ) {
    const actor = await resolveEiBillingActor(
      this.prisma,
      user.id,
      user.tenantId ?? '',
    );
    const row = await this.records.getRecord(actor, id);
    return this.mapRecord(row);
  }

  @Query(() => EiAgencyBillingProfileType, {
    name: 'eiAgencyBillingProfile',
    nullable: true,
  })
  @Roles('PLATFORM_ADMIN', 'AGENCY_ADMIN', 'BILLING_STAFF')
  async eiAgencyBillingProfile(
    @CurrentUser() user: AuthUser,
    @Args('agencyId', { type: () => ID, nullable: true }) agencyId?: string,
  ) {
    const actor = await resolveEiBillingActor(
      this.prisma,
      user.id,
      user.tenantId ?? '',
    );
    const profile = await this.enrollment.getAgencyProfile(actor, agencyId);
    return profile ? this.mapAgencyProfile(profile) : null;
  }

  @Query(() => [EiProviderEnrollmentType], { name: 'eiProviderEnrollments' })
  @Roles('PLATFORM_ADMIN', 'AGENCY_ADMIN', 'BILLING_STAFF')
  async eiProviderEnrollments(
    @CurrentUser() user: AuthUser,
    @Args('agencyId', { type: () => ID, nullable: true }) agencyId?: string,
  ) {
    const actor = await resolveEiBillingActor(
      this.prisma,
      user.id,
      user.tenantId ?? '',
    );
    const rows = await this.enrollment.listProviderEnrollments(actor, agencyId);
    return rows.map((row) => ({
      id: row.id,
      therapistId: row.therapistId,
      therapistName: row.therapist?.user
        ? `${row.therapist.user.firstName} ${row.therapist.user.lastName}`
        : undefined,
      renderingNpi: row.renderingNpi ?? undefined,
      discipline: row.discipline ?? undefined,
      eiCategory: row.eiCategory ?? undefined,
      medicaidEnrollmentStatus: row.medicaidEnrollmentStatus,
      credentialStatus: row.credentialStatus,
      isActive: row.isActive,
    }));
  }

  @Query(() => EiCaseBillingProfileType, {
    name: 'eiCaseBillingProfile',
    nullable: true,
  })
  @Roles(
    'PLATFORM_ADMIN',
    'AGENCY_ADMIN',
    'BILLING_STAFF',
    'SERVICE_COORDINATOR',
  )
  async eiCaseBillingProfile(
    @CurrentUser() user: AuthUser,
    @Args('childId', { type: () => ID }) childId: string,
    @Args('agencyId', { type: () => ID, nullable: true }) agencyId?: string,
  ) {
    const actor = await resolveEiBillingActor(
      this.prisma,
      user.id,
      user.tenantId ?? '',
    );
    const profile = await this.cases.getCaseProfile(actor, childId, agencyId);
    if (!profile) return null;
    return {
      id: profile.id,
      childId: profile.childId,
      childDisplayName: profile.child
        ? `${profile.child.firstName} ${profile.child.lastName.charAt(0)}.`
        : undefined,
      eiCaseId: profile.eiCaseId ?? undefined,
      municipality: profile.municipality ?? undefined,
      ifspAuthorizationNumber: profile.ifspAuthorizationNumber ?? undefined,
      serviceType: profile.serviceType ?? undefined,
      medicaidCin: profile.medicaidCin ?? undefined,
      consentStatus: profile.consentStatus,
    };
  }

  @Query(() => [EiClearinghouseConfigType], { name: 'eiClearinghouseConfig' })
  @Roles('PLATFORM_ADMIN', 'AGENCY_ADMIN', 'BILLING_STAFF')
  async eiClearinghouseConfig(
    @CurrentUser() user: AuthUser,
    @Args('agencyId', { type: () => ID, nullable: true }) agencyId?: string,
  ) {
    const actor = await resolveEiBillingActor(
      this.prisma,
      user.id,
      user.tenantId ?? '',
    );
    const rows = await this.clearinghouse.getConfig(actor, agencyId);
    return rows.map((row) => this.mapClearinghouseConfig(row));
  }

  @Query(() => [EiDenialListItemType], { name: 'eiBillingDenials' })
  @Roles(
    'PLATFORM_ADMIN',
    'AGENCY_ADMIN',
    'BILLING_STAFF',
    'THERAPIST',
    'SERVICE_COORDINATOR',
  )
  async eiBillingDenials(
    @CurrentUser() user: AuthUser,
    @Args('agencyId', { type: () => ID, nullable: true }) agencyId?: string,
  ) {
    const actor = await resolveEiBillingActor(
      this.prisma,
      user.id,
      user.tenantId ?? '',
    );
    const rows = await this.denials.listDenials(actor, { agencyId });
    return rows.map((row) => ({
      id: row.id,
      code: row.code,
      reason: row.reason,
      payerName: row.payerName ?? undefined,
      correctionStatus: row.correctionStatus,
      receivedAt: row.receivedAt,
      recordId: row.recordId,
      childDisplayName: row.record.child
        ? `${row.record.child.firstName} ${row.record.child.lastName.charAt(0)}.`
        : undefined,
      therapistName: row.record.therapist?.user
        ? `${row.record.therapist.user.firstName} ${row.record.therapist.user.lastName}`
        : undefined,
      recordQueueStatus: row.record.queueStatus,
    }));
  }

  @Query(() => [EiBillingReportRowType], { name: 'eiBillingReports' })
  @Roles('PLATFORM_ADMIN', 'AGENCY_ADMIN', 'BILLING_STAFF')
  async eiBillingReports(
    @CurrentUser() user: AuthUser,
    @Args('agencyId', { type: () => ID, nullable: true }) agencyId?: string,
  ) {
    const actor = await resolveEiBillingActor(
      this.prisma,
      user.id,
      user.tenantId ?? '',
    );
    const rows = await this.records.getReports(actor, agencyId);
    return rows.map((row) => ({
      status: row.status,
      count: row.count,
      billedTotal: row.billedTotal ? Number(row.billedTotal) : undefined,
      allowedTotal: row.allowedTotal ? Number(row.allowedTotal) : undefined,
    }));
  }

  @Query(() => [EiBillingAuditLogType], { name: 'eiBillingAuditLogs' })
  @Roles('PLATFORM_ADMIN', 'AGENCY_ADMIN', 'BILLING_STAFF', 'COMPLIANCE_AUDITOR')
  async eiBillingAuditLogs(@CurrentUser() user: AuthUser) {
    const actor = await resolveEiBillingActor(
      this.prisma,
      user.id,
      user.tenantId ?? '',
    );
    const rows = await this.audit.search(actor.tenantId, {
      entityType: 'EiBillingRecord',
      take: 100,
    });
    return rows.map((row) => ({
      id: row.id,
      action: row.action,
      entityType: row.entityType,
      entityId: row.entityId ?? undefined,
      actorName: row.actor
        ? `${row.actor.firstName} ${row.actor.lastName}`
        : undefined,
      metadataJson: JSON.stringify(row.metadata ?? {}),
      createdAt: row.createdAt,
    }));
  }

  @Mutation(() => EiAgencyBillingProfileType, {
    name: 'upsertEiAgencyBillingProfile',
  })
  @Roles('PLATFORM_ADMIN', 'AGENCY_ADMIN', 'BILLING_STAFF')
  async upsertEiAgencyBillingProfile(
    @CurrentUser() user: AuthUser,
    @Args('input') input: UpsertEiAgencyBillingProfileInput,
  ) {
    const actor = await resolveEiBillingActor(
      this.prisma,
      user.id,
      user.tenantId ?? '',
    );
    const profile = await this.enrollment.upsertAgencyProfile(actor, {
      ...input,
      baaSignedAt: input.baaSignedAt
        ? new Date(input.baaSignedAt)
        : undefined,
    });
    return this.mapAgencyProfile(profile);
  }

  @Mutation(() => EiProviderEnrollmentType, {
    name: 'upsertEiProviderEnrollment',
  })
  @Roles('PLATFORM_ADMIN', 'AGENCY_ADMIN', 'BILLING_STAFF')
  async upsertEiProviderEnrollment(
    @CurrentUser() user: AuthUser,
    @Args('input') input: UpsertEiProviderEnrollmentInput,
  ) {
    const actor = await resolveEiBillingActor(
      this.prisma,
      user.id,
      user.tenantId ?? '',
    );
    const row = await this.enrollment.upsertProviderEnrollment(actor, {
      ...input,
      licenseExpiry: input.licenseExpiry
        ? new Date(input.licenseExpiry)
        : undefined,
    });
    return {
      id: row.id,
      therapistId: row.therapistId,
      renderingNpi: row.renderingNpi ?? undefined,
      discipline: row.discipline ?? undefined,
      eiCategory: row.eiCategory ?? undefined,
      medicaidEnrollmentStatus: row.medicaidEnrollmentStatus,
      credentialStatus: row.credentialStatus,
      isActive: row.isActive,
    };
  }

  @Mutation(() => EiCaseBillingProfileType, {
    name: 'upsertEiCaseBillingProfile',
  })
  @Roles(
    'PLATFORM_ADMIN',
    'AGENCY_ADMIN',
    'BILLING_STAFF',
    'SERVICE_COORDINATOR',
  )
  async upsertEiCaseBillingProfile(
    @CurrentUser() user: AuthUser,
    @Args('input') input: UpsertEiCaseBillingProfileInput,
  ) {
    const actor = await resolveEiBillingActor(
      this.prisma,
      user.id,
      user.tenantId ?? '',
    );
    const profile = await this.cases.upsertCaseProfile(actor, {
      ...input,
      authorizationStartDate: input.authorizationStartDate
        ? new Date(input.authorizationStartDate)
        : undefined,
      authorizationEndDate: input.authorizationEndDate
        ? new Date(input.authorizationEndDate)
        : undefined,
    });
    return {
      id: profile.id,
      childId: profile.childId,
      eiCaseId: profile.eiCaseId ?? undefined,
      municipality: profile.municipality ?? undefined,
      ifspAuthorizationNumber: profile.ifspAuthorizationNumber ?? undefined,
      serviceType: profile.serviceType ?? undefined,
      medicaidCin: profile.medicaidCin ?? undefined,
      consentStatus: profile.consentStatus,
    };
  }

  @Mutation(() => EiBillingRecordType, { name: 'validateEiBillingRecord' })
  @Roles('PLATFORM_ADMIN', 'AGENCY_ADMIN', 'BILLING_STAFF')
  async validateEiBillingRecord(
    @CurrentUser() user: AuthUser,
    @Args('recordId', { type: () => ID }) recordId: string,
  ) {
    const actor = await resolveEiBillingActor(
      this.prisma,
      user.id,
      user.tenantId ?? '',
    );
    const row = await this.records.validateRecord(actor, recordId);
    return this.mapRecord(row);
  }

  @Mutation(() => EiBillingRecordType, { name: 'transitionEiBillingQueue' })
  @Roles('PLATFORM_ADMIN', 'AGENCY_ADMIN', 'BILLING_STAFF')
  async transitionEiBillingQueue(
    @CurrentUser() user: AuthUser,
    @Args('input') input: TransitionEiBillingQueueInput,
  ) {
    const actor = await resolveEiBillingActor(
      this.prisma,
      user.id,
      user.tenantId ?? '',
    );
    const row = await this.records.transitionQueue(
      actor,
      input.recordId,
      input.targetStatus,
    );
    return this.mapRecord(row);
  }

  @Mutation(() => EiBillingRecordType, { name: 'createEiBillingFromSession' })
  @Roles('PLATFORM_ADMIN', 'AGENCY_ADMIN', 'BILLING_STAFF')
  async createEiBillingFromSession(
    @CurrentUser() user: AuthUser,
    @Args('sessionId', { type: () => ID }) sessionId: string,
    @Args('agencyId', { type: () => ID, nullable: true }) agencyId?: string,
  ) {
    const actor = await resolveEiBillingActor(
      this.prisma,
      user.id,
      user.tenantId ?? '',
    );
    const row = await this.records.createFromSession(actor, sessionId, agencyId);
    return this.mapRecord(row);
  }

  @Mutation(() => EiBillingRecordType, { name: 'lockEiSessionForBilling' })
  @Roles('PLATFORM_ADMIN', 'AGENCY_ADMIN', 'BILLING_STAFF')
  async lockEiSessionForBilling(
    @CurrentUser() user: AuthUser,
    @Args('sessionId', { type: () => ID }) sessionId: string,
  ) {
    const actor = await resolveEiBillingActor(
      this.prisma,
      user.id,
      user.tenantId ?? '',
    );
    const row = await this.records.lockSessionForBilling(actor, sessionId);
    return this.mapRecord(row);
  }

  @Mutation(() => EiBillingExportResultType, { name: 'exportEiBillingRecord' })
  @Roles('PLATFORM_ADMIN', 'BILLING_STAFF')
  async exportEiBillingRecord(
    @CurrentUser() user: AuthUser,
    @Args('input') input: ExportEiBillingRecordInput,
  ) {
    const actor = await resolveEiBillingActor(
      this.prisma,
      user.id,
      user.tenantId ?? '',
    );
    return this.records.exportRecord(
      actor,
      input.recordId,
      input.workflow,
      input.authorizedConfirm,
    );
  }

  @Mutation(() => EiBillingSubmitResultType, { name: 'submitEiBillingRecord' })
  @Roles('PLATFORM_ADMIN', 'BILLING_STAFF')
  async submitEiBillingRecord(
    @CurrentUser() user: AuthUser,
    @Args('input') input: SubmitEiBillingRecordInput,
  ) {
    const actor = await resolveEiBillingActor(
      this.prisma,
      user.id,
      user.tenantId ?? '',
    );
    const { record, result } = await this.records.submitRecord(
      actor,
      input.recordId,
      input.workflow,
      input.authorizedConfirm,
    );
    return {
      accepted: result.accepted,
      externalReferenceId: result.externalReferenceId,
      message: result.message,
      record: this.mapRecord(record),
    };
  }

  @Mutation(() => EiDenialType, { name: 'recordEiDenial' })
  @Roles('PLATFORM_ADMIN', 'AGENCY_ADMIN', 'BILLING_STAFF')
  async recordEiDenial(
    @CurrentUser() user: AuthUser,
    @Args('input') input: RecordEiDenialInput,
  ) {
    const actor = await resolveEiBillingActor(
      this.prisma,
      user.id,
      user.tenantId ?? '',
    );
    const denial = await this.denials.recordDenial(actor, input);
    return {
      id: denial.id,
      code: denial.code,
      reason: denial.reason,
      correctionStatus: denial.correctionStatus,
    };
  }

  @Mutation(() => EiPaymentPostingType, { name: 'recordEiPayment' })
  @Roles('PLATFORM_ADMIN', 'BILLING_STAFF')
  async recordEiPayment(
    @CurrentUser() user: AuthUser,
    @Args('input') input: RecordEiPaymentInput,
  ) {
    const actor = await resolveEiBillingActor(
      this.prisma,
      user.id,
      user.tenantId ?? '',
    );
    const posting = await this.payments.recordPayment(actor, {
      recordId: input.recordId,
      paidAmount: input.paidAmount,
      allowedAmount: input.allowedAmount,
      eftReference: input.eftReference,
      eraPlaceholder: input.eraPlaceholder,
    });
    return {
      id: posting.id,
      paidAmount: Number(posting.paidAmount),
      reconciliationStatus: posting.reconciliationStatus,
      postedAt: posting.postedAt,
    };
  }

  @Mutation(() => EiClearinghouseConfigType, {
    name: 'upsertEiClearinghouseConfig',
  })
  @Roles('PLATFORM_ADMIN')
  async upsertEiClearinghouseConfig(
    @CurrentUser() user: AuthUser,
    @Args('input') input: UpsertEiClearinghouseConfigInput,
  ) {
    const actor = await resolveEiBillingActor(
      this.prisma,
      user.id,
      user.tenantId ?? '',
    );
    const config = await this.clearinghouse.upsertConfig(actor, {
      ...input,
      baaSignedAt: input.baaSignedAt
        ? new Date(input.baaSignedAt)
        : undefined,
    });
    return this.mapClearinghouseConfig(config);
  }

  @Mutation(() => EiClearinghouseTestResultType, {
    name: 'testEiClearinghouseConnection',
  })
  @Roles('PLATFORM_ADMIN')
  async testEiClearinghouseConnection(
    @CurrentUser() user: AuthUser,
    @Args('configId', { type: () => ID }) configId: string,
  ) {
    const actor = await resolveEiBillingActor(
      this.prisma,
      user.id,
      user.tenantId ?? '',
    );
    const { config, result } = await this.clearinghouse.testConnection(
      actor,
      configId,
    );
    return {
      success: result.success,
      message: result.message,
      config: this.mapClearinghouseConfig(config),
    };
  }

  private mapRecord(row: {
    id: string;
    agencyId: string;
    childId: string;
    sessionId?: string | null;
    queueStatus: string;
    units: unknown;
    serviceDate: Date;
    lockedAt?: Date | null;
    submittedAt?: Date | null;
    externalReferenceId?: string | null;
    child?: { firstName: string; lastName: string };
    therapist?: { user?: { firstName: string; lastName: string } };
    validationIssues?: Array<{
      id: string;
      code: string;
      severity: string;
      message: string;
      resolved: boolean;
    }>;
    denials?: Array<{
      id: string;
      code: string;
      reason: string;
      correctionStatus: string;
      payerName?: string | null;
      receivedAt: Date;
    }>;
    payments?: Array<{
      id: string;
      paidAmount: unknown;
      allowedAmount?: unknown | null;
      reconciliationStatus: string;
      postedAt: Date;
      eftReference?: string | null;
    }>;
  }): EiBillingRecordType {
    return {
      id: row.id,
      agencyId: row.agencyId,
      childId: row.childId,
      sessionId: row.sessionId ?? undefined,
      queueStatus: row.queueStatus as GqlEiBillingQueueStatus,
      units: Number(row.units),
      serviceDate: row.serviceDate,
      childDisplayName: row.child
        ? `${row.child.firstName} ${row.child.lastName.charAt(0)}.`
        : undefined,
      therapistName: row.therapist?.user
        ? `${row.therapist.user.firstName} ${row.therapist.user.lastName}`
        : undefined,
      lockedAt: row.lockedAt ?? undefined,
      submittedAt: row.submittedAt ?? undefined,
      externalReferenceId: row.externalReferenceId ?? undefined,
      validationIssues: row.validationIssues?.map((issue) => ({
        id: issue.id,
        code: issue.code,
        severity: issue.severity,
        message: issue.message,
        resolved: issue.resolved,
      })),
      denials: row.denials?.map((denial) => ({
        id: denial.id,
        code: denial.code,
        reason: denial.reason,
        correctionStatus: denial.correctionStatus,
        payerName: denial.payerName ?? undefined,
        receivedAt: denial.receivedAt,
      })),
      payments: row.payments?.map((payment) => ({
        id: payment.id,
        paidAmount: Number(payment.paidAmount),
        allowedAmount: payment.allowedAmount
          ? Number(payment.allowedAmount)
          : undefined,
        reconciliationStatus: payment.reconciliationStatus,
        postedAt: payment.postedAt,
        eftReference: payment.eftReference ?? undefined,
      })),
    };
  }

  private mapAgencyProfile(row: {
    id: string;
    agencyId: string;
    legalName: string;
    npi?: string | null;
    medicaidProviderId?: string | null;
    ein?: string | null;
    etin?: string | null;
    eiHubReferenceId?: string | null;
    eftEnrollmentStatus: string;
    baaSignedAt?: Date | null;
    enrollmentComplete: boolean;
    city?: string | null;
    state?: string | null;
  }): EiAgencyBillingProfileType {
    return {
      id: row.id,
      agencyId: row.agencyId,
      legalName: row.legalName,
      npi: row.npi ?? undefined,
      medicaidProviderId: row.medicaidProviderId ?? undefined,
      ein: row.ein ?? undefined,
      etin: row.etin ?? undefined,
      eiHubReferenceId: row.eiHubReferenceId ?? undefined,
      eftEnrollmentStatus: row.eftEnrollmentStatus,
      baaSignedAt: row.baaSignedAt ?? undefined,
      enrollmentComplete: row.enrollmentComplete,
      city: row.city ?? undefined,
      state: row.state ?? undefined,
    };
  }

  private mapClearinghouseConfig(row: {
    id: string;
    name: string;
    workflow: string;
    testMode: boolean;
    isActive: boolean;
    tradingPartnerId?: string | null;
    baaSignedAt?: Date | null;
    lastConnectionTestAt?: Date | null;
    lastConnectionTestResult?: string | null;
  }): EiClearinghouseConfigType {
    return {
      id: row.id,
      name: row.name,
      workflow: row.workflow as EiClearinghouseConfigType['workflow'],
      testMode: row.testMode,
      isActive: row.isActive,
      tradingPartnerId: row.tradingPartnerId ?? undefined,
      baaSignedAt: row.baaSignedAt ?? undefined,
      lastConnectionTestAt: row.lastConnectionTestAt ?? undefined,
      lastConnectionTestResult: row.lastConnectionTestResult ?? undefined,
    };
  }
}
