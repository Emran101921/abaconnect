import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
                    title: Text(
                      p.description ?? 'Payment ${p.id.substring(0, 8)}',
                    ),
                    subtitle: Text(
                      '${DateFormat.yMMMd().format(p.createdAt)} · ${p.status}',
                    ),
                    isThreeLine: true,
                    trailing: Text(
                      formatter.format(p.amount),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    onTap: () => _paymentActions(context, ref, p),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _paymentActions(BuildContext context, WidgetRef ref, PaymentModel p) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!p.isPaid) ...[
              ListTile(
                leading: const Icon(Icons.check),
                title: const Text('Mark paid (demo)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDemo(context, ref, p.id);
                },
              ),
              ListTile(
                leading: const Icon(Icons.sync),
                title: const Text('Sync from Stripe'),
                onTap: () {
                  Navigator.pop(ctx);
                  _syncStripe(context, ref, p.id);
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.gavel),
              title: const Text('Open dispute'),
              onTap: () {
                Navigator.pop(ctx);
                _openDispute(context, ref, p.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _paySession(BuildContext context, WidgetRef ref) async {
    try {
      final result =
          await ref.read(billingRepositoryProvider).createPaymentWithCheckout(
                amountCents: 15000,
                description: 'ABA therapy session',
              );
      ref.invalidate(parentPaymentsProvider);
      if (!context.mounted) return;

      if (result.stripeConfigured && result.checkoutUrl != null) {
        _showCheckoutLink(context, result.checkoutUrl!);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice created — use Mark paid in demo mode'),
          ),
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

  void _showCheckoutLink(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stripe Checkout'),
        content: SelectableText(url),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Checkout link copied')),
              );
            },
            child: const Text('Copy link'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _syncStripe(
    BuildContext context,
    WidgetRef ref,
    String paymentId,
  ) async {
    try {
      await ref.read(billingRepositoryProvider).syncPayment(paymentId);
      ref.invalidate(parentPaymentsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment status synced')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    }
  }

  Future<void> _openDispute(
    BuildContext context,
    WidgetRef ref,
    String paymentId,
  ) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Open dispute'),
        content: TextField(
          controller: reason,
          decoration: const InputDecoration(labelText: 'Reason'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
        ],
      ),
    );
    if (ok != true || reason.text.trim().isEmpty) return;
    try {
      await ref.read(billingRepositoryProvider).openDispute(
            paymentId: paymentId,
            reason: reason.text.trim(),
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dispute opened')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
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
