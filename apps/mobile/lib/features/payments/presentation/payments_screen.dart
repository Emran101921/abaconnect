import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/utils/checkout_launcher.dart';
import '../../../shared/widgets/app_dashboard_card.dart';
import '../../../shared/widgets/app_healthcare_illustration.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_section_header.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../data/payments_repository.dart';

final parentPaymentsProvider = FutureProvider<List<PaymentModel>>((ref) {
  return ref.watch(paymentsRepositoryProvider).fetchPayments();
});

final paymentsConfigProvider = FutureProvider<bool>((ref) {
  return ref.watch(paymentsRepositoryProvider).fetchStripeConfigured();
});

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key, this.initialPaymentId});

  final String? initialPaymentId;

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  bool _handledDeepLink = false;

  void _maybePromptDeepLinkPayment(List<PaymentModel> list) {
    final paymentId = widget.initialPaymentId;
    if (_handledDeepLink || paymentId == null || paymentId.isEmpty) return;
    _handledDeepLink = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showDeepLinkPaymentPrompt(context, list, paymentId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final payments = ref.watch(parentPaymentsProvider);
    final stripeConfigured = ref.watch(paymentsConfigProvider);
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
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error: $e', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                GlossyButton(
                  title: 'Retry',
                  icon: Icons.refresh_rounded,
                  variant: GlossyButtonVariant.neutral,
                  onPressed: () => ref.invalidate(parentPaymentsProvider),
                ),
              ],
            ),
          ),
        ),
        data: (list) {
          _maybePromptDeepLinkPayment(list);
          if (list.isEmpty) {
            return stripeConfigured.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => _buildEmptyPayments(
                context,
                stripeConfigured: false,
              ),
              data: (configured) => _buildEmptyPayments(
                context,
                stripeConfigured: configured,
              ),
            );
          }
          final deepLinkId = widget.initialPaymentId;
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
                  final isDeepLinkTarget =
                      deepLinkId != null && p.id == deepLinkId;
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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: isDeepLinkTarget
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                              fontWeight: isDeepLinkTarget
                                  ? FontWeight.w700
                                  : null,
                            ),
                      ),
                      tileColor: isDeepLinkTarget
                          ? Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withValues(alpha: 0.35)
                          : null,
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

  Widget _buildEmptyPayments(
    BuildContext context, {
    required bool stripeConfigured,
  }) {
    final demoHint = stripeConfigured
        ? 'Stripe checkout is enabled — tap Pay for a session or open a payment '
            'notification to complete checkout.'
        : 'Stripe checkout is not configured in demo — use Mark paid (demo) '
            'when prompted, or tap Pay for a session to create a test invoice.';

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
              'When your therapist requests session payment, it appears here '
              'and you can pay from a notification or this screen.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              demoHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
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

  Future<void> _showDeepLinkPaymentPrompt(
    BuildContext context,
    List<PaymentModel> list,
    String paymentId,
  ) async {
    final formatter = NumberFormat.currency(symbol: '\$');
    PaymentModel? payment;
    for (final p in list) {
      if (p.id == paymentId) {
        payment = p;
        break;
      }
    }

    final proceed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Session payment due',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                payment == null
                    ? 'Your therapist requested payment before the session can begin.'
                    : payment.isPaid
                        ? 'This session payment is already complete.'
                        : '${payment.description ?? 'Therapy session'} · ${formatter.format(payment.amount)}',
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              if (payment?.isPaid != true) ...[
                GlossyButton(
                  title: 'Pay now',
                  icon: Icons.payments_outlined,
                  variant: GlossyButtonVariant.orangeRed,
                  onPressed: () => Navigator.pop(ctx, true),
                ),
                const SizedBox(height: 8),
              ],
              GlossyButton(
                title: payment?.isPaid == true ? 'Done' : 'View all payments',
                variant: GlossyButtonVariant.neutral,
                onPressed: () => Navigator.pop(ctx, false),
              ),
            ],
          ),
        ),
      ),
    );

    if (proceed == true && context.mounted) {
      await _payPendingSession(context, paymentId);
    }
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
        _openCheckout(context, result.checkoutUrl!);
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
        _openCheckout(context, result.checkoutUrl!);
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

  Future<void> _openCheckout(BuildContext context, String url) async {
    final opened = await launchCheckoutUrl(url);
    if (!context.mounted) return;
    if (opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Opening Stripe Checkout…')),
      );
      return;
    }
    _showCheckoutLinkFallback(context, url);
  }

  void _showCheckoutLinkFallback(BuildContext context, String url) {
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
