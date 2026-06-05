import { Args, ID, Int, Mutation, Query, Resolver } from '@nestjs/graphql';
import { Roles } from '../common/decorators/roles.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { AiService } from '../ai/ai.service';
import { AnalyticsService } from '../analytics/analytics.service';
import { ComplaintsService } from '../complaints/complaints.service';
import { ComplianceService } from '../compliance/compliance.service';
import { DocumentsService } from '../documents/documents.service';
import { GpsService } from '../gps/gps.service';
import { InsuranceService } from '../insurance/insurance.service';
import { NotificationsService } from '../notifications/notifications.service';
import { TelehealthService } from '../telehealth/telehealth.service';
import {
  FileComplaintInput,
  GrantConsentInput,
  RecordEvvInput,
  RegisterDocumentInput,
  SoapAssistInput,
  SubmitInsuranceClaimInput,
} from './inputs/platform.input';
import {
  AnalyticsMetricType,
  ComplaintType,
  DocumentItemType,
  HipaaConsentType,
  InsuranceClaimType,
  NotificationType,
  SoapSuggestionType,
  TelehealthRoomType,
} from './types/platform.types';

@Resolver()
export class PlatformResolver {
  constructor(
    private readonly telehealth: TelehealthService,
    private readonly documents: DocumentsService,
    private readonly notifications: NotificationsService,
    private readonly insurance: InsuranceService,
    private readonly compliance: ComplianceService,
    private readonly gps: GpsService,
    private readonly ai: AiService,
    private readonly analytics: AnalyticsService,
    private readonly complaints: ComplaintsService,
  ) {}

  @Query(() => [TelehealthRoomType], { name: 'myTelehealthSessions' })
  @Roles('PARENT', 'THERAPIST')
  async myTelehealthSessions(
    @CurrentUser() user: AuthUser,
  ): Promise<TelehealthRoomType[]> {
    const rows = await this.telehealth.listForUser(user.id);
    const isParent = user.roles?.includes('PARENT');
    return rows.map((r) => ({
      id: r.id,
      roomId: r.roomId,
      joinUrl: isParent
        ? (r.patientUrl ?? undefined)
        : (r.providerUrl ?? undefined),
      startedAt: r.startedAt ?? undefined,
      vendor: r.vendor ?? undefined,
      appointmentLabel: r.appointment
        ? `${r.appointment.therapyType} · ${r.appointment.scheduledStart.toISOString()}`
        : undefined,
    }));
  }

  @Mutation(() => TelehealthRoomType, { name: 'joinTelehealth' })
  @Roles('PARENT', 'THERAPIST')
  async joinTelehealth(
    @CurrentUser() user: AuthUser,
    @Args('appointmentId', { type: () => ID }) appointmentId: string,
  ): Promise<TelehealthRoomType> {
    const row = await this.telehealth.getOrCreateForAppointment(
      user.id,
      appointmentId,
    );
    const started = await this.telehealth.startSession(user.id, row.id);
    const isParent = user.roles?.includes('PARENT');
    return {
      id: started.id,
      roomId: started.roomId,
      joinUrl: isParent
        ? (started.patientUrl ?? undefined)
        : (started.providerUrl ?? undefined),
      startedAt: started.startedAt ?? undefined,
      vendor: started.vendor ?? undefined,
    };
  }

  @Query(() => [DocumentItemType], { name: 'myDocuments' })
  @Roles('PARENT', 'THERAPIST')
  async myDocuments(
    @CurrentUser() user: AuthUser,
  ): Promise<DocumentItemType[]> {
    const rows = await this.documents.listForUser(user.id);
    return rows.map((d) => ({
      id: d.id,
      title: d.title,
      fileName: d.fileName,
      type: d.type,
      fileSize: d.fileSize,
      uploadedAt: d.uploadedAt,
    }));
  }

  @Mutation(() => DocumentItemType, { name: 'registerDocument' })
  @Roles('PARENT', 'THERAPIST')
  async registerDocument(
    @CurrentUser() user: AuthUser,
    @Args('input') input: RegisterDocumentInput,
  ): Promise<DocumentItemType> {
    const d = await this.documents.registerUpload(user.id, input);
    return {
      id: d.id,
      title: d.title,
      fileName: d.fileName,
      type: d.type,
      fileSize: d.fileSize,
      uploadedAt: d.uploadedAt,
    };
  }

  @Mutation(() => Boolean, { name: 'deleteMyDocument' })
  @Roles('PARENT', 'THERAPIST')
  async deleteMyDocument(
    @CurrentUser() user: AuthUser,
    @Args('documentId', { type: () => ID }) documentId: string,
  ): Promise<boolean> {
    await this.documents.deleteForUser(user.id, documentId);
    return true;
  }

  @Query(() => Int, { name: 'myUnreadNotificationCount' })
  @Roles('PARENT', 'THERAPIST', 'AGENCY_ADMIN', 'PLATFORM_ADMIN')
  async myUnreadNotificationCount(
    @CurrentUser() user: AuthUser,
  ): Promise<number> {
    return this.notifications.countUnread(user.id);
  }

  @Query(() => [NotificationType], { name: 'myNotifications' })
  @Roles('PARENT', 'THERAPIST', 'AGENCY_ADMIN', 'PLATFORM_ADMIN')
  async myNotifications(
    @CurrentUser() user: AuthUser,
  ): Promise<NotificationType[]> {
    const rows = await this.notifications.listForUser(user.id);
    return rows.map((n) => this.mapNotification(n));
  }

