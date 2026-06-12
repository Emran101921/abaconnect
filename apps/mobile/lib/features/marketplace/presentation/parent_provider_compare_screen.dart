import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../data/marketplace_repository.dart';

class ParentProviderCompareScreen extends ConsumerWidget {
  const ParentProviderCompareScreen({
    super.key,
    required this.marketplaceRequestId,
  });

  final String marketplaceRequestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interests = ref.watch(
      FutureProvider(
        (ref) => ref
            .watch(marketplaceRepositoryProvider)
            .fetchInterests(marketplaceRequestId),
      ),
    );

    return AppScaffold(
      title: 'Interested providers',
      subtitle: 'Compare before sharing details',
      body: interests.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No provider interest yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = list[index];
              return Card(
                child: ListTile(
                  title: Text(item.providerName),
                  subtitle: Text(
                    '${item.accountType} · ${item.verifiedStatus}'
                    '${item.message != null ? '\n${item.message}' : ''}',
                  ),
                  isThreeLine: item.message != null,
                  trailing: FilledButton(
                    onPressed: () => context.push(
                      '${AppRoutes.parentMarketplace}/$marketplaceRequestId/consent/${item.providerId}?name=${Uri.encodeComponent(item.providerName)}',
                    ),
                    child: const Text('Review & share'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
