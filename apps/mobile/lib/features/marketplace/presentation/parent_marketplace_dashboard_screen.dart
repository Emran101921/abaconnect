import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_select.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../../../shared/widgets/role_tab_scaffold.dart';
import '../../parent/data/parent_booking_repository.dart';
import '../data/marketplace_repository.dart';
import '../widgets/marketplace_approx_map.dart';
import '../widgets/marketplace_request_card.dart';

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

  Future<bool> _confirmAction({
    required String title,
    required String message,
    required String confirmLabel,
    GlossyButtonVariant confirmVariant = GlossyButtonVariant.orangeRed,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          GlossyButton(
            title: confirmLabel,
            size: GlossyButtonSize.small,
            fullWidth: false,
            variant: confirmVariant,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _pauseRequest(MarketplaceRequestModel request) async {
    final confirmed = await _confirmAction(
      title: 'Pause this request?',
      message:
          'Providers will not see your anonymous listing while paused. '
          'You can resume anytime and pending provider responses stay saved.',
      confirmLabel: 'Pause request',
    );
    if (!confirmed) return;
    try {
      await ref.read(marketplaceRepositoryProvider).pauseRequest(request.id);
      await _refreshRequests();
      if (mounted) {
        AppSnackBar.showSuccess(context, 'Request paused — no new provider responses.');
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          'Pause failed: ${AppSnackBar.messageFromError(e)}',
        );
      }
    }
  }

  Future<void> _resumeRequest(MarketplaceRequestModel request) async {
    try {
      await ref.read(marketplaceRepositoryProvider).resumeRequest(request.id);
      await _refreshRequests();
      if (mounted) {
        AppSnackBar.showSuccess(context, 'Request active again — providers can respond.');
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          'Resume failed: ${AppSnackBar.messageFromError(e)}',
        );
      }
    }
  }

  Future<void> _closeRequest(MarketplaceRequestModel request) async {
    final confirmed = await _confirmAction(
      title: 'Close this request?',
      message:
          'This permanently stops new provider interest. '
          'You can still review past responses and consent history.',
      confirmLabel: 'Close request',
    );
    if (!confirmed) return;
    try {
      await ref.read(marketplaceRepositoryProvider).closeRequest(request.id);
      await _refreshRequests();
      if (mounted) {
        AppSnackBar.showSuccess(context, 'Request closed.');
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          'Close failed: ${AppSnackBar.messageFromError(e)}',
        );
      }
    }
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

      ChildModel? child;
      if (children.length == 1) {
        child = children.first;
      } else {
        final pickedId = await AppSelect.show<String>(
          context: context,
          title: 'Which child is this request for?',
          options: children
              .map(
                (item) => AppSelectOption(
                  value: item.id,
                  label: item.displayName,
                  subtitle: item.zipCode != null
                      ? 'ZIP ${item.zipCode}'
                      : 'ZIP required for marketplace posting',
                  enabled: item.zipCode?.trim().isNotEmpty ?? false,
                ),
              )
              .toList(),
        );
        if (!context.mounted || pickedId == null) return;
        child = children.firstWhere((c) => c.id == pickedId);
      }

      if (!context.mounted) return;
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
        if (request.pendingInterestCount > 0)
          GlossyButton(
            title:
                'Review ${request.pendingInterestCount} provider${request.pendingInterestCount == 1 ? '' : 's'}',
            icon: Icons.verified_user_rounded,
            variant: GlossyButtonVariant.success,
            size: GlossyButtonSize.small,
            fullWidth: false,
            iconLeading: true,
            showTrailingIcon: false,
            semanticLabel:
                'Review ${request.pendingInterestCount} providers awaiting approval',
            onPressed: () async {
              await context.push(
                '${AppRoutes.parentMarketplace}/${request.id}/interests',
              );
              if (mounted) {
                ref.invalidate(parentMarketplaceRequestsProvider);
              }
            },
          ),
        if (request.status == 'ACTIVE')
          TextButton(
            onPressed: () => _pauseRequest(request),
            child: const Text('Pause'),
          ),
        if (request.status == 'PAUSED') ...[
          TextButton(
            onPressed: () => _resumeRequest(request),
            child: const Text('Resume'),
          ),
          TextButton(
            onPressed: () => _closeRequest(request),
            child: const Text('Close'),
          ),
        ],
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
            (sum, request) => sum + request.pendingInterestCount,
          );
          MarketplaceRequestModel? firstPendingRequest;
          for (final request in list) {
            if (request.pendingInterestCount > 0) {
              firstPendingRequest = request;
              break;
            }
          }
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
                            leading: Semantics(
                              label: '$pendingTotal providers awaiting review',
                              child: Badge(
                                label: Text('$pendingTotal'),
                                child: const Icon(Icons.verified_user_outlined),
                              ),
                            ),
                            title: Text(
                              '$pendingTotal provider${pendingTotal == 1 ? '' : 's'} awaiting review',
                            ),
                            subtitle: const Text(
                              'Tap to compare providers and approve sharing.',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: firstPendingRequest == null
                                ? null
                                : () async {
                                    await context.push(
                                      '${AppRoutes.parentMarketplace}/${firstPendingRequest!.id}/interests',
                                    );
                                    if (mounted) {
                                      ref.invalidate(
                                        parentMarketplaceRequestsProvider,
                                      );
                                    }
                                  },
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
