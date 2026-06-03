import { Args, ID, Mutation, Query, Resolver } from '@nestjs/graphql';
import { Roles } from '../common/decorators/roles.decorator';
import { AuthUser, CurrentUser } from '../common/decorators/current-user.decorator';
import { AppointmentsService } from '../appointments/appointments.service';
import { ChildrenService } from '../children/children.service';
import { MatchingService } from '../matching/matching.service';
import { PrismaService } from '../prisma/prisma.service';
import { ReviewsService } from '../reviews/reviews.service';
import { ScreeningsService } from '../screenings/screenings.service';
import { BookAppointmentInput, TherapistDiscoveryInput } from './inputs/book-appointment.input';
import {
  AddChildInput,
  SubmitReviewInput,
  SubmitScreeningInput,
} from './inputs/parent-ext.input';
import {
  AppointmentType,
  ChildType,
  TherapistMatchType,
} from './types/parent-booking.types';
import {
  ReviewType,
  ScreeningResponseType,
  ScreeningTemplateType,
} from './types/parent-ext.types';

@Resolver()
@Roles('PARENT')
export class ParentBookingResolver {
  constructor(
    private readonly childrenService: ChildrenService,
    private readonly appointmentsService: AppointmentsService,
    private readonly matchingService: MatchingService,
    private readonly reviewsService: ReviewsService,
    private readonly screeningsService: ScreeningsService,
    private readonly prisma: PrismaService,
  ) {}

  @Query(() => [ChildType], { name: 'myChildren' })
  async myChildren(@CurrentUser() user: AuthUser): Promise<ChildType[]> {
    return this.childrenService.findByParentUserId(user.id);
  }

  @Query(() => [AppointmentType], { name: 'myAppointments' })
  async myAppointments(@CurrentUser() user: AuthUser): Promise<AppointmentType[]> {
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
    const row = await this.appointmentsService.bookForParentUser(user.id, input);
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
    child?: { id: string; firstName: string; lastName: string; dateOfBirth: Date };
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
