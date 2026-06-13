import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../parent/data/parent_booking_repository.dart';
import '../data/marketplace_repository.dart';
import '../widgets/marketplace_request_card.dart';

final parentMarketplaceRequestsProvider =
    FutureProvider.autoDispose<List<MarketplaceRequestModel>>((ref) {
  return ref.watch(marketplaceRepositoryProvider).fetchMyRequests();
});

class ParentMarketplaceDashboardScreen extends ConsumerWidget {
  const ParentMarketplaceDashboardScreen({super.key});

  Future<void> _startNewRequest(BuildContext context, WidgetRef ref) async {
    try {
      final children =
          await ref.read(parentBookingRepositoryProvider).fetchChildren();
      if (!context.mounted) return;
      if (children.isEmpty) {
        AppSnackBar.showError(
          context,
          'Add a child profile first, then complete a screening to post anonymously.',
        );
        context.push(AppRoutes.parentChildren);
        return;
      }

      final child = children.length == 1
          ? children.first
          : await showModalBottomSheet<ChildModel>(
              context: context,
              showDragHandle: true,
              builder: (ctx) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Which child is this request for?',
                        style: Theme.of(ctx).textTheme.titleMedium,
                      ),
                    ),
                    ...children.map(
                      (item) => ListTile(
                        title: Text(item.displayName),
                        subtitle: Text(
                          item.zipCode != null
                              ? 'ZIP ${item.zipCode}'
                              : 'ZIP required for marketplace posting',
                        ),
                        enabled: item.zipCode?.trim().isNotEmpty ?? false,
                        onTap: () => Navigator.pop(ctx, item),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );

      if (child == null || !context.mounted) return;
      if (child.zipCode?.trim().isEmpty ?? true) {
        AppSnackBar.showError(
          context,
          'ZIP code is required on the child profile before posting.',
        );
        return;
      }

      final language = child.primaryLanguage;
      context.push(
        '${AppRoutes.parentMarketplaceOptIn}'
        '?childId=${child.id}'
        '${language != null ? '&languagePreference=${Uri.encodeComponent(language)}' : ''}',
      );
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.showError(
          context,
          'Could not start marketplace request: ${AppSnackBar.messageFromError(e)}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(parentMarketplaceRequestsProvider);

    return AppScaffold(
      title: 'Service requests',
      subtitle: 'Anonymous marketplace dashboard',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _startNewRequest(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Post request'),
      ),
      body: requests.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load requests: ${AppSnackBar.messageFromError(e)}',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (list) {
          final pendingTotal = list.fold<int>(
            0,
            (sum, request) => sum + request.interestCount,
          );
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(parentMarketplaceRequestsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (pendingTotal > 0)
                  Card(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ListTile(
                      leading: const Icon(Icons.verified_user_outlined),
                      title: Text(
                        '$pendingTotal provider${pendingTotal == 1 ? '' : 's'} awaiting review',
                      ),
                      subtitle: const Text(
                        'Tap a request below to compare providers and approve sharing.',
                      ),
                    ),
                  ),
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      children: [
                        Text(
                          'No anonymous service requests yet. Tap Post request to '
                          'share general service needs by ZIP area without revealing '
                          'your child\'s identity.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () => _startNewRequest(context, ref),
                          icon: const Icon(Icons.privacy_tip_outlined),
                          label: const Text('Post anonymous request'),
                        ),
                      ],
                    ),
                  )
                else
                  ...list.map((request) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        children: [
                          MarketplaceRequestCard(request: request),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (request.interestCount > 0)
                                FilledButton(
                                  onPressed: () => context.push(
                                    '${AppRoutes.parentMarketplace}/${request.id}/interests',
                                  ),
                                  child: Text(
                                    'Review ${request.interestCount} provider${request.interestCount == 1 ? '' : 's'}',
                                  ),
                                ),
                              if (request.status == 'ACTIVE')
                                TextButton(
                                  onPressed: () async {
                                    await ref
                                        .read(marketplaceRepositoryProvider)
                                        .pauseRequest(request.id);
                                    ref.invalidate(
                                      parentMarketplaceRequestsProvider,
                                    );
                                  },
                                  child: const Text('Pause'),
                                ),
                              if (request.status == 'PAUSED')
                                TextButton(
                                  onPressed: () async {
                                    await ref
                                        .read(marketplaceRepositoryProvider)
                                        .closeRequest(request.id);
                                    ref.invalidate(
                                      parentMarketplaceRequestsProvider,
                                    );
                                  },
                                  child: const Text('Close'),
                                ),
                              TextButton(
                                onPressed: () => context.push(
                                  '${AppRoutes.parentMarketplace}/${request.id}/consents',
                                ),
                                child: const Text('Consent history'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}
