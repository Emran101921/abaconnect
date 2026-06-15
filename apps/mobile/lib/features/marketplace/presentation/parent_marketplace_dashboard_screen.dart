import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../../../shared/widgets/role_tab_scaffold.dart';
import '../../parent/data/parent_booking_repository.dart';
import '../data/marketplace_repository.dart';
import '../widgets/marketplace_approx_map.dart';
import '../widgets/marketplace_request_card.dart';

final parentMarketplaceRequestsProvider =
    FutureProvider.autoDispose<List<MarketplaceRequestModel>>((ref) {
  return ref.watch(marketplaceRepositoryProvider).fetchMyRequests();
});

class ParentMarketplaceDashboardScreen extends ConsumerStatefulWidget {
  const ParentMarketplaceDashboardScreen({super.key});

  @override
  ConsumerState<ParentMarketplaceDashboardScreen> createState() =>
      _ParentMarketplaceDashboardScreenState();
}

class _ParentMarketplaceDashboardScreenState
    extends ConsumerState<ParentMarketplaceDashboardScreen> {
  var _mapView = false;

  Future<void> _refreshRequests() async {
    ref.invalidate(parentMarketplaceRequestsProvider);
    await ref.read(parentMarketplaceRequestsProvider.future);
  }

  Future<void> _startNewRequest(BuildContext context) async {
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
              isScrollControlled: true,
              builder: (ctx) => SafeArea(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 16),
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

  Widget _buildRequestActions(MarketplaceRequestModel request) {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 4,
      runSpacing: 4,
      children: [
        if (request.interestCount > 0)
          GlossyButton(
            title:
                'Review ${request.interestCount} provider${request.interestCount == 1 ? '' : 's'}',
            icon: Icons.verified_user_rounded,
            variant: GlossyButtonVariant.success,
            size: GlossyButtonSize.small,
            fullWidth: false,
            iconLeading: true,
            showTrailingIcon: false,
            onPressed: () => context.push(
              '${AppRoutes.parentMarketplace}/${request.id}/interests',
            ),
          ),
        if (request.status == 'ACTIVE')
          TextButton(
            onPressed: () async {
              await ref.read(marketplaceRepositoryProvider).pauseRequest(request.id);
              await _refreshRequests();
            },
            child: const Text('Pause'),
          ),
        if (request.status == 'PAUSED')
          TextButton(
            onPressed: () async {
              await ref.read(marketplaceRepositoryProvider).closeRequest(request.id);
              await _refreshRequests();
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
    );
  }

  List<Widget> _requestTiles(List<MarketplaceRequestModel> list) {
    return list.map((request) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          children: [
            MarketplaceRequestCard(request: request),
            _buildRequestActions(request),
          ],
        ),
      );
    }).toList();
  }

  List<Widget> _mapTiles(List<MarketplaceRequestModel> list) {
    return [
      MarketplaceApproxMap(
        requests: list,
        emptyMessage:
            'Service area map appears here once your posted requests have ZIP pins.',
      ),
      ...list.map((request) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
          child: Column(
            children: [
              MarketplaceRequestCard(request: request),
              _buildRequestActions(request),
            ],
          ),
        );
      }),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(parentMarketplaceRequestsProvider);

    return ParentTabScaffold(
      title: 'Service requests',
      subtitle: 'Anonymous marketplace dashboard',
      actions: [
        IconButton(
          tooltip: _mapView ? 'List view' : 'Map view',
          onPressed: () => setState(() => _mapView = !_mapView),
          icon: Icon(_mapView ? Icons.list : Icons.map_outlined),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Center(
            child: GlossyButton(
              title: 'Post request',
              icon: Icons.add_rounded,
              iconOnly: true,
              size: GlossyButtonSize.small,
              fullWidth: false,
              semanticLabel: 'Post request',
              onPressed: () => _startNewRequest(context),
            ),
          ),
        ),
      ],
      body: requests.when(
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
                  'Could not load requests',
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
                  onPressed: _refreshRequests,
                ),
              ],
            ),
          ),
        ),
        data: (list) {
          final pendingTotal = list.fold<int>(
            0,
            (sum, request) => sum + request.interestCount,
          );
          return RefreshIndicator(
            onRefresh: _refreshRequests,
            child: list.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
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
                            GlossyButton(
                              title: 'Post anonymous request',
                              icon: Icons.privacy_tip_outlined,
                              variant: GlossyButtonVariant.tealBlue,
                              onPressed: () => _startNewRequest(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (pendingTotal > 0)
                        Card(
                          color: Theme.of(context).colorScheme.secondaryContainer,
                          margin: const EdgeInsets.only(bottom: 16),
                          child: ListTile(
                            leading: Badge(
                              label: Text('$pendingTotal'),
                              child: const Icon(Icons.verified_user_outlined),
                            ),
                            title: Text(
                              '$pendingTotal provider${pendingTotal == 1 ? '' : 's'} awaiting review',
                            ),
                            subtitle: const Text(
                              'Tap a request below to compare providers and approve sharing.',
                            ),
                          ),
                        ),
                      if (_mapView) ..._mapTiles(list) else ..._requestTiles(list),
                    ],
                  ),
          );
        },
      ),
    );
  }
}
