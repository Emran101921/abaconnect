import {
  BadRequestException,
  ForbiddenException,
  Inject,
  Injectable,
  Logger,
  NotFoundException,
  forwardRef,
} from '@nestjs/common';
import {
  AppointmentConfirmationStatus,
  LocationType,
  TherapyType,
} from '../../generated/prisma/client';
import { NotificationsService } from '../notifications/notifications.service';
import { isSelfPayInsuranceType } from '../payments/self-pay.util';
import { PaymentsService } from '../payments/payments.service';
import { PrismaService } from '../prisma/prisma.service';
import { SmsService } from '../sms/sms.service';
import { ACTIVE_APPOINTMENT_STATUSES } from './schedule-overlap.util';

export interface BookAppointmentInput {
  childId: string;
  therapistId: string;
  therapyType: TherapyType;
  scheduledStart: Date;
  scheduledEnd: Date;
  notes?: string;
  locationType?: LocationType;
}

type AppointmentActorRole = 'PARENT' | 'THERAPIST' | 'AGENCY';

type AppointmentWithParties = {
  id: string;
  childId: string;
  therapistId: string;
  therapyType: string;
  status: string;
  confirmationStatus: AppointmentConfirmationStatus;
  scheduledStart: Date;
  scheduledEnd: Date;
  parentConfirmedAt: Date | null;
  therapistConfirmedAt: Date | null;
  rescheduleRequestedBy: string | null;
  proposedScheduledStart: Date | null;
  proposedScheduledEnd: Date | null;
  rescheduleReason: string | null;
  child: { firstName: string; lastName: string; insuranceType?: string | null };
  therapist: {
    userId: string;
    user: { firstName: string; lastName: string; phone?: string | null };
  };
  parent: {
    userId: string;
    user: { firstName: string; lastName: string; phone?: string | null };
  };
};

/** Appointment is ready for arrival / session when fully confirmed by both parties. */
export function isAppointmentOperationallyConfirmed(appointment: {
  status: string;
  confirmationStatus?: AppointmentConfirmationStatus | string | null;
}): boolean {
  if (appointment.confirmationStatus === 'CONFIRMED') {
    return true;
  }
  return ['CONFIRMED', 'SCHEDULED'].includes(appointment.status);
}

@Injectable()
export class AppointmentsService {
  private readonly logger = new Logger(AppointmentsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: NotificationsService,
    private readonly sms: SmsService,
    @Inject(forwardRef(() => PaymentsService))
    private readonly payments: PaymentsService,
  ) {}

  async findByParentUserId(userId: string) {
    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (!parent) {
      return [];
    }
    return this.prisma.appointment.findMany({
      where: { parentId: parent.id },
      include: {
        child: true,
        therapist: { include: { user: true } },
        bookingPayment: true,
      },
      orderBy: { scheduledStart: 'asc' },
    });
  }

  async findUpcomingForParentUser(userId: string) {
    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (!parent) {
      return [];
    }
    return this.prisma.appointment.findMany({
      where: {
        parentId: parent.id,
        scheduledStart: { gte: new Date() },
        status: { notIn: ['CANCELLED', 'COMPLETED', 'NO_SHOW'] },
      },
      include: {
        child: true,
        therapist: { include: { user: true } },
        bookingPayment: true,
      },
      orderBy: { scheduledStart: 'asc' },
    });
  }

  async findUpcomingForTherapistUser(userId: string) {
    const therapist = await this.prisma.therapist.findUnique({
      where: { userId },
    });
    if (!therapist) {
      return [];
    }
    return this.prisma.appointment.findMany({
      where: {
        therapistId: therapist.id,
        scheduledStart: { gte: new Date() },
        status: { notIn: ['CANCELLED', 'COMPLETED', 'NO_SHOW'] },
      },
      include: {
        child: true,
        therapist: { include: { user: true } },
        bookingPayment: true,
      },
      orderBy: { scheduledStart: 'asc' },
    });
  }

