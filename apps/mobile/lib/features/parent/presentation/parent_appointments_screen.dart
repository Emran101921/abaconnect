import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../platform/data/platform_repository.dart';
import '../data/parent_booking_repository.dart';
import 'parent_home_screen.dart';

class ParentAppointmentsScreen extends ConsumerWidget {
  const ParentAppointmentsScreen({super.key});

  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    AppointmentModel appointment,
  ) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Cancel appointment?'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Reason (optional)',
            ),
            maxLines: 2,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Keep'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Cancel visit'),
            ),
          ],
        );
      },
    );
    if (reason == null || !context.mounted) return;

    try {
      await ref.read(parentBookingRepositoryProvider).cancelAppointment(
            appointmentId: appointment.id,
            reason: reason.isEmpty ? null : reason,
          );
      ref.invalidate(parentAppointmentsProvider);
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

  Future<void> _joinTelehealth(
    BuildContext context,
    WidgetRef ref,
    AppointmentModel appointment,
  ) async {
    try {
      final session =
          await ref.read(platformRepositoryProvider).joinTelehealth(appointment.id);
      if (!context.mounted) return;
      if (session.joinUrl != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Room ready: ${session.joinUrl}'),
            duration: const Duration(seconds: 8),
          ),
        );
      }
      context.push('/telehealth');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Telehealth failed: $e')),
        );
      }
    }
  }

  Future<void> _exportCalendar(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      final path =
          await ref.read(parentBookingRepositoryProvider).downloadAppointmentsIcal();
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

  Future<void> _reschedule(
    BuildContext context,
    WidgetRef ref,
    AppointmentModel appointment,
  ) async {
    var start = appointment.scheduledStart;
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      initialDate: start,
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(start),
    );
    if (time == null || !context.mounted) return;
    start = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final end = start.add(const Duration(hours: 1));

    try {
      await ref.read(parentBookingRepositoryProvider).rescheduleAppointment(
            appointmentId: appointment.id,
            start: start,
            end: end,
          );
      ref.invalidate(parentAppointmentsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appointment rescheduled')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reschedule failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointments = ref.watch(parentAppointmentsProvider);

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
            return const Center(child: Text('No appointments yet'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(parentAppointmentsProvider);
              await ref.read(parentAppointmentsProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final a = list[index];
                final canChange = !['COMPLETED', 'CANCELLED', 'NO_SHOW']
                    .contains(a.status);
                final loc = a.locationType ?? 'IN_HOME';
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${a.therapyType} · ${a.childName}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text('${a.therapistName} · $loc'),
                        Text(
                          DateFormat.yMMMd().add_jm().format(a.scheduledStart),
                        ),
                        Chip(label: Text(a.status)),
                        if (a.isTelehealth &&
                            !['COMPLETED', 'CANCELLED'].contains(a.status))
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: FilledButton.icon(
                              onPressed: () => _joinTelehealth(context, ref, a),
                              icon: const Icon(Icons.video_call),
                              label: const Text('Join telehealth'),
                            ),
                          ),
                        if (canChange)
                          Align(
                            alignment: Alignment.centerRight,
                            child: PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'reschedule') {
                                  _reschedule(context, ref, a);
                                } else if (v == 'cancel') {
                                  _cancel(context, ref, a);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'reschedule',
                                  child: Text('Reschedule'),
                                ),
                                PopupMenuItem(
                                  value: 'cancel',
                                  child: Text('Cancel'),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
