import { Args, ID, Mutation, Query, Resolver } from '@nestjs/graphql';
import { LocationType, TherapyType } from '../../generated/prisma/client';
import { Roles } from '../common/decorators/roles.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { AppointmentsService } from '../appointments/appointments.service';
import { isEipFormFullySigned } from '../sessions/eip-form.util';
import { SessionsService } from '../sessions/sessions.service';
import { TherapistsService } from '../therapists/therapists.service';
import {
  SaveSoapNoteInput,
  UpdateTherapistProfileInput,
} from './inputs/therapist.inputs';
import {
  SessionNoteFormContextType,
  SoapNoteType,
  TherapistAppointmentType,
  TherapistDashboardType,
  TherapistProfileType,
  TherapistSessionType,
} from './types/therapist.types';

@Resolver()
@Roles('THERAPIST')
export class TherapistResolver {
  constructor(
    private readonly therapistsService: TherapistsService,
    private readonly sessionsService: SessionsService,
    private readonly appointmentsService: AppointmentsService,
  ) {}

  @Query(() => TherapistDashboardType, { name: 'therapistDashboard' })
  async therapistDashboard(
    @CurrentUser() user: AuthUser,
  ): Promise<TherapistDashboardType> {
    return this.therapistsService.getDashboardForUserId(user.id);
  }

  @Query(() => TherapistProfileType, { name: 'myTherapistProfile' })
  async myTherapistProfile(
    @CurrentUser() user: AuthUser,
  ): Promise<TherapistProfileType> {
    const t = await this.therapistsService.findByUserId(user.id);
    return {
      id: t.id,
      isVerified: t.isVerified,
      therapyTypes: t.therapyTypes,
      bio: t.bio ?? undefined,
      npi: t.npi ?? undefined,
      licenseNumber: t.licenseNumber ?? undefined,
      licenseState: t.licenseState ?? undefined,
      yearsExperience: t.yearsExperience ?? undefined,
      ratingAverage: Number(t.ratingAverage),
      ratingCount: t.ratingCount,
      user: {
        firstName: t.user.firstName,
        lastName: t.user.lastName,
        email: t.user.email,
      },
    };
  }

  @Query(() => [TherapistAppointmentType], { name: 'myTherapistAppointments' })
  async myTherapistAppointments(
    @CurrentUser() user: AuthUser,
  ): Promise<TherapistAppointmentType[]> {
    const rows = await this.therapistsService.findAppointmentsByUserId(user.id);
    return rows.map((a) => this.mapAppointment(a));
  }

  @Query(() => [TherapistSessionType], { name: 'myTherapistSessions' })
  async myTherapistSessions(
    @CurrentUser() user: AuthUser,
  ): Promise<TherapistSessionType[]> {
    const rows = await this.sessionsService.findByTherapistUserId(user.id);
    return rows.map((s) => ({
      id: s.id,
      status: s.status,
      child: {
        id: s.child.id,
        firstName: s.child.firstName,
        lastName: s.child.lastName,
        dateOfBirth: s.child.dateOfBirth,
      },
      soapNote: s.soapNote
        ? {
            id: s.soapNote.id,
            subjective: s.soapNote.subjective ?? undefined,
            objective: s.soapNote.objective ?? undefined,
            assessment: s.soapNote.assessment ?? undefined,
            plan: s.soapNote.plan ?? undefined,
            eipFormData:
              s.soapNote.eipFormData != null
                ? JSON.stringify(s.soapNote.eipFormData)
                : undefined,
            eipFormFullySigned:
              s.soapNote.signedAt != null ||
              isEipFormFullySigned(
                s.soapNote.eipFormData as Record<string, unknown> | null,
              ),
          }
        : undefined,
    }));
  }

  @Query(() => SessionNoteFormContextType, { name: 'sessionNoteFormContext' })
  async sessionNoteFormContext(
    @CurrentUser() user: AuthUser,
    @Args('sessionId', { type: () => ID }) sessionId: string,
  ): Promise<SessionNoteFormContextType> {
    return this.sessionsService.getSessionNoteFormContext(user.id, sessionId);
  }

  @Mutation(() => TherapistProfileType, { name: 'updateTherapistProfile' })
  async updateTherapistProfile(
    @CurrentUser() user: AuthUser,
    @Args('input') input: UpdateTherapistProfileInput,
  ): Promise<TherapistProfileType> {
    const t = await this.therapistsService.updateByUserId(user.id, input);
    return {
      id: t.id,
      isVerified: t.isVerified,
      therapyTypes: t.therapyTypes,
      bio: t.bio ?? undefined,
      npi: t.npi ?? undefined,
      licenseNumber: t.licenseNumber ?? undefined,
      licenseState: t.licenseState ?? undefined,
      yearsExperience: t.yearsExperience ?? undefined,
      ratingAverage: Number(t.ratingAverage),
      ratingCount: t.ratingCount,
      user: {
        firstName: t.user.firstName,
        lastName: t.user.lastName,
        email: t.user.email,
      },
    };
  }

