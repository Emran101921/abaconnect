import { Args, ID, Mutation, Query, Resolver } from '@nestjs/graphql';
import { Roles } from '../common/decorators/roles.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { AppointmentsService } from '../appointments/appointments.service';
import { ChildrenService } from '../children/children.service';
import { MatchingService } from '../matching/matching.service';
import { ParentsService } from '../parents/parents.service';
import { PrismaService } from '../prisma/prisma.service';
import { ReviewsService } from '../reviews/reviews.service';
import { TherapyType } from '../../generated/prisma/client';
import { ScreeningsService } from '../screenings/screenings.service';
import { SessionsService } from '../sessions/sessions.service';
import {
  BookAppointmentInput,
  BookRecurringAppointmentsInput,
  RescheduleAppointmentInput,
  TherapistDiscoveryInput,
} from './inputs/book-appointment.input';
import {
  AddChildInput,
  SaveScreeningDraftInput,
  SubmitReviewInput,
  SubmitScreeningInput,
  UpdateChildInput,
  UpdateParentProfileInput,
} from './inputs/parent-ext.input';
import {
  AppointmentType,
  ChildType,
  TherapistMatchType,
} from './types/parent-booking.types';
import {
  ParentDashboardType,
  ParentProfileType,
  ReviewType,
  ScreeningResponseType,
  ScreeningTemplateType,
  SessionHistoryType,
  EarlyInterventionEvaluationRequestType,
} from './types/parent-ext.types';

@Resolver()
@Roles('PARENT')
export class ParentBookingResolver {
  constructor(
    private readonly childrenService: ChildrenService,
    private readonly appointmentsService: AppointmentsService,
    private readonly matchingService: MatchingService,
    private readonly parentsService: ParentsService,
    private readonly reviewsService: ReviewsService,
    private readonly screeningsService: ScreeningsService,
    private readonly sessionsService: SessionsService,
    private readonly prisma: PrismaService,
  ) {}

  @Query(() => ParentDashboardType, { name: 'parentDashboard' })
  async parentDashboard(
    @CurrentUser() user: AuthUser,
  ): Promise<ParentDashboardType> {
    const base = await this.parentsService.getDashboardForUserId(user.id);
    const pending = await this.reviewsService.findPendingReviewTherapists(
      user.id,
    );
    return {
      ...base,
      pendingReviews: pending.length,
    };
  }

  @Query(() => ParentProfileType, { name: 'myParentProfile' })
  async myParentProfile(
    @CurrentUser() user: AuthUser,
  ): Promise<ParentProfileType> {
    const p = await this.parentsService.findProfileByUserId(user.id);
    return this.mapParentProfile(p);
  }

  @Mutation(() => ParentProfileType, { name: 'updateParentProfile' })
  async updateParentProfile(
    @CurrentUser() user: AuthUser,
    @Args('input') input: UpdateParentProfileInput,
  ): Promise<ParentProfileType> {
    const p = await this.parentsService.updateProfileByUserId(user.id, input);
    return this.mapParentProfile(p);
  }

  @Query(() => [SessionHistoryType], { name: 'mySessionHistory' })
  async mySessionHistory(
    @CurrentUser() user: AuthUser,
  ): Promise<SessionHistoryType[]> {
    const rows = await this.sessionsService.findHistoryForParentUserId(user.id);
    return rows.map((s) => ({
      id: s.id,
      status: s.status,
      childName: `${s.child.firstName} ${s.child.lastName}`,
      therapistName: `${s.therapist.user.firstName} ${s.therapist.user.lastName}`,
      therapyType: s.appointment.therapyType,
      completedAt: s.checkOutAt ?? s.checkInAt ?? undefined,
      durationMinutes: s.durationMinutes ?? undefined,
      progressNoteSummary: s.progressNote?.summary ?? undefined,
      hasProgressNote: Boolean(s.progressNote?.signedAt),
      parentFeedback: s.progressNote?.parentFeedback ?? undefined,
    }));
  }