  private mapNotification(n: {
    id: string;
    title: string;
    body: string;
    readAt: Date | null;
    sentAt: Date;
    data: unknown;
  }): NotificationType {
    const data =
      n.data && typeof n.data === 'object' && !Array.isArray(n.data)
        ? (n.data as Record<string, unknown>)
        : {};
    const threadId = data.threadId;
    const actionType = data.type;
    const appointmentId = data.appointmentId;
    const sessionId = data.sessionId;
    return {
      id: n.id,
      title: n.title,
      body: n.body,
      readAt: n.readAt ?? undefined,
      sentAt: n.sentAt,
      actionType: typeof actionType === 'string' ? actionType : undefined,
      threadId: typeof threadId === 'string' ? threadId : undefined,
      appointmentId:
        typeof appointmentId === 'string' ? appointmentId : undefined,
      sessionId: typeof sessionId === 'string' ? sessionId : undefined,
    };
  }

  @Mutation(() => NotificationType, { name: 'markNotificationRead' })
  @Roles('PARENT', 'THERAPIST', 'AGENCY_ADMIN', 'PLATFORM_ADMIN')
  async markNotificationRead(
    @CurrentUser() user: AuthUser,
    @Args('id', { type: () => ID }) id: string,
  ): Promise<NotificationType> {
    const n = await this.notifications.markRead(user.id, id);
    return this.mapNotification(n);
  }

  @Mutation(() => Int, { name: 'markAllNotificationsRead' })
  @Roles('PARENT', 'THERAPIST', 'AGENCY_ADMIN', 'PLATFORM_ADMIN')
  async markAllNotificationsRead(
    @CurrentUser() user: AuthUser,
  ): Promise<number> {
    const result = await this.notifications.markAllRead(user.id);
    return result.updated;
  }

  @Query(() => [InsuranceClaimType], { name: 'myInsuranceClaims' })
  @Roles('PARENT')
  async myInsuranceClaims(
    @CurrentUser() user: AuthUser,
  ): Promise<InsuranceClaimType[]> {
    const rows = await this.insurance.listClaimsForParentUser(user.id);
    return rows.map((c) => ({
      id: c.id,
      payerName: c.payerName,
      status: c.status,
      billedAmount: Number(c.billedAmount),
      childName: c.child
        ? `${c.child.firstName} ${c.child.lastName}`
        : undefined,
      serviceDate: c.serviceDate,
    }));
  }

  @Mutation(() => InsuranceClaimType, { name: 'submitInsuranceClaim' })
  @Roles('PARENT')
  async submitInsuranceClaim(
    @CurrentUser() user: AuthUser,
    @Args('input') input: SubmitInsuranceClaimInput,
  ): Promise<InsuranceClaimType> {
    const c = await this.insurance.submitClaim(user.id, input);
    return {
      id: c.id,
      payerName: c.payerName,
      status: c.status,
      billedAmount: Number(c.billedAmount),
      childName: c.child
        ? `${c.child.firstName} ${c.child.lastName}`
        : undefined,
      serviceDate: c.serviceDate,
    };
  }

  @Query(() => [HipaaConsentType], { name: 'myConsents' })
  async myConsents(@CurrentUser() user: AuthUser): Promise<HipaaConsentType[]> {
    const rows = await this.compliance.listConsentsForUser(user.id);
    return rows.map((c) => ({
      id: c.id,
      consentType: c.consentType,
      version: c.version,
      granted: c.granted,
      grantedAt: c.grantedAt,
    }));
  }

  @Mutation(() => HipaaConsentType, { name: 'grantConsent' })
  async grantConsent(
    @CurrentUser() user: AuthUser,
    @Args('input') input: GrantConsentInput,
  ): Promise<HipaaConsentType> {
    const c = await this.compliance.grantConsent(user.id, input);
    return {
      id: c.id,
      consentType: c.consentType,
      version: c.version,
      granted: c.granted,
      grantedAt: c.grantedAt,
    };
  }

  @Mutation(() => Boolean, { name: 'recordEvvCheckIn' })
  @Roles('THERAPIST')
  async recordEvvCheckIn(
    @CurrentUser() user: AuthUser,
    @Args('input') input: RecordEvvInput,
  ): Promise<boolean> {
    await this.gps.recordCheckIn(user.id, input);
    return true;
  }

  @Query(() => SoapSuggestionType, { name: 'suggestSoapNote' })
  @Roles('THERAPIST')
  async suggestSoapNote(
    @Args('input', { nullable: true }) input?: SoapAssistInput,
  ): Promise<SoapSuggestionType> {
    return this.ai.suggestSoapNote({
      therapyType: input?.therapyType,
      childName: input?.childName,
    });
  }

  @Query(() => [AnalyticsMetricType], { name: 'tenantAnalytics' })
  @Roles('PLATFORM_ADMIN', 'AGENCY_ADMIN')
  async tenantAnalytics(
    @CurrentUser() user: AuthUser,
  ): Promise<AnalyticsMetricType[]> {
    if (!user.tenantId) return [];
    const rows = await this.analytics.getTenantMetrics(user.tenantId);
    return rows;
  }

  @Mutation(() => ComplaintType, { name: 'fileComplaint' })
  @Roles('PARENT')
  async fileComplaint(
    @CurrentUser() user: AuthUser,
    @Args('input') input: FileComplaintInput,
  ): Promise<ComplaintType> {
    const c = await this.complaints.fileComplaint(user.id, input);
    return {
      id: c.id,
      status: c.status,
      category: c.category,
      subject: c.subject,
      description: c.description,
      reporterName: `${c.reporter.firstName} ${c.reporter.lastName}`,
    };
  }
}
