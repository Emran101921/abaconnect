import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../../../shared/widgets/role_tab_scaffold.dart';
import '../data/marketplace_repository.dart';

final marketplaceInterestsProvider = FutureProvider.autoDispose
    .family<List<MarketplaceInterestModel>, String>((ref, requestId) {
  return ref.watch(marketplaceRepositoryProvider).fetchInterests(requestId);
});

class ParentProviderCompareScreen extends ConsumerWidget {
  const ParentProviderCompareScreen({
    super.key,
    required this.marketplaceRequestId,
  });

  final String marketplaceRequestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interests = ref.watch(
      marketplaceInterestsProvider(marketplaceRequestId),
    );

    return ParentTabScaffold(
      title: 'Interested providers',
      subtitle: 'Compare before sharing details',
      body: interests.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Could not load provider interest',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  AppSnackBar.messageFromError(e),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                GlossyButton(
                  title: 'Retry',
                  icon: Icons.refresh_rounded,
                  variant: GlossyButtonVariant.neutral,
                  onPressed: () => ref.invalidate(
                    marketplaceInterestsProvider(marketplaceRequestId),
                  ),
                ),
              ],
            ),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(
                  marketplaceInterestsProvider(marketplaceRequestId),
                );
              },
              child: ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No provider interest yet.')),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(
                marketplaceInterestsProvider(marketplaceRequestId),
              );
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = list[index];
                final awaitingReview = item.status == 'PENDING_PARENT_REVIEW';
                return Card(
                  color: awaitingReview
                      ? Theme.of(context).colorScheme.secondaryContainer
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.providerName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.accountType} · ${item.verifiedStatus}'
                          '${awaitingReview ? '\nAwaiting your approval' : ''}'
                          '${item.message != null ? '\n${item.message}' : ''}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (awaitingReview) ...[
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: GlossyButton(
                              title: 'Review & share',
                              size: GlossyButtonSize.small,
                              fullWidth: false,
                              variant: GlossyButtonVariant.tealBlue,
                              onPressed: () => context.push(
                                '${AppRoutes.parentMarketplace}/$marketplaceRequestId/consent/${item.providerId}?name=${Uri.encodeComponent(item.providerName)}',
                              ),
                            ),
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
}
