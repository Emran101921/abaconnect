import { NotFoundException } from '@nestjs/common';
import { Args, ID, Mutation, Query, Resolver } from '@nestjs/graphql';
import { LocationType, TherapyType } from '../../generated/prisma/client';
import { Roles } from '../common/decorators/roles.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../common/decorators/current-user.decorator';
import { AppointmentsService, isAppointmentOperationallyConfirmed } from '../appointments/appointments.service';
import { isSelfPayInsuranceType } from '../payments/self-pay.util';
import { PaymentsService } from '../payments/payments.service';
import { isEipFormFullySigned } from '../sessions/eip-form.util';
import { SessionsService } from '../sessions/sessions.service';
import { ProviderOnboardingService } from '../compliance/provider-onboarding.service';
import { TherapistsService } from '../therapists/therapists.service';
import { RequestRescheduleAppointmentInput } from './inputs/book-appointment.input';
import {
  SaveSoapNoteInput,
  UpdateTherapistProfileInput,
} from './inputs/therapist.inputs';
import {
  ServiceLogType,
  SessionNoteFormContextType,
  SoapNoteType,
  TherapistAppointmentType,
  TherapistCaseloadChartType,
  ProviderOnboardingChecklistType,
  TherapistDashboardType,
  TherapistProfileType,
  TherapistSessionType,
} from './types/therapist.types';
import { PaymentIntentResultType } from './types/payments.types';

@Resolver()
@Roles('THERAPIST')
export class TherapistResolver {
  constructor(
    private readonly therapistsService: TherapistsService,
    private readonly sessionsService: SessionsService,
    private readonly appointmentsService: AppointmentsService,
    private readonly providerOnboarding: ProviderOnboardingService,
    private readonly paymentsService: PaymentsService,
  ) {}

  @Query(() => ProviderOnboardingChecklistType, {
    name: 'providerOnboardingChecklist',
  })
  async providerOnboardingChecklist(
    @CurrentUser() user: AuthUser,
  ): Promise<ProviderOnboardingChecklistType> {
    const checklist = await this.providerOnboarding.getChecklist(user.id);
    if (!checklist) {
      throw new NotFoundException('Provider profile not found');
    }
    return checklist;
  }

  @Mutation(() => ProviderOnboardingChecklistType, {
    name: 'attestHipaaTraining',
  })
  async attestHipaaTraining(
    @CurrentUser() user: AuthUser,
  ): Promise<ProviderOnboardingChecklistType> {
    await this.providerOnboarding.attestHipaaTraining(user.id);
    return (await this.providerOnboarding.getChecklist(user.id))!;
  }

  @Mutation(() => ProviderOnboardingChecklistType, {
    name: 'attestConfidentialityAgreement',
  })
  async attestConfidentialityAgreement(
    @CurrentUser() user: AuthUser,
  ): Promise<ProviderOnboardingChecklistType> {
    await this.providerOnboarding.attestConfidentialityAgreement(user.id);
    return (await this.providerOnboarding.getChecklist(user.id))!;
  }

  @Mutation(() => ProviderOnboardingChecklistType, {
    name: 'submitProviderOnboarding',
  })
  async submitProviderOnboarding(
    @CurrentUser() user: AuthUser,
  ): Promise<ProviderOnboardingChecklistType> {
    await this.providerOnboarding.submitForReview(user.id);
    return (await this.providerOnboarding.getChecklist(user.id))!;
  }

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

