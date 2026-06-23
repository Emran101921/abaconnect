import 'package:flutter/material.dart';

import '../data/therapist_repository.dart';

class SelfPayPaymentStatusChip extends StatelessWidget {
  const SelfPayPaymentStatusChip({super.key, required this.appointment});

  final TherapistAppointmentModel appointment;

  @override
  Widget build(BuildContext context) {
    final hasPayment =
        appointment.requiresSelfPayCollection || appointment.sessionPaymentId != null;
    if (!hasPayment) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final (label, background, foreground) = _statusStyle(theme);

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Chip(
          avatar: Icon(
            _statusIcon,
            size: 16,
            color: foreground,
          ),
          label: Text(label),
          backgroundColor: background,
          labelStyle: TextStyle(color: foreground, fontWeight: FontWeight.w600),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  IconData get _statusIcon {
    if (appointment.isSessionPaymentReceived) {
      return Icons.check_circle_outline_rounded;
    }
    if (appointment.hasArrived) {
      return Icons.payments_outlined;
    }
    return Icons.account_balance_wallet_outlined;
  }

  (String, Color, Color) _statusStyle(ThemeData theme) {
    if (appointment.isSessionPaymentReceived) {
      return (
        appointment.hasArrived
            ? 'Self-pay · Paid'
            : 'Self-pay · Paid at booking',
        theme.colorScheme.primaryContainer,
        theme.colorScheme.onPrimaryContainer,
      );
    }
    if (appointment.hasArrived) {
      return (
        appointment.sessionPaymentId != null
            ? 'Self-pay · Awaiting parent payment'
            : 'Self-pay · Charge session',
        theme.colorScheme.errorContainer,
        theme.colorScheme.onErrorContainer,
      );
    }
    if (appointment.sessionPaymentStatus == 'PENDING') {
      return (
        'Self-pay · Payment requested',
        theme.colorScheme.tertiaryContainer,
        theme.colorScheme.onTertiaryContainer,
      );
    }
    return (
      'Self-pay · Collect before session',
      theme.colorScheme.surfaceContainerHighest,
      theme.colorScheme.onSurfaceVariant,
    );
  }
}
