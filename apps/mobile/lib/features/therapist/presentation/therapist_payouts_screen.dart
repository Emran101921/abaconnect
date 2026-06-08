import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../payments/data/billing_repository.dart';

final therapistPayoutsProvider = FutureProvider<List<PayoutModel>>((ref) {
  return ref.watch(billingRepositoryProvider).fetchTherapistPayouts();
});

class TherapistPayoutsScreen extends ConsumerWidget {
  const TherapistPayoutsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payouts = ref.watch(therapistPayoutsProvider);
    final formatter = NumberFormat.currency(symbol: '\$');

    return AppScaffold(
      title: 'Payouts',
      body: payouts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No payouts yet'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(therapistPayoutsProvider);
              await ref.read(therapistPayoutsProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final p = list[index];
                return Card(
                  child: ListTile(
                    title: Text(formatter.format(p.amount)),
                    subtitle: Text(
                      '${DateFormat.yMMMd().format(p.periodStart)} – '
                      '${DateFormat.yMMMd().format(p.periodEnd)}\n${p.status}',
                    ),
                    isThreeLine: true,
                    trailing: Icon(
                      p.status == 'SUCCEEDED'
                          ? Icons.check_circle
                          : Icons.pending,
                      color: p.status == 'SUCCEEDED'
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
