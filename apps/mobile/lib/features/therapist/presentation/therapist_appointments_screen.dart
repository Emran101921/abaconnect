import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../data/therapist_repository.dart';
import '../therapist_providers.dart';
import 'self_pay_payment_status_chip.dart';
import 'therapist_appointment_session_actions.dart';
import 'therapist_home_screen.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/app_scaffold.dart';

class TherapistAppointmentsScreen extends ConsumerWidget {
  const TherapistAppointmentsScreen({super.key, this.highlightAppointmentId});

  final String? highlightAppointmentId;

  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref,
    TherapistAppointmentModel appointment,
  ) async {
    try {
      await ref
          .read(therapistRepositoryProvider)
          .confirmAppointment(appointment.id);
      ref.invalidate(therapistAppointmentsProvider);
      ref.invalidate(therapistDashboardProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Appointment confirmed')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Confirm failed: $e')));
      }
    }
  }

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    TherapistAppointmentModel appointment,
  ) async {
    try {
      await ref
          .read(therapistRepositoryProvider)
          .cancelAppointment(appointment.id, reason: 'Therapist unavailable');
      ref.invalidate(therapistAppointmentsProvider);
      ref.invalidate(therapistDashboardProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Appointment cancelled')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Cancel failed: $e')));
      }
    }
  }

  Future<void> _decline(
    BuildContext context,
    WidgetRef ref,
    TherapistAppointmentModel appointment,
  ) async {
    try {
      await ref
          .read(therapistRepositoryProvider)
          .declineAppointment(appointment.id, reason: 'Schedule conflict');
      ref.invalidate(therapistAppointmentsProvider);
      ref.invalidate(therapistDashboardProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Appointment declined')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Decline failed: $e')));
      }
    }
  }

  Future<void> _exportCalendar(BuildContext context, WidgetRef ref) async {
    try {
      final path = await ref
          .read(therapistRepositoryProvider)
          .downloadAppointmentsIcal();
      if (!context.mounted) return;
      final message = kIsWeb
          ? 'Calendar file downloaded'
          : (path.isNotEmpty ? 'Saved to $path' : 'Calendar file saved');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointments = ref.watch(therapistAppointmentsProvider);

    return AppScaffold(
      title: 'My Appointments',
      bottomNavigationBar: TherapistBottomNav(
        current: TherapistNavTab.appointments,
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.calendar_month),
          tooltip: 'Export to calendar',
          onPressed: () => _exportCalendar(context, ref),
        ),
      ],
      body: appointments.when(
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No appointments yet'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final a = list[index];
              final isRequested = a.status == 'REQUESTED';
              final highlighted = highlightAppointmentId == a.id;
              final canCancel = ![
                'COMPLETED',
                'CANCELLED',
                'NO_SHOW',
                'REQUESTED',
              ].contains(a.status);
              return Card(
                color: highlighted
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (highlighted)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'From notification',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      Text(
                        a.childName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${a.therapyType} · ${a.status}'
                        '${a.locationType != null ? ' · ${a.locationType}' : ''}'
                        '${a.requiresSelfPayCollection ? ' · Self-pay' : ''}',
                      ),
                      Text(
                        DateFormat.yMMMd().add_jm().format(a.scheduledStart),
                      ),
                      SelfPayPaymentStatusChip(appointment: a),
                      if (isRequested) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: GlossyButton(
                                title: 'Confirm',
                                icon: Icons.check_rounded,
                                variant: GlossyButtonVariant.greenTeal,
                                size: GlossyButtonSize.small,
                                onPressed: () => _confirm(context, ref, a),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GlossyOutlinedButton(
                                onPressed: () => _decline(context, ref, a),
                                child: const Text('Decline'),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (!isRequested &&
                          (a.requiresSelfPayCollection ||
                              a.status == 'CONFIRMED' ||
                              a.status == 'SCHEDULED' ||
                              a.canStartSession)) ...[
                        const SizedBox(height: 12),
                        TherapistAppointmentSessionActions(appointment: a),
                      ],
                      if (canCancel) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => _cancel(context, ref, a),
                            child: const Text('Cancel appointment'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Could not load appointments',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  AppSnackBar.messageFromError(e),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                GlossyButton(
                  title: 'Retry',
                  icon: Icons.refresh_rounded,
                  variant: GlossyButtonVariant.neutral,
                  onPressed: () {
                    ref.invalidate(therapistAppointmentsProvider);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
