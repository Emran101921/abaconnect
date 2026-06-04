import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/app_scaffold.dart';
import 'admin_providers.dart';
import 'admin_stat_card.dart';

class AdminAnalyticsScreen extends ConsumerWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(adminAnalyticsProvider);
    final currency = NumberFormat.currency(symbol: '\$');

    return AppScaffold(
      title: 'Analytics',
      body: analytics.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (metrics) {
          if (metrics.isEmpty) {
            return const Center(child: Text('No analytics yet'));
          }
          String label(String key) {
            switch (key) {
              case 'appointments_7d':
                return 'Appointments (7d)';
              case 'sessions_completed':
                return 'Sessions completed';
              case 'revenue_paid':
                return 'Revenue paid';
              case 'active_children':
                return 'Active children';
              default:
                return key;
            }
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(adminAnalyticsProvider);
              await ref.read(adminAnalyticsProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Metrics refresh when you open this screen. Use them to '
                  'monitor platform health.',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: metrics.map((m) {
                    final display = m.metricKey == 'revenue_paid'
                        ? currency.format(m.metricValue)
                        : m.metricValue.toStringAsFixed(
                            m.metricValue == m.metricValue.roundToDouble()
                                ? 0
                                : 2,
                          );
                    return AdminStatCard(label: label(m.metricKey), value: display);
                  }).toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
