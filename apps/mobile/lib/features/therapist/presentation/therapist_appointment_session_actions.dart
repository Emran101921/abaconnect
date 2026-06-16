import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../data/therapist_repository.dart';
import '../therapist_providers.dart';
import 'session_notes_screen.dart';
import 'therapist_home_screen.dart';

class TherapistAppointmentSessionActions extends ConsumerWidget {
  const TherapistAppointmentSessionActions({
    super.key,
    required this.appointment,
    this.compact = false,
  });

  final TherapistAppointmentModel appointment;
  final bool compact;

  Future<void> _recordArrival(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(therapistRepositoryProvider)
          .recordTherapistArrival(appointment.id);
      ref.invalidate(therapistAppointmentsProvider);
      ref.invalidate(therapistDashboardProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Arrival recorded')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not record arrival: $e')),
        );
      }
    }
  }

  Future<void> _requestPayment(BuildContext context, WidgetRef ref) async {
    try {
      final result = await ref
          .read(therapistRepositoryProvider)
          .requestSessionPayment(appointment.id);
      ref.invalidate(therapistAppointmentsProvider);
      ref.invalidate(therapistDashboardProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.payment.isPaid
                ? 'Payment already received'
                : 'Payment request sent to parent',
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not request payment: $e')),
        );
      }
    }
  }

  void _openSessionDocumentation(BuildContext context, String sessionId) {
    context.push(
      '${AppRoutes.therapistHome}/session-notes/$sessionId/form',
    );
  }

  Future<void> _startSession(BuildContext context, WidgetRef ref) async {
    try {
      final sessionId = await ref
          .read(therapistRepositoryProvider)
          .startSession(appointment.id);
      ref.invalidate(therapistSessionsProvider);
      ref.invalidate(therapistAppointmentsProvider);
      ref.invalidate(therapistDashboardProvider);
      if (!context.mounted) return;
      if (sessionId.isEmpty) {
        throw Exception('Session id missing');
      }
      _openSessionDocumentation(context, sessionId);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start session: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startLabel =
        compact ? 'Start' : 'Start session & document';

    if (!appointment.requiresSelfPayCollection) {
      if (!appointment.canStartSession) return const SizedBox.shrink();
      return GlossyButton(
        title: startLabel,
        icon: Icons.play_circle_outline_rounded,
        variant: GlossyButtonVariant.greenTeal,
        size: compact ? GlossyButtonSize.small : GlossyButtonSize.medium,
        onPressed: () => _startSession(context, ref),
      );
    }

    final isPaid = appointment.isSessionPaymentReceived;
    final paymentPending = appointment.sessionPaymentStatus == 'PENDING' &&
        appointment.sessionPaymentId != null;
    final awaitingPayment = appointment.hasArrived && !isPaid;
    final canCharge =
        appointment.hasArrived && !isPaid && !paymentPending;
    final canArrive = !appointment.hasArrived &&
        (appointment.status == 'CONFIRMED' ||
            appointment.status == 'SCHEDULED');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (appointment.hasArrived && !canArrive)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Arrival recorded',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ),
        if (canArrive)
          GlossyButton(
            title: "I've arrived",
            icon: Icons.location_on_rounded,
            variant: GlossyButtonVariant.tealBlue,
            size: compact ? GlossyButtonSize.small : GlossyButtonSize.medium,
            onPressed: () => _recordArrival(context, ref),
          ),
        if (isPaid && appointment.hasArrived) ...[
          if (canArrive) const SizedBox(height: 8),
          Text(
            'Session payment received — you can start when ready.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ],
        if (canCharge) ...[
          if (canArrive) const SizedBox(height: 8),
          GlossyButton(
            title: appointment.sessionPaymentAmount != null
                ? 'Charge \$${appointment.sessionPaymentAmount!.toStringAsFixed(2)}'
                : 'Charge session (self-pay)',
            icon: Icons.payments_rounded,
            variant: GlossyButtonVariant.orangeRed,
            size: compact ? GlossyButtonSize.small : GlossyButtonSize.medium,
            onPressed: () => _requestPayment(context, ref),
          ),
          const SizedBox(height: 4),
          Text(
            'Parent must pay before you can start the session.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (paymentPending) ...[
          if (canArrive || canCharge) const SizedBox(height: 8),
          Text(
            'Awaiting parent payment — invoice sent.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.tertiary,
                ),
          ),
        ],
        if (awaitingPayment && appointment.sessionPaymentId != null) ...[
          const SizedBox(height: 8),
          GlossyButton(
            title: 'Refresh payment status',
            icon: Icons.refresh_rounded,
            variant: GlossyButtonVariant.neutral,
            size: GlossyButtonSize.small,
            onPressed: () async {
              ref.invalidate(therapistAppointmentsProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Checking payment status…')),
                );
              }
            },
          ),
        ],
        if (appointment.canStartSession) ...[
          const SizedBox(height: 8),
          GlossyButton(
            title: startLabel,
            icon: Icons.play_circle_outline_rounded,
            variant: GlossyButtonVariant.greenTeal,
            size: compact ? GlossyButtonSize.small : GlossyButtonSize.medium,
            onPressed: () => _startSession(context, ref),
          ),
        ],
      ],
    );
  }
}
