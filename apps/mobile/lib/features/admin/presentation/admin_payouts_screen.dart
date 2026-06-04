import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import 'admin_providers.dart';

class AdminPayoutsScreen extends ConsumerWidget {
  const AdminPayoutsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payouts = ref.watch(adminPayoutsProvider);

    return AppScaffold(
      title: 'Therapist payouts',
      body: payouts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No payouts'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(adminPayoutsProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final p = list[index];
                final paid = p.status == 'SUCCEEDED';
                return Card(
                  child: ListTile(
                    title: Text('\$${p.amount.toStringAsFixed(2)}'),
                    subtitle: Text(p.status),
                    trailing: paid
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : FilledButton(
                            onPressed: () async {
                              try {
                                await ref
                                    .read(billingRepositoryProvider)
                                    .markPayoutPaid(p.id);
                                ref.invalidate(adminPayoutsProvider);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Marked paid')),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed: $e')),
                                  );
                                }
                              }
                            },
                            child: const Text('Mark paid'),
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