  async buildIcalForTherapistUser(userId: string): Promise<string> {
    const rows = await this.findUpcomingForTherapistUser(userId);
    const lines: string[] = [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//BloomOra//EN',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
    ];

    for (const row of rows) {
      const childName = `${row.child.firstName} ${row.child.lastName}`;
      const summary = this.escapeIcalText(`${row.therapyType} – ${childName}`);
      const description = this.escapeIcalText(
        `Status: ${row.status}. Location: ${row.locationType ?? 'IN_HOME'}.`,
      );
      lines.push('BEGIN:VEVENT');
      lines.push(`UID:${row.id}@abaconnect-therapist`);
      lines.push(`DTSTAMP:${this.formatIcalUtc(new Date())}`);
      lines.push(`DTSTART:${this.formatIcalUtc(row.scheduledStart)}`);
      lines.push(`DTEND:${this.formatIcalUtc(row.scheduledEnd)}`);
      lines.push(`SUMMARY:${summary}`);
      lines.push(`DESCRIPTION:${description}`);
      lines.push('END:VEVENT');
    }

    lines.push('END:VCALENDAR');
    return `${lines.join('\r\n')}\r\n`;
  }

  async buildIcalForParentUser(userId: string): Promise<string> {
    const rows = await this.findUpcomingForParentUser(userId);
    const lines: string[] = [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//BloomOra//EN',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
    ];

    for (const row of rows) {
      const therapistName = `${row.therapist.user.firstName} ${row.therapist.user.lastName}`;
      const childName = `${row.child.firstName} ${row.child.lastName}`;
      const summary = this.escapeIcalText(
        `${row.therapyType} – ${childName} with ${therapistName}`,
      );
      const description = this.escapeIcalText(
        `Status: ${row.status}. Location: ${row.locationType ?? 'IN_HOME'}.`,
      );
      lines.push('BEGIN:VEVENT');
      lines.push(`UID:${row.id}@abaconnect`);
      lines.push(`DTSTAMP:${this.formatIcalUtc(new Date())}`);
      lines.push(`DTSTART:${this.formatIcalUtc(row.scheduledStart)}`);
      lines.push(`DTEND:${this.formatIcalUtc(row.scheduledEnd)}`);
      lines.push(`SUMMARY:${summary}`);
      lines.push(`DESCRIPTION:${description}`);
      lines.push('END:VEVENT');
    }

    lines.push('END:VCALENDAR');
    return `${lines.join('\r\n')}\r\n`;
  }

  private formatIcalUtc(date: Date): string {
    return date
      .toISOString()
      .replace(/[-:]/g, '')
      .replace(/\.\d{3}/, '');
  }

  private escapeIcalText(value: string): string {
    return value
      .replace(/\\/g, '\\\\')
      .replace(/;/g, '\\;')
      .replace(/,/g, '\\,')
      .replace(/\n/g, '\\n');
  }

  /**
   * A child may not have overlapping sessions (any therapist / agency roster).
   * A therapist may not have overlapping sessions (any child).
   */
  private async assertNoScheduleOverlap(
    childId: string,
    therapistId: string,
    scheduledStart: Date,
    scheduledEnd: Date,
    excludeAppointmentId?: string,
  ): Promise<void> {
    const activeStatusFilter = {
      in: [...ACTIVE_APPOINTMENT_STATUSES],
    };
    const excludeId = excludeAppointmentId
      ? { not: excludeAppointmentId }
      : undefined;

    const childConflict = await this.prisma.appointment.findFirst({
      where: {
        childId,
        id: excludeId,
        status: activeStatusFilter,
        scheduledStart: { lt: scheduledEnd },
        scheduledEnd: { gt: scheduledStart },
      },
      include: {
        therapist: {
          include: {
            user: { select: { firstName: true, lastName: true } },
          },
        },
      },
    });
    if (childConflict) {
      const therapistName = childConflict.therapist?.user
        ? `${childConflict.therapist.user.firstName} ${childConflict.therapist.user.lastName}`.trim()
        : 'another provider';
      throw new BadRequestException(
        `This child already has a session at that time with ${therapistName}. Choose a different time.`,
      );
    }

    const therapistConflict = await this.prisma.appointment.findFirst({
      where: {
        therapistId,
        id: excludeId,
        status: activeStatusFilter,
        scheduledStart: { lt: scheduledEnd },
        scheduledEnd: { gt: scheduledStart },
      },
      include: {
        child: { select: { firstName: true, lastName: true } },
      },
    });
    if (therapistConflict) {
      const childName = therapistConflict.child
        ? `${therapistConflict.child.firstName} ${therapistConflict.child.lastName}`.trim()
        : 'another child';
      throw new BadRequestException(
        `This therapist already has an appointment during that time with ${childName}. Choose a different time.`,
      );
    }
  }

