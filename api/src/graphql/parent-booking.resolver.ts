import { Args, ID, Mutation, Query, Resolver } from '@nestjs/graphql';
import { Roles } from '../common/decorators/roles.decorator';
import { AuthUser, CurrentUser } from '../common/decorators/current-user.decorator';
import { AppointmentsService } from '../appointments/appointments.service';
import { ChildrenService } from '../children/children.service';
import { MatchingService } from '../matching/matching.service';
import { PrismaService } from '../prisma/prisma.service';
import { BookAppointmentInput, TherapistDiscoveryInput } from './inputs/book-appointment.input';
import {
  AppointmentType,
  ChildType,
  TherapistMatchType,
} from './types/parent-booking.types';

@Resolver()
@Roles('PARENT')
export class ParentBookingResolver {
  constructor(
    private readonly childrenService: ChildrenService,
    private readonly appointmentsService: AppointmentsService,
    private readonly matchingService: MatchingService,
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