  @Query(() => [ChildType], { name: 'myChildren' })
  async myChildren(@CurrentUser() user: AuthUser): Promise<ChildType[]> {
    const rows = await this.childrenService.findByParentUserId(user.id);
    return rows.map((child) => this.mapChild(child));
  }

  @Query(() => [AppointmentType], { name: 'myAppointments' })
  async myAppointments(
    @CurrentUser() user: AuthUser,
  ): Promise<AppointmentType[]> {
    const rows = await this.appointmentsService.findByParentUserId(user.id);
    return rows.map((row) => this.mapAppointment(row));
  }

  @Query(() => [TherapistMatchType], { name: 'recommendedTherapists' })
  async recommendedTherapists(
    @CurrentUser() user: AuthUser,
    @Args('input', { nullable: true }) input?: TherapistDiscoveryInput,
  ): Promise<TherapistMatchType[]> {
    const tenantId = user.tenantId ?? (await this.resolveTenantId(user.id));
    const scored = await this.matchingService.findTherapistsForMatch(
      tenantId,
      input?.therapyType,
      input?.latitude,
      input?.longitude,
      input?.therapyTypes,
    );

    const therapists = await this.prisma.therapist.findMany({
      where: { id: { in: scored.map((s) => s.id) } },
      include: { user: true },
    });

    const byId = new Map(therapists.map((t) => [t.id, t]));
    return scored.map((s) => {
      const t = byId.get(s.id);
      return {
        id: s.id,
        ratingAverage: Number(t?.ratingAverage ?? 0),
        matchScore: s.score,
        user: t?.user
          ? {
              firstName: t.user.firstName,
              lastName: t.user.lastName,
              email: t.user.email,
            }
          : undefined,
      };
    });
  }

  @Mutation(() => AppointmentType, { name: 'bookAppointment' })
  async bookAppointment(
    @CurrentUser() user: AuthUser,
    @Args('input') input: BookAppointmentInput,
  ): Promise<AppointmentType> {
    const row = await this.appointmentsService.bookForParentUser(
      user.id,
      input,
    );
    return this.mapAppointment(row);
  }

  @Mutation(() => [AppointmentType], { name: 'bookRecurringAppointments' })
  async bookRecurringAppointments(
    @CurrentUser() user: AuthUser,
    @Args('input') input: BookRecurringAppointmentsInput,
  ): Promise<AppointmentType[]> {
    const { weeks, ...booking } = input;
    const rows = await this.appointmentsService.bookRecurringForParentUser(
      user.id,
      booking,
      weeks,
    );
    return rows.map((row) => this.mapAppointment(row));
  }

  @Query(() => [TherapistMatchType], { name: 'pendingReviewTherapists' })
  async pendingReviewTherapists(
    @CurrentUser() user: AuthUser,
  ): Promise<TherapistMatchType[]> {
    const rows = await this.reviewsService.findPendingReviewTherapists(user.id);
    return rows.map((t) => ({
      id: t.id,
      ratingAverage: Number(t.ratingAverage ?? 0),
      user: t.user
        ? {
            firstName: t.user.firstName,
            lastName: t.user.lastName,
            email: t.user.email,
          }
        : undefined,
    }));
  }

  @Mutation(() => AppointmentType, { name: 'rescheduleAppointment' })
  async rescheduleAppointment(
    @CurrentUser() user: AuthUser,
    @Args('input') input: RescheduleAppointmentInput,
  ): Promise<AppointmentType> {
    const row = await this.appointmentsService.rescheduleForParentUser(
      user.id,
      input.appointmentId,
      input.scheduledStart,
      input.scheduledEnd,
    );
    return this.mapAppointment(row);
  }

  @Mutation(() => AppointmentType, { name: 'cancelAppointment' })
  async cancelAppointment(
    @CurrentUser() user: AuthUser,
    @Args('id', { type: () => ID }) id: string,
    @Args('reason', { nullable: true }) reason?: string,
  ): Promise<AppointmentType> {
    const row = await this.appointmentsService.cancelForParentUser(
      user.id,
      id,
      reason,
    );
    return this.mapAppointment(row);
  }

