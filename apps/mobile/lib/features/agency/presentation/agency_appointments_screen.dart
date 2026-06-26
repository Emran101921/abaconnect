import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/app_scaffold.dart';
import 'agency_providers.dart';

class AgencyAppointmentsScreen extends ConsumerStatefulWidget {
  const AgencyAppointmentsScreen({super.key});

  @override
  ConsumerState<AgencyAppointmentsScreen> createState() =>
      _AgencyAppointmentsScreenState();
}

class _AgencyAppointmentsScreenState
    extends ConsumerState<AgencyAppointmentsScreen> {
  var _weekOffset = 0;

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(agencyDashboardProvider);
    final appointments = ref.watch(agencyUpcomingAppointmentsProvider);
    final weekStart = _weekStart(_weekOffset);
    final weekEnd = weekStart.add(const Duration(days: 7));

    return AppScaffold(
      title: 'Scheduling',
      subtitle: 'Agency calendar and upcoming sessions',
      showPageBreadcrumbs: true,
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
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _weekOffset -= 1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    'Week of ${DateFormat.MMMd().format(weekStart)}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _weekOffset += 1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
              'This week',
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
                final weekList = list
                    .where(
                      (a) =>
                          !a.scheduledStart.isBefore(weekStart) &&
                          a.scheduledStart.isBefore(weekEnd),
                    )
                    .toList();
                if (weekList.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No appointments scheduled this week.'),
                  );
                }
                return Column(
                  children: weekList.map((a) {
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

  DateTime _weekStart(int offset) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final day = DateTime(monday.year, monday.month, monday.day);
    return day.add(Duration(days: offset * 7));
  }
}
