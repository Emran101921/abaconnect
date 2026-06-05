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
    }));
  }

  @Query(() => [ChildType], { name: 'myChildren' })
  async myChildren(@CurrentUser() user: AuthUser): Promise<ChildType[]> {
    return this.childrenService.findByParentUserId(user.id);
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
        notes: input.notes,
      },
    );
    return {
      id: child.id,
      firstName: child.firstName,
      lastName: child.lastName,
      dateOfBirth: child.dateOfBirth,
    };
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
    });
    return {
      id: child.id,
      firstName: child.firstName,
      lastName: child.lastName,
      dateOfBirth: child.dateOfBirth,
    };
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

  @Mutation(() => ScreeningResponseType, { name: 'submitScreening' })
  async submitScreening(
    @CurrentUser() user: AuthUser,
    @Args('input') input: SubmitScreeningInput,
  ): Promise<ScreeningResponseType> {
    let responses: Record<string, unknown> = {};
    try {
      responses = JSON.parse(input.responsesJson) as Record<string, unknown>;
    } catch {
      responses = { raw: input.responsesJson };
    }
    const row = await this.screeningsService.submitResponseForParent(user.id, {
      templateId: input.templateId,
      childId: input.childId,
      responses,
    });
    const template = 'template' in row ? row.template : null;
    return {
      id: row.id,
      completedAt: row.completedAt,
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