  @Mutation(() => ChildType, { name: 'updateChild' })
  async updateChild(
    @CurrentUser() user: AuthUser,
    @Args('input') input: UpdateChildInput,
  ): Promise<ChildType> {
    const child = await this.childrenService.updateForParentUserId(
      user.id,
      input.childId,
      {
        firstName: input.firstName,
        lastName: input.lastName,
        dateOfBirth: input.dateOfBirth,
        gender: input.gender,
        primaryLanguage: input.primaryLanguage,
        guardianName: input.guardianName,
        guardianPhone: input.guardianPhone,
        guardianEmail: input.guardianEmail,
        addressLine1: input.addressLine1,
        zipCode: input.zipCode,
        pediatricianName: input.pediatricianName,
        insuranceType: input.insuranceType,
        hadEarlyIntervention: input.hadEarlyIntervention,
        notes: input.notes,
      },
    );
    return this.mapChild(child);
  }

  @Mutation(() => ChildType, { name: 'addChild' })
  async addChild(
    @CurrentUser() user: AuthUser,
    @Args('input') input: AddChildInput,
  ): Promise<ChildType> {
    const child = await this.childrenService.createForParentUserId(user.id, {
      firstName: input.firstName,
      lastName: input.lastName,
      dateOfBirth: input.dateOfBirth,
      gender: input.gender,
      primaryLanguage: input.primaryLanguage,
      guardianName: input.guardianName,
      guardianPhone: input.guardianPhone,
      guardianEmail: input.guardianEmail,
      addressLine1: input.addressLine1,
      zipCode: input.zipCode,
      pediatricianName: input.pediatricianName,
      insuranceType: input.insuranceType,
      hadEarlyIntervention: input.hadEarlyIntervention,
    });
    return this.mapChild(child);
  }

  @Query(() => [ReviewType], { name: 'myReviews' })
  async myReviews(@CurrentUser() user: AuthUser): Promise<ReviewType[]> {
    const rows = await this.reviewsService.findByParentUserId(user.id);
    return rows.map((r) => ({
      id: r.id,
      rating: r.rating,
      title: r.title ?? undefined,
      comment: r.comment ?? undefined,
      createdAt: r.createdAt,
      therapistUser: r.therapist?.user
        ? {
            firstName: r.therapist.user.firstName,
            lastName: r.therapist.user.lastName,
            email: r.therapist.user.email,
          }
        : undefined,
    }));
  }

  @Mutation(() => ReviewType, { name: 'submitReview' })
  async submitReview(
    @CurrentUser() user: AuthUser,
    @Args('input') input: SubmitReviewInput,
  ): Promise<ReviewType> {
    const r = await this.reviewsService.createForParentUserId(user.id, input);
    return {
      id: r.id,
      rating: r.rating,
      title: r.title ?? undefined,
      comment: r.comment ?? undefined,
      createdAt: r.createdAt,
      therapistUser: r.therapist?.user
        ? {
            firstName: r.therapist.user.firstName,
            lastName: r.therapist.user.lastName,
            email: r.therapist.user.email,
          }
        : undefined,
    };
  }

  @Query(() => [ScreeningTemplateType], { name: 'screeningTemplates' })
  async screeningTemplates(
    @CurrentUser() user: AuthUser,
  ): Promise<ScreeningTemplateType[]> {
    const tenantId = user.tenantId ?? (await this.resolveTenantId(user.id));
    const rows = await this.screeningsService.listTemplatesForTenant(tenantId);
    return rows.map((t) => ({
      id: t.id,
      name: t.name,
      therapyType: t.therapyType,
      version: String(t.version),
      questionsJson: JSON.stringify(t.questions),
    }));
  }

