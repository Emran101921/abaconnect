import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../data/payments_repository.dart';

final parentPaymentsProvider = FutureProvider<List<PaymentModel>>((ref) {
  return ref.watch(paymentsRepositoryProvider).fetchPayments();
});

class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payments = ref.watch(parentPaymentsProvider);
    final formatter = NumberFormat.currency(symbol: '\$');

    return AppScaffold(
      title: 'Payments',
      floatingActionButton: FloatingActionButton(
        onPressed: () => _paySession(context, ref),
        child: const Icon(Icons.add_card),
      ),
      body: payments.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No payments yet.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => _paySession(context, ref),
                    child: const Text('Pay for a session'),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(parentPaymentsProvider);
              await ref.read(parentPaymentsProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (context, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final p = list[index];
                return Card(
                  child: ListTile(
                    title: Text(p.description ?? 'Payment ${p.id.substring(0, 8)}'),
                    subtitle: Text(
                      '${DateFormat.yMMMd().format(p.createdAt)} · ${p.status}',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatter.format(p.amount),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (!p.isPaid)
                          TextButton(
                            onPressed: () => _confirmDemo(context, ref, p.id),
                            child: const Text('Mark paid'),
                          ),
                      ],
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

  Future<void> _paySession(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(paymentsRepositoryProvider).createPayment(
            amountCents: 15000,
            description: 'ABA therapy session',
          );
      ref.invalidate(parentPaymentsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice created (pending payment)')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: $e')),
        );
      }
    }
  }

  Future<void> _confirmDemo(
    BuildContext context,
    WidgetRef ref,
    String paymentId,
  ) async {
    try {
      await ref.read(paymentsRepositoryProvider).confirmPaymentDemo(paymentId);
      ref.invalidate(parentPaymentsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment marked as paid')),
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
}