  async bookForParentUser(userId: string, input: BookAppointmentInput) {
    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (!parent) {
      throw new BadRequestException('Parent profile not found');
    }

    const child = await this.prisma.child.findFirst({
      where: { id: input.childId, parentId: parent.id },
    });
    if (!child) {
      throw new NotFoundException('Child not found');
    }

    const therapist = await this.prisma.therapist.findFirst({
      where: { id: input.therapistId, tenantId: parent.tenantId },
    });
    if (!therapist) {
      throw new NotFoundException('Therapist not found');
    }
    if (!therapist.therapyTypes.includes(input.therapyType)) {
      throw new BadRequestException(
        `This therapist does not offer ${input.therapyType} therapy`,
      );
    }

    if (input.scheduledEnd <= input.scheduledStart) {
      throw new BadRequestException(
        'scheduledEnd must be after scheduledStart',
      );
    }

    await this.assertNoScheduleOverlap(
      child.id,
      therapist.id,
      input.scheduledStart,
      input.scheduledEnd,
    );

    const now = new Date();
    const isSelfPay = isSelfPayInsuranceType(child.insuranceType);
    const appointment = await this.prisma.appointment.create({
      data: {
        tenantId: parent.tenantId,
        parentId: parent.id,
        childId: child.id,
        therapistId: therapist.id,
        therapyType: input.therapyType,
        scheduledStart: input.scheduledStart,
        scheduledEnd: input.scheduledEnd,
        notes: input.notes,
        locationType: input.locationType ?? 'IN_HOME',
        status: 'REQUESTED',
        confirmationStatus: 'PENDING',
        // Insurance: parent confirmation is implicit at booking.
        // Self-pay: parent must confirm then pay before the visit is confirmed.
        parentConfirmedAt: isSelfPay ? undefined : now,
      },
      include: this.appointmentInclude(),
    });

    try {
      await this.notifyConfirmationNeeded(
        appointment as unknown as AppointmentWithParties,
      );
    } catch (err) {
      this.logger.warn(
        `Appointment ${appointment.id} created but notifications failed: ${err}`,
      );
    }
    return appointment;
  }

