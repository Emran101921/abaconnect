import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../data/therapist_repository.dart';
import 'session_notes_screen.dart';
import 'therapist_home_screen.dart';
import '../../../shared/widgets/app_scaffold.dart';

class TherapistAppointmentsScreen extends ConsumerWidget {
  const TherapistAppointmentsScreen({super.key});

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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment confirmed')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Confirm failed: $e')),
        );
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment cancelled')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cancel failed: $e')),
        );
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment declined')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Decline failed: $e')),
        );
      }
    }
  }

  Future<void> _startSession(
    BuildContext context,
    WidgetRef ref,
    TherapistAppointmentModel appointment,
  ) async {
    try {
      await ref
          .read(therapistRepositoryProvider)
          .startSession(appointment.id);
      ref.invalidate(therapistSessionsProvider);
      ref.invalidate(therapistAppointmentsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Session started for ${appointment.childName}'),
          action: SnackBarAction(
            label: 'SOAP',
            onPressed: () => context.push('/therapist/session-notes'),
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start session: $e')),
        );
      }
    }
  }

  Future<void> _exportCalendar(BuildContext context, WidgetRef ref) async {
    try {
      final path =
          await ref.read(therapistRepositoryProvider).downloadAppointmentsIcal();
      if (!context.mounted) return;
      final message = kIsWeb
          ? 'Calendar file downloaded'
          : (path.isNotEmpty ? 'Saved to $path' : 'Calendar file saved');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointments = ref.watch(therapistAppointmentsProvider);

    return AppScaffold(
      title: 'My Appointments',
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
            return const Center(
              child: Text('No appointments yet'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final a = list[index];
              final isRequested = a.status == 'REQUESTED';
              final canStart = a.status == 'CONFIRMED' || a.status == 'SCHEDULED';
              final canCancel = !['COMPLETED', 'CANCELLED', 'NO_SHOW', 'REQUESTED']
                  .contains(a.status);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.childName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text('${a.therapyType} · ${a.status}'),
                      Text(
                        DateFormat.yMMMd().add_jm().format(a.scheduledStart),
                      ),
                      if (isRequested) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: () => _confirm(context, ref, a),
                                child: const Text('Confirm'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _decline(context, ref, a),
                                child: const Text('Decline'),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (canStart) ...[
                        const SizedBox(height: 12),
                        FilledButton.tonalIcon(
                          onPressed: () => _startSession(context, ref, a),
                          icon: const Icon(Icons.play_circle_outline),
                          label: const Text('Start session & document'),
                        ),
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
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