  @Query(() => [TherapistCaseloadChartType], {
    name: 'myTherapistCaseloadCharts',
  })
  async myTherapistCaseloadCharts(
    @CurrentUser() user: AuthUser,
  ): Promise<TherapistCaseloadChartType[]> {
    const rows = await this.therapistsService.findCaseloadChartsByUserId(
      user.id,
    );
    return rows.map((row) => ({
      ...row,
      therapyTypes: row.therapyTypes as TherapyType[],
    }));
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
      serviceLog: this.mapServiceLog(s.serviceLog, s.child),
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

  @Mutation(() => TherapistAppointmentType, { name: 'requestRescheduleAppointment' })
  async requestRescheduleAppointment(
    @CurrentUser() user: AuthUser,
    @Args('input') input: RequestRescheduleAppointmentInput,
  ): Promise<TherapistAppointmentType> {
    const row = await this.appointmentsService.requestRescheduleForUser(
      user.id,
      input.appointmentId,
      input.proposedStart,
      input.proposedEnd,
      input.reason,
    );
    return this.mapAppointment(row as Parameters<typeof this.mapAppointment>[0]);
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
    return this.mapAppointment(row as Parameters<typeof this.mapAppointment>[0]);
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
    return this.mapAppointment(row as Parameters<typeof this.mapAppointment>[0]);
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
    return this.mapAppointment(row as Parameters<typeof this.mapAppointment>[0]);
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

  @Mutation(() => TherapistAppointmentType, { name: 'recordTherapistArrival' })
  async recordTherapistArrival(
    @CurrentUser() user: AuthUser,
    @Args('appointmentId', { type: () => ID }) appointmentId: string,
  ): Promise<TherapistAppointmentType> {
    const row = await this.sessionsService.recordTherapistArrival(
      user.id,
      appointmentId,
    );
    return this.mapAppointment(row as Parameters<typeof this.mapAppointment>[0]);
  }

  @Mutation(() => PaymentIntentResultType, { name: 'requestSessionPayment' })
  async requestSessionPayment(
    @CurrentUser() user: AuthUser,
    @Args('appointmentId', { type: () => ID }) appointmentId: string,
  ): Promise<PaymentIntentResultType> {
    const result = await this.paymentsService.requestSessionChargeForTherapist(
      user.id,
      appointmentId,
    );
    return {
      payment: {
        id: result.payment.id,
        amount: Number(result.payment.amount),
        currency: result.payment.currency,
        status: result.payment.status,
        description: result.payment.description ?? undefined,
        paidAt: result.payment.paidAt ?? undefined,
        createdAt: result.payment.createdAt,
      },
      clientSecret: result.clientSecret ?? undefined,
      checkoutUrl: result.checkoutUrl ?? undefined,
      stripeConfigured: result.stripeConfigured,
      alreadyPaid: result.alreadyPaid ?? undefined,
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
    const serviceLog = await this.sessionsService.findServiceLogBySessionId(
      input.sessionId,
    );
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
      serviceLog: serviceLog
        ? this.mapServiceLog(serviceLog, serviceLog.session.child)
        : undefined,
    };
  }

  private mapServiceLog(
    log: {
      id: string;
      therapistSignatureName: string | null;
      therapistSignedAt: Date | null;
      parentSignatureName: string | null;
      parentSignatureDate: string | null;
      parentSignedAt: Date | null;
      logData: unknown;
    } | null,
    child?: { firstName: string; lastName: string },
  ): ServiceLogType | undefined {
    if (!log) return undefined;
    const data = log.logData as Record<string, unknown> | null;
    const childName =
      typeof data?.childName === 'string'
        ? data.childName
        : child
          ? `${child.firstName} ${child.lastName}`
          : '';
    return {
      id: log.id,
      therapistSignatureName: log.therapistSignatureName ?? undefined,
      therapistSignedAt: log.therapistSignedAt?.toISOString(),
      parentSignatureName: log.parentSignatureName ?? undefined,
      parentSignatureDate: log.parentSignatureDate ?? undefined,
      parentSignedAt: log.parentSignedAt?.toISOString(),
      childName,
    };
  }

  private mapAppointment(row: {
    id: string;
    status: string;
    therapyType: string;
    scheduledStart: Date;
    scheduledEnd: Date;
    locationType?: string | null;
    confirmationStatus?: string;
    parentConfirmedAt?: Date | null;
    therapistConfirmedAt?: Date | null;
    rescheduleRequestedBy?: string | null;
    proposedScheduledStart?: Date | null;
    proposedScheduledEnd?: Date | null;
    rescheduleReason?: string | null;
    child: {
      id: string;
      firstName: string;
      lastName: string;
      dateOfBirth: Date;
      insuranceType?: string | null;
    };
    parent?: {
      user: { id: string; firstName: string; lastName: string };
    };
    session?: {
      payment?: {
        id: string;
        status: string;
        amount: unknown;
      } | null;
    } | null;
    bookingPayment?: {
      id: string;
      status: string;
      amount: unknown;
    } | null;
  }): TherapistAppointmentType {
    const requiresSelfPay = isSelfPayInsuranceType(row.child.insuranceType);
    const sessionPayment = row.session?.payment;
    const bookingPayment = row.bookingPayment;
    const paymentSucceeded =
      sessionPayment?.status === 'SUCCEEDED' ||
      bookingPayment?.status === 'SUCCEEDED';
    const outstandingPayment = sessionPayment ?? bookingPayment ?? null;
    const succeededPayment =
      sessionPayment?.status === 'SUCCEEDED'
        ? sessionPayment
        : bookingPayment?.status === 'SUCCEEDED'
          ? bookingPayment
          : null;
    const hasArrived = ['CHECKED_IN', 'IN_PROGRESS', 'COMPLETED'].includes(
      row.status,
    );
    const canStartSession = requiresSelfPay
      ? hasArrived && paymentSucceeded
      : isAppointmentOperationallyConfirmed(row) ||
        ['CHECKED_IN', 'IN_PROGRESS'].includes(row.status);

    return {
      id: row.id,
      status: row.status,
      therapyType: row.therapyType as TherapyType,
      scheduledStart: row.scheduledStart,
      scheduledEnd: row.scheduledEnd,
      locationType: row.locationType
        ? (row.locationType as LocationType)
        : undefined,
      confirmationStatus:
        (row.confirmationStatus as TherapistAppointmentType['confirmationStatus']) ??
        'PENDING',
      parentConfirmedAt: row.parentConfirmedAt ?? undefined,
      therapistConfirmedAt: row.therapistConfirmedAt ?? undefined,
      rescheduleRequestedBy: row.rescheduleRequestedBy ?? undefined,
      proposedScheduledStart: row.proposedScheduledStart ?? undefined,
      proposedScheduledEnd: row.proposedScheduledEnd ?? undefined,
      rescheduleReason: row.rescheduleReason ?? undefined,
      child: {
        id: row.child.id,
        firstName: row.child.firstName,
        lastName: row.child.lastName,
        dateOfBirth: row.child.dateOfBirth,
        insuranceType: row.child.insuranceType ?? undefined,
      },
      childInsuranceType: row.child.insuranceType ?? undefined,
      requiresSelfPayCollection: requiresSelfPay,
      hasArrived,
      canStartSession,
      sessionPaymentId: paymentSucceeded
        ? succeededPayment?.id
        : outstandingPayment?.id,
      sessionPaymentStatus: paymentSucceeded
        ? 'SUCCEEDED'
        : outstandingPayment?.status,
      sessionPaymentAmount: paymentSucceeded
        ? Number(succeededPayment?.amount ?? 0)
        : outstandingPayment
          ? Number(outstandingPayment.amount)
          : undefined,
      parentUserId: row.parent?.user.id,
      parentName: row.parent
        ? `${row.parent.user.firstName} ${row.parent.user.lastName}`
        : undefined,
    };
  }
}