  async confirmForUser(userId: string, appointmentId: string) {
    const { appointment, role } = await this.findAuthorizedAppointment(
      userId,
      appointmentId,
    );
    if (role === 'AGENCY') {
      throw new ForbiddenException('Agency users cannot confirm appointments');
    }

    if (['COMPLETED', 'CANCELLED', 'NO_SHOW'].includes(appointment.status)) {
      throw new BadRequestException(
        `Cannot confirm appointment in status ${appointment.status}`,
      );
    }
    if (appointment.confirmationStatus === 'CANCELLED') {
      throw new BadRequestException('Appointment is cancelled');
    }

    const now = new Date();
    const parentConfirmed =
      role === 'PARENT' ? now : appointment.parentConfirmedAt;
    const therapistConfirmed =
      role === 'THERAPIST' ? now : appointment.therapistConfirmedAt;

    const updateData: {
      parentConfirmedAt?: Date;
      therapistConfirmedAt?: Date;
      confirmationStatus?: AppointmentConfirmationStatus;
      status?: 'CONFIRMED' | 'REQUESTED' | 'RESCHEDULED';
      scheduledStart?: Date;
      scheduledEnd?: Date;
      proposedScheduledStart?: null;
      proposedScheduledEnd?: null;
      rescheduleRequestedBy?: null;
      rescheduleReason?: null;
    } = {};

    if (role === 'PARENT') {
      if (appointment.parentConfirmedAt) {
        throw new BadRequestException('You have already confirmed');
      }
      updateData.parentConfirmedAt = now;
    } else {
      if (appointment.therapistConfirmedAt) {
        throw new BadRequestException('You have already confirmed');
      }
      updateData.therapistConfirmedAt = now;
    }

    const isSelfPay = isSelfPayInsuranceType(appointment.child.insuranceType);

    if (isSelfPay) {
      const updated = await this.prisma.appointment.update({
        where: { id: appointmentId },
        data: updateData,
        include: this.appointmentInclude(),
      });

      if (role === 'PARENT') {
        try {
          await this.payments.ensureBookingPaymentForAppointment(
            userId,
            appointmentId,
          );
        } catch (err) {
          this.logger.warn(
            `Booking payment setup failed for appointment ${appointmentId}: ${err}`,
          );
        }
      } else {
        const bookingPaid = await this.hasSucceededBookingPayment(appointmentId);
        if (bookingPaid) {
          return this.finalizeAfterBookingPayment(appointmentId);
        }
        await this.notifyUser(updated.parent.userId, {
          type: 'APPOINTMENT_PARTNER_CONFIRMED',
          title: 'Therapist confirmed — payment needed',
          body: `Your therapist confirmed the ${updated.therapyType} session. Complete payment to finalize the appointment.`,
          appointmentId: updated.id,
          smsBody: `BloomOra: Your therapist confirmed. Complete payment to confirm your appointment.`,
        });
      }
      return this.prisma.appointment.findUniqueOrThrow({
        where: { id: appointmentId },
        include: this.appointmentInclude(),
      });
    }

    if (parentConfirmed && therapistConfirmed) {
      if (
        appointment.confirmationStatus === 'RESCHEDULE_REQUESTED' &&
        appointment.proposedScheduledStart &&
        appointment.proposedScheduledEnd
      ) {
        await this.assertNoScheduleOverlap(
          appointment.childId,
          appointment.therapistId,
          appointment.proposedScheduledStart,
          appointment.proposedScheduledEnd,
          appointmentId,
        );
        updateData.scheduledStart = appointment.proposedScheduledStart;
        updateData.scheduledEnd = appointment.proposedScheduledEnd;
        updateData.proposedScheduledStart = null;
        updateData.proposedScheduledEnd = null;
        updateData.rescheduleRequestedBy = null;
        updateData.rescheduleReason = null;
      }
      updateData.confirmationStatus = 'CONFIRMED';
      updateData.status = 'CONFIRMED';
    }

    const updated = await this.prisma.appointment.update({
      where: { id: appointmentId },
      data: updateData,
      include: this.appointmentInclude(),
    });

    const parties = updated as unknown as AppointmentWithParties;
    if (updateData.confirmationStatus === 'CONFIRMED') {
      await this.notifyBothParties(parties, {
        type: 'APPOINTMENT_CONFIRMED',
        title: 'Appointment confirmed',
        body: this.formatConfirmedBody(parties),
        smsBody: `BloomOra: Your ${parties.therapyType} appointment on ${parties.scheduledStart.toLocaleString()} is confirmed.`,
      });
    } else {
      const otherUserId =
        role === 'PARENT'
          ? parties.therapist.userId
          : parties.parent.userId;
      const actorName =
        role === 'PARENT'
          ? `${parties.parent.user.firstName} ${parties.parent.user.lastName}`
          : `${parties.therapist.user.firstName} ${parties.therapist.user.lastName}`;
      await this.notifyUser(otherUserId, {
        type: 'APPOINTMENT_PARTNER_CONFIRMED',
        title: 'Appointment confirmation update',
        body: `${actorName} confirmed the ${parties.therapyType} session on ${parties.scheduledStart.toLocaleString()}. Please confirm in the app.`,
        appointmentId: parties.id,
        smsBody: `BloomOra: ${actorName} confirmed an appointment. Open the app to confirm, reschedule, or cancel.`,
      });
    }

    return updated;
  }

  async respondForTherapistUserId(
    userId: string,
    appointmentId: string,
    action: 'CONFIRM' | 'DECLINE',
    reason?: string,
  ) {
    if (action === 'CONFIRM') {
      return this.confirmForUser(userId, appointmentId);
    }
    return this.cancelForUser(userId, appointmentId, reason ?? 'Declined by therapist');
  }

