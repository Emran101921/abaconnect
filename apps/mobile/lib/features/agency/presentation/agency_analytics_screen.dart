import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_scaffold.dart';
import 'agency_providers.dart';

class AgencyAnalyticsScreen extends ConsumerWidget {
  const AgencyAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(agencyAnalyticsProvider);

    return AppScaffold(
      title: 'Analytics',
      body: analytics.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (metrics) {
          if (metrics.isEmpty) {
            return const Center(child: Text('No analytics snapshots yet.'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(agencyAnalyticsProvider);
              await ref.read(agencyAnalyticsProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: metrics
                  .map(
                    (m) => Card(
                      child: ListTile(
                        title: Text('${m['key']}'),
                        trailing: Text(
                          '${m['value']}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          );
        },
      ),
    );
  }
}
