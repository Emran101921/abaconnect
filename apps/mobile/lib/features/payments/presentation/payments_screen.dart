import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_dashboard_card.dart';
import '../../../shared/widgets/app_healthcare_illustration.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_section_header.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../data/payments_repository.dart';

final parentPaymentsProvider = FutureProvider<List<PaymentModel>>((ref) {
  return ref.watch(paymentsRepositoryProvider).fetchPayments();
});

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key, this.initialPaymentId});

  final String? initialPaymentId;

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  @override
  void initState() {
    super.initState();
    final paymentId = widget.initialPaymentId;
    if (paymentId != null && paymentId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _payPendingSession(context, paymentId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final payments = ref.watch(parentPaymentsProvider);
    final formatter = NumberFormat.currency(symbol: '\$');

    return AppScaffold(
      title: 'Payments',
      floatingActionButton: GlossyFab(
        icon: Icons.add_card,
        onPressed: () => _paySession(context, ref),
        tooltip: 'Pay session',
      ),
      body: payments.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const AppHealthcareIllustration(
                      type: AppIllustrationType.progress,
                      size: 120,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No payments yet',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Session payments and receipts will appear here.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    GlossyButton(
                      title: 'Pay for a session',
                      icon: Icons.add_card,
                      variant: GlossyButtonVariant.orangeRed,
                      onPressed: () => _paySession(context, ref),
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(parentPaymentsProvider);
              await ref.read(parentPaymentsProvider.future);
            },
            child: AppContentContainer(
              child: ListView.separated(
                itemCount: list.length + 1,
                separatorBuilder: (context, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return const AppSectionHeader(
                      title: 'Payment history',
                      subtitle: 'Secure billing for therapy sessions',
                    );
                  }
                  final p = list[index - 1];
                  return AppDashboardCard(
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

  Future<void> _payPendingSession(BuildContext context, String paymentId) async {
    try {
      final result = await ref
          .read(paymentsRepositoryProvider)
          .prepareSessionPayment(paymentId);
      ref.invalidate(parentPaymentsProvider);
      if (!context.mounted) return;

      if (result.payment.isPaid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session payment already completed')),
        );
        return;
      }

      if (result.stripeConfigured && result.checkoutUrl != null) {
        _showCheckoutLink(context, result.checkoutUrl!);
      } else {
        await _confirmDemo(context, ref, paymentId);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open session payment: $e')),
        );
      }
    }
  }

  Future<void> _paySession(BuildContext context, WidgetRef ref) async {
    try {
      final result = await ref
          .read(billingRepositoryProvider)
          .createPaymentWithCheckout(
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Payment failed: $e')));
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
          GlossyButton(
            title: 'Close',
            size: GlossyButtonSize.small,
            fullWidth: false,
            variant: GlossyButtonVariant.neutral,
            onPressed: () => Navigator.pop(ctx),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Payment status synced')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Sync failed: $e')));
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          GlossyButton(
            title: 'Submit',
            size: GlossyButtonSize.small,
            fullWidth: false,
            variant: GlossyButtonVariant.greenTeal,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok != true || reason.text.trim().isEmpty) return;
    try {
      await ref
          .read(billingRepositoryProvider)
          .openDispute(paymentId: paymentId, reason: reason.text.trim());
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Dispute opened')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Payment marked as paid')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Confirm failed: $e')));
      }
    }
  }
}