  @Mutation(() => TherapistAppointmentType, { name: 'confirmAppointment' })
  async confirmAppointment(
    @CurrentUser() user: AuthUser,
    @Args('appointmentId', { type: () => ID }) appointmentId: string,
  ): Promise<TherapistAppointmentType> {
    const row = await this.appointmentsService.respondForTherapistUserId(
      user.id,
      appointmentId,
      'CONFIRM',
    );
    return this.mapAppointment(row);
  }

  @Mutation(() => TherapistAppointmentType, {
    name: 'cancelAppointmentAsTherapist',
  })
  async cancelAppointmentAsTherapist(
    @CurrentUser() user: AuthUser,
    @Args('appointmentId', { type: () => ID }) appointmentId: string,
    @Args('reason', { nullable: true }) reason?: string,
  ): Promise<TherapistAppointmentType> {
    const row = await this.appointmentsService.cancelForTherapistUser(
      user.id,
      appointmentId,
      reason,
    );
    return this.mapAppointment(row);
  }

  @Mutation(() => TherapistAppointmentType, { name: 'declineAppointment' })
  async declineAppointment(
    @CurrentUser() user: AuthUser,
    @Args('appointmentId', { type: () => ID }) appointmentId: string,
    @Args('reason', { nullable: true }) reason?: string,
  ): Promise<TherapistAppointmentType> {
    const row = await this.appointmentsService.respondForTherapistUserId(
      user.id,
      appointmentId,
      'DECLINE',
      reason,
    );
    return this.mapAppointment(row);
  }

  @Mutation(() => TherapistSessionType, { name: 'completeSession' })
  async completeSession(
    @CurrentUser() user: AuthUser,
    @Args('sessionId', { type: () => ID }) sessionId: string,
  ): Promise<TherapistSessionType> {
    const s = await this.sessionsService.completeSessionForTherapist(
      user.id,
      sessionId,
    );
    return {
      id: s.id,
      status: s.status,
      child: {
        id: s.child.id,
        firstName: s.child.firstName,
        lastName: s.child.lastName,
        dateOfBirth: s.child.dateOfBirth,
      },
      soapNote: undefined,
    };
  }

  @Mutation(() => TherapistSessionType, { name: 'startSession' })
  async startSession(
    @CurrentUser() user: AuthUser,
    @Args('appointmentId', { type: () => ID }) appointmentId: string,
  ): Promise<TherapistSessionType> {
    const s = await this.sessionsService.ensureSessionForAppointment(
      user.id,
      appointmentId,
    );
    return {
      id: s.id,
      status: s.status,
      child: {
        id: s.child.id,
        firstName: s.child.firstName,
        lastName: s.child.lastName,
        dateOfBirth: s.child.dateOfBirth,
      },
      soapNote: undefined,
    };
  }

  @Mutation(() => SoapNoteType, { name: 'saveSoapNote' })
  async saveSoapNote(
    @CurrentUser() user: AuthUser,
    @Args('input') input: SaveSoapNoteInput,
  ): Promise<SoapNoteType> {
    const note = await this.sessionsService.saveSoapNote(user.id, input);
    return {
      id: note.id,
      subjective: note.subjective ?? undefined,
      objective: note.objective ?? undefined,
      assessment: note.assessment ?? undefined,
      plan: note.plan ?? undefined,
      eipFormData:
        note.eipFormData != null ? JSON.stringify(note.eipFormData) : undefined,
      eipFormFullySigned:
        note.signedAt != null ||
        isEipFormFullySigned(
          note.eipFormData as Record<string, unknown> | null,
        ),
    };
  }

  private mapAppointment(row: {
    id: string;
    status: string;
    therapyType: string;
    scheduledStart: Date;
    scheduledEnd: Date;
    locationType?: string | null;
    child: {
      id: string;
      firstName: string;
      lastName: string;
      dateOfBirth: Date;
    };
  }): TherapistAppointmentType {
    return {
      id: row.id,
      status: row.status,
      therapyType: row.therapyType as TherapyType,
      scheduledStart: row.scheduledStart,
      scheduledEnd: row.scheduledEnd,
      locationType: row.locationType
        ? (row.locationType as LocationType)
        : undefined,
      child: {
        id: row.child.id,
        firstName: row.child.firstName,
        lastName: row.child.lastName,
        dateOfBirth: row.child.dateOfBirth,
      },
    };
  }
}
