import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/app_scaffold.dart';
import 'agency_providers.dart';

class AgencyAppointmentsScreen extends ConsumerWidget {
  const AgencyAppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(agencyDashboardProvider);
    final appointments = ref.watch(agencyUpcomingAppointmentsProvider);

    return AppScaffold(
      title: 'Appointments',
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(agencyDashboardProvider);
          ref.invalidate(agencyUpcomingAppointmentsProvider);
          await Future.wait([
            ref.read(agencyDashboardProvider.future),
            ref.read(agencyUpcomingAppointmentsProvider.future),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            dashboard.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Dashboard error: $e'),
              data: (stats) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sessions scheduled today',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${stats.appointmentsToday}',
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${stats.therapistCount} therapists · ${stats.activeClients} clients',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Upcoming (14 days)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            appointments.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Appointments error: $e'),
              data: (list) {
                if (list.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No upcoming appointments in the next two weeks.',
                    ),
                  );
                }
                return Column(
                  children: list.map((a) {
                    final start = DateFormat.MMMd().add_jm().format(
                      a.scheduledStart,
                    );
                    return Card(
                      child: ListTile(
                        title: Text('${a.childName} · ${a.therapyType}'),
                        subtitle: Text(
                          '${a.therapistName}\n$start · ${a.status} · ${a.locationType}',
                        ),
                        isThreeLine: true,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