  @Query(() => [ScreeningResponseType], { name: 'myScreeningHistory' })
  async myScreeningHistory(
    @CurrentUser() user: AuthUser,
  ): Promise<ScreeningResponseType[]> {
    const rows = await this.screeningsService.listHistoryForParentUser(user.id);
    return rows.map((r) => this.mapScreeningResponse(r));
  }

  @Query(() => ScreeningResponseType, { name: 'myScreeningResult' })
  async myScreeningResult(
    @CurrentUser() user: AuthUser,
    @Args('id', { type: () => ID }) id: string,
  ): Promise<ScreeningResponseType> {
    const row = await this.screeningsService.getResponseForParent(user.id, id);
    return this.mapScreeningResponse(row);
  }

  @Query(() => ScreeningResponseType, {
    name: 'myScreeningDraft',
    nullable: true,
  })
  async myScreeningDraft(
    @CurrentUser() user: AuthUser,
    @Args('templateId', { type: () => ID }) templateId: string,
    @Args('childId', { type: () => ID }) childId: string,
  ): Promise<ScreeningResponseType | null> {
    const row = await this.screeningsService.getDraftForParent(
      user.id,
      templateId,
      childId,
    );
    return row ? this.mapScreeningResponse(row) : null;
  }

  @Mutation(() => ScreeningResponseType, { name: 'saveScreeningDraft' })
  async saveScreeningDraft(
    @CurrentUser() user: AuthUser,
    @Args('input') input: SaveScreeningDraftInput,
  ): Promise<ScreeningResponseType> {
    const responses = this.parseResponsesJson(input.responsesJson);
    const row = await this.screeningsService.saveDraftForParent(user.id, {
      templateId: input.templateId,
      childId: input.childId,
      responses,
      draftId: input.draftId,
    });
    return this.mapScreeningResponse(row);
  }

  @Mutation(() => ScreeningResponseType, { name: 'submitScreening' })
  async submitScreening(
    @CurrentUser() user: AuthUser,
    @Args('input') input: SubmitScreeningInput,
  ): Promise<ScreeningResponseType> {
    const responses = this.parseResponsesJson(input.responsesJson);
    const row = await this.screeningsService.submitResponseForParent(
      user.id,
      {
        templateId: input.templateId,
        childId: input.childId,
        responses,
        consentGranted: input.consentGranted,
        draftId: input.draftId,
      },
      user.id,
    );
    return this.mapScreeningResponse(row);
  }

  @Mutation(() => EarlyInterventionEvaluationRequestType, {
    name: 'requestEarlyInterventionEvaluation',
  })
  async requestEarlyInterventionEvaluation(
    @CurrentUser() user: AuthUser,
    @Args('screeningResponseId', { type: () => ID }) screeningResponseId: string,
  ): Promise<EarlyInterventionEvaluationRequestType> {
    const result = await this.screeningsService.requestEarlyInterventionEvaluation(
      user.id,
      screeningResponseId,
    );
    return {
      id: result.id,
      screeningResponseId: result.screeningResponseId,
      childId: result.childId,
      requestedAt: result.requestedAt,
      serviceCodes: result.serviceCodes,
    };
  }

  private parseResponsesJson(responsesJson: string) {
    try {
      return JSON.parse(responsesJson) as Record<string, unknown>;
    } catch {
      return { raw: responsesJson };
    }
  }

  private mapChild(child: {
    id: string;
    firstName: string;
    lastName: string;
    dateOfBirth: Date;
    gender?: string | null;
    primaryLanguage?: string | null;
    guardianName?: string | null;
    guardianPhone?: string | null;
    guardianEmail?: string | null;
    addressLine1?: string | null;
    zipCode?: string | null;
    pediatricianName?: string | null;
    insuranceType?: string | null;
    hadEarlyIntervention?: boolean | null;
  }): ChildType {
    return {
      id: child.id,
      firstName: child.firstName,
      lastName: child.lastName,
      dateOfBirth: child.dateOfBirth,
      gender: child.gender ?? undefined,
      primaryLanguage: child.primaryLanguage ?? undefined,
      guardianName: child.guardianName ?? undefined,
      guardianPhone: child.guardianPhone ?? undefined,
      guardianEmail: child.guardianEmail ?? undefined,
      addressLine1: child.addressLine1 ?? undefined,
      zipCode: child.zipCode ?? undefined,
      pediatricianName: child.pediatricianName ?? undefined,
      insuranceType: child.insuranceType ?? undefined,
      hadEarlyIntervention: child.hadEarlyIntervention ?? undefined,
    };
  }

