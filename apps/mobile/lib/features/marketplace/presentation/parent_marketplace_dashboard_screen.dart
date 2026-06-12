import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../data/marketplace_repository.dart';
import '../widgets/marketplace_request_card.dart';

final parentMarketplaceRequestsProvider =
    FutureProvider<List<MarketplaceRequestModel>>((ref) {
  return ref.watch(marketplaceRepositoryProvider).fetchMyRequests();
});

class ParentMarketplaceDashboardScreen extends ConsumerWidget {
  const ParentMarketplaceDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(parentMarketplaceRequestsProvider);

    return AppScaffold(
      title: 'Service requests',
      subtitle: 'Anonymous marketplace dashboard',
      body: requests.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No anonymous service requests yet. Complete a screening and opt in '
                  'to post a request providers can respond to by ZIP area.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(parentMarketplaceRequestsProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final request = list[index];
                return Column(
                  children: [
                    MarketplaceRequestCard(request: request),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (request.status == 'ACTIVE')
                          TextButton(
                            onPressed: () async {
                              await ref
                                  .read(marketplaceRepositoryProvider)
                                  .pauseRequest(request.id);
                              ref.invalidate(parentMarketplaceRequestsProvider);
                            },
                            child: const Text('Pause'),
                          ),
                        if (request.status == 'PAUSED')
                          TextButton(
                            onPressed: () async {
                              await ref
                                  .read(marketplaceRepositoryProvider)
                                  .closeRequest(request.id);
                              ref.invalidate(parentMarketplaceRequestsProvider);
                            },
                            child: const Text('Close'),
                          ),
                        TextButton(
                          onPressed: () => context.push(
                            '${AppRoutes.parentMarketplace}/${request.id}/consents',
                          ),
                          child: const Text('Consent history'),
                        ),
                        if (request.interestCount > 0)
                          TextButton(
                            onPressed: () => context.push(
                              '${AppRoutes.parentMarketplace}/${request.id}/interests',
                            ),
                            child: Text(
                              'View ${request.interestCount} interested provider(s)',
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}
