import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../data/admin_repository.dart';
import 'admin_providers.dart';

class AdminInsuranceScreen extends ConsumerWidget {
  const AdminInsuranceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claims = ref.watch(adminInsuranceClaimsProvider);
    final currency = NumberFormat.currency(symbol: '\$');

    return AppScaffold(
      title: 'Insurance claims',
      body: claims.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No insurance claims'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(adminInsuranceClaimsProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final c = list[index];
                final actionable = ['SUBMITTED', 'PENDING', 'UNDER_REVIEW', 'DRAFT']
                    .contains(c.status);
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${c.payerName} · ${c.status}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text('${c.childName ?? ''} · ${c.parentEmail ?? ''}'),
                        Text(currency.format(c.billedAmount)),
                        if (actionable) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            children: [
                              FilledButton(
                                onPressed: () => _update(
                                  context,
                                  ref,
                                  c,
                                  'APPROVED',
                                  c.billedAmount,
                                ),
                                child: const Text('Approve'),
                              ),
                              OutlinedButton(
                                onPressed: () => _update(
                                  context,
                                  ref,
                                  c,
                                  'DENIED',
                                  null,
                                  denial: 'Not covered under plan',
                                ),
                                child: const Text('Deny'),
                              ),
                              TextButton(
                                onPressed: () => _update(
                                  context,
                                  ref,
                                  c,
                                  'PAID',
                                  c.billedAmount,
                                ),
                                child: const Text('Mark paid'),
                              ),
                            ],
                          ),
                        ],
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

  Future<void> _update(
    BuildContext context,
    WidgetRef ref,
    AdminInsuranceClaimModel c,
    String status,
    double? approvedAmount, {
    String? denial,
  }) async {
    try {
      await ref.read(adminRepositoryProvider).updateInsuranceClaim(
            claimId: c.id,
            status: status,
            approvedAmount: approvedAmount,
            denialReason: denial,
          );
      ref.invalidate(adminInsuranceClaimsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Claim $status')),
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
}