  async requestRescheduleForUser(
    userId: string,
    appointmentId: string,
    proposedStart: Date,
    proposedEnd: Date,
    reason?: string,
  ) {
    const { appointment, role } = await this.findAuthorizedAppointment(
      userId,
      appointmentId,
    );
    if (role === 'AGENCY') {
      throw new ForbiddenException('Agency users cannot reschedule appointments');
    }

    if (['COMPLETED', 'CANCELLED', 'NO_SHOW'].includes(appointment.status)) {
      throw new BadRequestException('Cannot reschedule this appointment');
    }
    if (proposedEnd <= proposedStart) {
      throw new BadRequestException(
        'proposedEnd must be after proposedStart',
      );
    }

    await this.assertNoScheduleOverlap(
      appointment.childId,
      appointment.therapistId,
      proposedStart,
      proposedEnd,
      appointmentId,
    );

    const updated = await this.prisma.appointment.update({
      where: { id: appointmentId },
      data: {
        confirmationStatus: 'RESCHEDULE_REQUESTED',
        parentConfirmedAt: null,
        therapistConfirmedAt: null,
        rescheduleRequestedBy: role,
        proposedScheduledStart: proposedStart,
        proposedScheduledEnd: proposedEnd,
        rescheduleReason: reason,
      },
      include: this.appointmentInclude(),
    });

    const parties = updated as unknown as AppointmentWithParties;
    const actorName =
      role === 'PARENT'
        ? `${parties.parent.user.firstName} ${parties.parent.user.lastName}`
        : `${parties.therapist.user.firstName} ${parties.therapist.user.lastName}`;
    const when = proposedStart.toLocaleString();
    const otherUserId =
      role === 'PARENT' ? parties.therapist.userId : parties.parent.userId;

    await this.notifyUser(otherUserId, {
      type: 'APPOINTMENT_RESCHEDULE_REQUESTED',
      title: 'Reschedule requested',
      body: `${actorName} requested to move ${parties.therapyType} to ${when}${reason ? `: ${reason}` : ''}. Open the app to confirm, propose another time, or cancel.`,
      appointmentId: parties.id,
      smsBody: `BloomOra: ${actorName} requested to reschedule to ${when}. Open the app to confirm, reschedule, or cancel.`,
    });

    return updated;
  }

  async rescheduleForParentUser(
    userId: string,
    appointmentId: string,
    scheduledStart: Date,
    scheduledEnd: Date,
    reason?: string,
  ) {
    return this.requestRescheduleForUser(
      userId,
      appointmentId,
      scheduledStart,
      scheduledEnd,
      reason,
    );
  }

  async cancelForUser(
    userId: string,
    appointmentId: string,
    reason?: string,
  ) {
    const { appointment, role } = await this.findAuthorizedAppointment(
      userId,
      appointmentId,
    );

    if (['COMPLETED', 'CANCELLED', 'NO_SHOW'].includes(appointment.status)) {
      throw new BadRequestException('Cannot cancel this appointment');
    }

    const cancelLabel =
      role === 'PARENT'
        ? 'Cancelled by parent'
        : role === 'THERAPIST'
          ? 'Cancelled by therapist'
          : 'Cancelled by agency';

    const updated = await this.prisma.appointment.update({
      where: { id: appointmentId },
      data: {
        status: 'CANCELLED',
        confirmationStatus: 'CANCELLED',
        cancelledReason: reason ?? cancelLabel,
        cancelRequestedBy: role,
      },
      include: this.appointmentInclude(),
    });

    const parties = updated as unknown as AppointmentWithParties;
    const childName = `${parties.child.firstName} ${parties.child.lastName}`;
    const when = parties.scheduledStart.toLocaleString();
    const cancelReason = reason ?? cancelLabel;
    const actorName =
      role === 'PARENT'
        ? `${parties.parent.user.firstName} ${parties.parent.user.lastName}`
        : role === 'THERAPIST'
          ? `${parties.therapist.user.firstName} ${parties.therapist.user.lastName}`
          : 'Agency';

    await this.notifyBothParties(parties, {
      type: 'APPOINTMENT_CANCELLED',
      title: 'Appointment cancelled',
      body: `${actorName} cancelled ${parties.therapyType} for ${childName} on ${when}: ${cancelReason}`,
      smsBody: `BloomOra: Appointment cancelled (${when}). ${cancelReason}`,
    });

    return updated;
  }