  private mapScreeningResponse(r: {
    id: string;
    completedAt: Date;
    score?: unknown | null;
    riskLevel?: string | null;
    recommendations?: unknown;
    responses?: unknown;
    isDraft?: boolean;
    consentGrantedAt?: Date | null;
    template?: {
      id: string;
      name: string;
      therapyType: TherapyType;
      version: number | string;
    } | null;
    child?: { firstName: string; lastName: string } | null;
  }): ScreeningResponseType {
    const template = r.template;
    return {
      id: r.id,
      completedAt: r.completedAt,
      score: r.score != null ? Number(r.score) : undefined,
      riskLevel: r.riskLevel ?? undefined,
      recommendationsJson: JSON.stringify(r.recommendations ?? []),
      responsesJson: JSON.stringify(r.responses ?? {}),
      isDraft: r.isDraft ?? false,
      consentGrantedAt: r.consentGrantedAt ?? undefined,
      childName: r.child
        ? `${r.child.firstName} ${r.child.lastName}`
        : undefined,
      templateName: template?.name,
      template: template
        ? {
            id: template.id,
            name: template.name,
            therapyType: template.therapyType,
            version: String(template.version),
          }
        : undefined,
    };
  }

  private mapParentProfile(p: {
    id: string;
    addressLine1?: string | null;
    city?: string | null;
    state?: string | null;
    zipCode?: string | null;
    emergencyContactName?: string | null;
    emergencyContactPhone?: string | null;
    insuranceProvider?: string | null;
    insuranceMemberId?: string | null;
    insuranceGroupNumber?: string | null;
    user: { email: string; firstName: string; lastName: string };
  }): ParentProfileType {
    return {
      id: p.id,
      addressLine1: p.addressLine1 ?? undefined,
      city: p.city ?? undefined,
      state: p.state ?? undefined,
      zipCode: p.zipCode ?? undefined,
      emergencyContactName: p.emergencyContactName ?? undefined,
      emergencyContactPhone: p.emergencyContactPhone ?? undefined,
      insuranceProvider: p.insuranceProvider ?? undefined,
      insuranceMemberId: p.insuranceMemberId ?? undefined,
      insuranceGroupNumber: p.insuranceGroupNumber ?? undefined,
      email: p.user.email,
      firstName: p.user.firstName,
      lastName: p.user.lastName,
    };
  }

  private async resolveTenantId(userId: string): Promise<string> {
    const u = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!u) {
      throw new Error('User not found');
    }
    return u.tenantId;
  }

  private mapAppointment(row: {
    id: string;
    status: string;
    therapyType: string;
    scheduledStart: Date;
    scheduledEnd: Date;
    locationType?: string;
    child?: {
      id: string;
      firstName: string;
      lastName: string;
      dateOfBirth: Date;
    };
    therapist?: {
      id: string;
      ratingAverage: unknown;
      user?: { firstName: string; lastName: string; email: string };
    };
  }): AppointmentType {
    return {
      id: row.id,
      status: row.status,
      therapyType: row.therapyType as AppointmentType['therapyType'],
      scheduledStart: row.scheduledStart,
      scheduledEnd: row.scheduledEnd,
      locationType: row.locationType as AppointmentType['locationType'],
      child: row.child,
      therapist: row.therapist
        ? {
            id: row.therapist.id,
            ratingAverage: Number(row.therapist.ratingAverage),
            user: row.therapist.user,
          }
        : undefined,
    };
  }
}
