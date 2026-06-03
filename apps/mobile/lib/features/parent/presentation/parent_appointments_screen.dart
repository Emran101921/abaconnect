import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../data/parent_booking_repository.dart';
import 'parent_home_screen.dart';

class ParentAppointmentsScreen extends ConsumerWidget {
  const ParentAppointmentsScreen({super.key});

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
                return Card(
                  child: ListTile(
                    title: Text('${a.therapyType} · ${a.childName}'),
                    subtitle: Text(
                      '${a.therapistName}\n'
                      '${DateFormat.yMMMd().add_jm().format(a.scheduledStart)}\n'
                      '${a.status}',
                    ),
                    isThreeLine: true,
                    trailing: canChange
                        ? PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'reschedule') {
                                _reschedule(context, ref, a);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'reschedule',
                                child: Text('Reschedule'),
                              ),
                            ],
                          )
                        : null,
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