  async cancelForTherapistUser(
    userId: string,
    appointmentId: string,
    reason?: string,
  ) {
    return this.cancelForUser(userId, appointmentId, reason);
  }

  async cancelForParentUser(
    userId: string,
    appointmentId: string,
    reason?: string,
  ) {
    return this.cancelForUser(userId, appointmentId, reason);
  }

  async bookRecurringForParentUser(
    userId: string,
    input: BookAppointmentInput,
    weeks: number,
  ) {
    if (weeks < 2 || weeks > 12) {
      throw new BadRequestException('Recurring bookings must be 2–12 weeks');
    }
    const results = [];
    for (let i = 0; i < weeks; i++) {
      const weekMs = 7 * 24 * 60 * 60 * 1000;
      const row = await this.bookForParentUser(userId, {
        ...input,
        scheduledStart: new Date(input.scheduledStart.getTime() + weekMs * i),
        scheduledEnd: new Date(input.scheduledEnd.getTime() + weekMs * i),
        notes:
          i === 0
            ? input.notes
            : `${input.notes ?? 'Recurring session'} (week ${i + 1}/${weeks})`,
      });
      results.push(row);
    }
    return results;
  }

  private appointmentInclude() {
    return {
      child: true,
      therapist: { include: { user: true } },
      parent: { include: { user: true } },
      bookingPayment: true,
    };
  }

  async hasSucceededBookingPayment(appointmentId: string): Promise<boolean> {
    const payment = await this.prisma.payment.findFirst({
      where: { appointmentId, status: 'SUCCEEDED' },
    });
    return payment != null;
  }

  async finalizeAfterBookingPayment(appointmentId: string) {
    const appointment = await this.prisma.appointment.findUnique({
      where: { id: appointmentId },
      include: this.appointmentInclude(),
    });
    if (!appointment) {
      throw new NotFoundException('Appointment not found');
    }

    const now = new Date();
    const updated = await this.prisma.appointment.update({
      where: { id: appointmentId },
      data: {
        confirmationStatus: 'CONFIRMED',
        status: 'CONFIRMED',
        parentConfirmedAt: appointment.parentConfirmedAt ?? now,
      },
      include: this.appointmentInclude(),
    });

    const prepaidSession = await this.prisma.session.findUnique({
      where: { appointmentId },
      include: { payment: true },
    });
    if (prepaidSession?.payment?.status === 'PENDING') {
      await this.prisma.payment.update({
        where: { id: prepaidSession.payment.id },
        data: { status: 'CANCELLED' },
      });
    }

    const parties = updated as unknown as AppointmentWithParties;
    try {
      await this.notifyBothParties(parties, {
        type: 'APPOINTMENT_CONFIRMED',
        title: 'Appointment confirmed',
        body: this.formatConfirmedBody(parties),
        smsBody: `BloomOra: Your ${parties.therapyType} appointment on ${parties.scheduledStart.toLocaleString()} is confirmed.`,
      });
    } catch (err) {
      this.logger.warn(
        `Confirmation notifications failed for appointment ${appointmentId}: ${err}`,
      );
    }
    return updated;
  }

  private async findAuthorizedAppointment(
    userId: string,
    appointmentId: string,
  ): Promise<{ appointment: AppointmentWithParties; role: AppointmentActorRole }> {
    const appointment = await this.prisma.appointment.findUnique({
      where: { id: appointmentId },
      include: this.appointmentInclude(),
    });
    if (!appointment) {
      throw new NotFoundException('Appointment not found');
    }

    const parent = await this.prisma.parent.findUnique({ where: { userId } });
    if (parent && appointment.parentId === parent.id) {
      return { appointment: appointment as unknown as AppointmentWithParties, role: 'PARENT' };
    }

    const therapist = await this.prisma.therapist.findUnique({
      where: { userId },
    });
    if (therapist && appointment.therapistId === therapist.id) {
      return {
        appointment: appointment as unknown as AppointmentWithParties,
        role: 'THERAPIST',
      };
    }

    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (
      user?.agencyId &&
      appointment.agencyId &&
      user.agencyId === appointment.agencyId
    ) {
      return {
        appointment: appointment as unknown as AppointmentWithParties,
        role: 'AGENCY',
      };
    }

    throw new ForbiddenException('Not authorized for this appointment');
  }

