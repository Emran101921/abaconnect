import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../parent/data/parent_booking_repository.dart';
import '../../platform/data/platform_repository.dart';

final insuranceClaimsProvider =
    FutureProvider<List<InsuranceClaimItemModel>>((ref) {
  return ref.watch(platformRepositoryProvider).fetchClaims();
});

class InsuranceScreen extends ConsumerWidget {
  const InsuranceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claims = ref.watch(insuranceClaimsProvider);
    final formatter = NumberFormat.currency(symbol: '\$');

    return AppScaffold(
      title: 'Insurance',
      floatingActionButton: FloatingActionButton(
        onPressed: () => _submitClaim(context, ref),
        child: const Icon(Icons.add),
      ),
      body: claims.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No claims yet'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(insuranceClaimsProvider);
              await ref.read(insuranceClaimsProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final c = list[index];
                return Card(
                  child: ListTile(
                    title: Text(c.payerName),
                    subtitle: Text('${c.childName ?? ''} · ${c.status}'),
                    trailing: Text(formatter.format(c.billedAmount)),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _submitClaim(BuildContext context, WidgetRef ref) async {
    try {
      final children =
          await ref.read(parentBookingRepositoryProvider).fetchChildren();
      if (children.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add a child first')),
          );
        }
        return;
      }
      await ref.read(platformRepositoryProvider).submitClaim(
            childId: children.first.id,
            payerName: 'Demo Health Plan',
            amount: 200,
          );
      ref.invalidate(insuranceClaimsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Claim submitted')),
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
