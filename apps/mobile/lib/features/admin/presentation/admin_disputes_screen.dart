import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import 'admin_providers.dart';

class AdminDisputesScreen extends ConsumerWidget {
  const AdminDisputesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disputes = ref.watch(adminPaymentDisputesProvider);

    return AppScaffold(
      title: 'Payment disputes',
      body: disputes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No open payment disputes'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(adminPaymentDisputesProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final d = list[index];
                return Card(
                  child: ListTile(
                    title: Text(d.reason),
                    subtitle: Text(
                      '${d.status}\nPayment: ${d.paymentId ?? '—'}',
                    ),
                    isThreeLine: true,
                    trailing: FilledButton(
                      onPressed: () async {
                        try {
                          await ref
                              .read(billingRepositoryProvider)
                              .resolveDispute(d.id, 'Refunded per policy');
                          ref.invalidate(adminPaymentDisputesProvider);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Dispute resolved')),
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
                      child: const Text('Resolve'),
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