  private formatConfirmedBody(appointment: AppointmentWithParties): string {
    const childName = `${appointment.child.firstName} ${appointment.child.lastName}`;
    const therapistName = `${appointment.therapist.user.firstName} ${appointment.therapist.user.lastName}`;
    const when = appointment.scheduledStart.toLocaleString();
    return `${appointment.therapyType} for ${childName} with ${therapistName} on ${when} is fully confirmed`;
  }

  private async notifyConfirmationNeeded(appointment: AppointmentWithParties) {
    const childName = `${appointment.child.firstName} ${appointment.child.lastName}`;
    const when = appointment.scheduledStart.toLocaleString();
    const therapistName = `${appointment.therapist.user.firstName} ${appointment.therapist.user.lastName}`;

    await this.notifyUser(appointment.therapist.userId, {
      type: 'APPOINTMENT_CONFIRMATION_NEEDED',
      title: 'New appointment request',
      body: `Please confirm ${appointment.therapyType} with ${childName} on ${when}. You can confirm, reschedule, or cancel in the app.`,
      appointmentId: appointment.id,
      smsBody: `BloomOra: New ${appointment.therapyType} appointment with ${childName} on ${when}. Open the app to confirm, reschedule, or cancel.`,
    });

    await this.notifyUser(appointment.parent.userId, {
      type: 'APPOINTMENT_BOOKED',
      title: 'Appointment requested',
      body: `Your ${appointment.therapyType} session for ${childName} with ${therapistName} on ${when} is booked. Waiting for provider confirmation.`,
      appointmentId: appointment.id,
      smsBody: `BloomOra: ${appointment.therapyType} with ${therapistName} on ${when} is booked. We'll notify you when the provider confirms.`,
    });
  }

  private async notifyBothParties(
    appointment: AppointmentWithParties,
    payload: {
      type: string;
      title: string;
      body: string;
      smsBody: string;
    },
  ) {
    await this.notifyUser(appointment.parent.userId, {
      ...payload,
      appointmentId: appointment.id,
    });
    await this.notifyUser(appointment.therapist.userId, {
      ...payload,
      appointmentId: appointment.id,
    });
  }

  private async notifyUser(
    userId: string,
    payload: {
      type: string;
      title: string;
      body: string;
      appointmentId: string;
      smsBody: string;
    },
  ) {
    try {
      await this.notifications.createForUser(userId, {
        title: payload.title,
        body: payload.body,
        data: {
          appointmentId: payload.appointmentId,
          type: payload.type,
          actionType: payload.type,
        },
      });
    } catch (err) {
      this.logger.warn(
        `In-app notification failed for user ${userId}: ${err}`,
      );
    }

    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (user?.phone) {
      try {
        await this.sms.sendSms({ to: user.phone, body: payload.smsBody });
      } catch (err) {
        this.logger.warn(`SMS failed for user ${userId}: ${err}`);
      }
    }
  }

  async create(data: Record<string, unknown>) {
    void data;
    throw new BadRequestException(
      'Use GraphQL bookAppointment or bookForParentUser',
    );
  }

  async findAll() {
    return this.prisma.appointment.findMany({
      take: 100,
      orderBy: { scheduledStart: 'desc' },
      include: { child: true, therapist: { include: { user: true } } },
    });
  }

  async findOne(id: string) {
    const appointment = await this.prisma.appointment.findUnique({
      where: { id },
      include: { child: true, therapist: { include: { user: true } } },
    });
    if (!appointment) {
      throw new NotFoundException('Appointment not found');
    }
    return appointment;
  }

  async update(id: string, data: Record<string, unknown>) {
    await this.findOne(id);
    return this.prisma.appointment.update({
      where: { id },
      data: data as Parameters<
        typeof this.prisma.appointment.update
      >[0]['data'],
      include: { child: true, therapist: { include: { user: true } } },
    });
  }

  async remove(id: string) {
    await this.findOne(id);
    await this.prisma.appointment.delete({ where: { id } });
    return { id, deleted: true };
  }
}
