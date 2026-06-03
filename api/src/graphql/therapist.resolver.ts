import { Args, ID, Mutation, Query, Resolver } from '@nestjs/graphql';
import { Roles } from '../common/decorators/roles.decorator';
import { AuthUser, CurrentUser } from '../common/decorators/current-user.decorator';
import { SessionsService } from '../sessions/sessions.service';
import { TherapistsService } from '../therapists/therapists.service';
import { SaveSoapNoteInput, UpdateTherapistProfileInput } from './inputs/therapist.inputs';
import {
  SoapNoteType,
  TherapistAppointmentType,
  TherapistProfileType,
  TherapistSessionType,
} from './types/therapist.types';

@Resolver()
@Roles('THERAPIST')
export class TherapistResolver {
  constructor(
    private readonly therapistsService: TherapistsService,
    private readonly sessionsService: SessionsService,
  ) {}

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
    return rows.map((a) => ({
      id: a.id,
      status: a.status,
      therapyType: a.therapyType,
      scheduledStart: a.scheduledStart,
      scheduledEnd: a.scheduledEnd,
      child: {
        id: a.child.id,
        firstName: a.child.firstName,
        lastName: a.child.lastName,
        dateOfBirth: a.child.dateOfBirth,
      },
    }));
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
          }
        : undefined,
    }));
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
    };
  }
}
