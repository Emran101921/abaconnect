import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../../../shared/widgets/role_tab_scaffold.dart';
import '../data/marketplace_repository.dart';

final marketplaceInterestsProvider = FutureProvider.autoDispose
    .family<List<MarketplaceInterestModel>, String>((ref, requestId) {
  return ref.watch(marketplaceRepositoryProvider).fetchInterests(requestId);
});

final marketplaceRequestByIdProvider = FutureProvider.autoDispose
    .family<MarketplaceRequestModel?, String>((ref, requestId) async {
  final requests =
      await ref.watch(marketplaceRepositoryProvider).fetchMyRequests();
  for (final request in requests) {
    if (request.id == requestId) return request;
  }
  return null;
});

int _interestSortOrder(String status) {
  return switch (status) {
    'PENDING_PARENT_REVIEW' => 0,
    'ACCEPTED' => 1,
    'REJECTED' => 2,
    'WITHDRAWN' => 3,
    _ => 4,
  };
}

List<MarketplaceInterestModel> _sortedInterests(
  List<MarketplaceInterestModel> list,
) {
  return [...list]
    ..sort(
      (a, b) => _interestSortOrder(a.status).compareTo(
        _interestSortOrder(b.status),
      ),
    );
}

class ParentProviderCompareScreen extends ConsumerStatefulWidget {
  const ParentProviderCompareScreen({
    super.key,
    required this.marketplaceRequestId,
  });

  final String marketplaceRequestId;

  @override
  ConsumerState<ParentProviderCompareScreen> createState() =>
      _ParentProviderCompareScreenState();
}

class _ParentProviderCompareScreenState
    extends ConsumerState<ParentProviderCompareScreen> {
  Future<void> _reportProviderConcern(MarketplaceInterestModel item) async {
    final detailsController = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report concern'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Flag ${item.providerName} for compliance review. '
              'This does not share your child\'s identity.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: detailsController,
              decoration: const InputDecoration(
                labelText: 'What happened?',
                hintText: 'Describe the concern',
              ),
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          GlossyButton(
            title: 'Submit report',
            size: GlossyButtonSize.small,
            fullWidth: false,
            variant: GlossyButtonVariant.orangeRed,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (submitted != true || detailsController.text.trim().isEmpty) {
      detailsController.dispose();
      return;
    }
    try {
      await ref.read(platformRepositoryProvider).fileComplaint(
            category: 'SAFETY',
            subject:
                'Marketplace provider concern: ${item.providerName} (${item.accountType})',
            description:
                'Request ${widget.marketplaceRequestId}\n'
                'Provider ${item.providerId}\n\n'
                '${detailsController.text.trim()}',
          );
      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          'Report submitted. Our compliance team will review.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(
          context,
          'Report failed: ${AppSnackBar.messageFromError(e)}',
        );
      }
    } finally {
      detailsController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final interests = ref.watch(
      marketplaceInterestsProvider(widget.marketplaceRequestId),
    );
    final request = ref.watch(
      marketplaceRequestByIdProvider(widget.marketplaceRequestId),
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
                  onPressed: () {
                    ref.invalidate(
                      marketplaceInterestsProvider(widget.marketplaceRequestId),
                    );
                    ref.invalidate(
                      marketplaceRequestByIdProvider(widget.marketplaceRequestId),
                    );
                  },
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.go(AppRoutes.parentMarketplace),
                  child: const Text('Back to marketplace'),
                ),
              ],
            ),
          ),
        ),
        data: (list) {
          final sorted = _sortedInterests(list);
          final pendingCount = sorted
              .where((item) => item.status == 'PENDING_PARENT_REVIEW')
              .length;
          final requestStatus = request.maybeWhen(
            data: (r) => r?.status,
            orElse: () => null,
          );
          final requestMissing = request.maybeWhen(
            data: (r) => r == null,
            orElse: () => false,
          );
          final requestInactive =
              requestStatus == 'CLOSED' || requestStatus == 'PAUSED';

          Future<void> refresh() async {
            ref.invalidate(
              marketplaceInterestsProvider(widget.marketplaceRequestId),
            );
            ref.invalidate(
              marketplaceRequestByIdProvider(widget.marketplaceRequestId),
            );
            ref.invalidate(parentMarketplaceRequestsProvider);
            await ref.read(
              marketplaceInterestsProvider(widget.marketplaceRequestId).future,
            );
          }

          if (list.isEmpty) {
            return RefreshIndicator(
              onRefresh: refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (requestMissing)
                    _RequestStatusBanner(
                      icon: Icons.info_outline,
                      message:
                          'This request is no longer on your account. It may have been removed.',
                    )
                  else if (requestInactive)
                    _RequestStatusBanner(
                      icon: Icons.pause_circle_outline,
                      message: requestStatus == 'CLOSED'
                          ? 'This request is closed — new provider interest will not arrive.'
                          : 'This request is paused — providers cannot respond until you reactivate it.',
                    ),
                  const SizedBox(height: 48),
                  Center(
                    child: Text(
                      requestInactive
                          ? 'No provider interest on this request.'
                          : 'No provider interest yet.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: GlossyButton(
                      title: 'Back to marketplace',
                      icon: Icons.storefront_outlined,
                      variant: GlossyButtonVariant.neutral,
                      onPressed: () => context.go(AppRoutes.parentMarketplace),
                    ),
                  ),
                ],
              ),
            );
          }

          if (pendingCount == 0) {
            return RefreshIndicator(
              onRefresh: refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (requestInactive)
                    _RequestStatusBanner(
                      icon: Icons.pause_circle_outline,
                      message: requestStatus == 'CLOSED'
                          ? 'This request is closed. Past provider responses are shown below.'
                          : 'This request is paused. You can still review past responses.',
                    )
                  else
                    _RequestStatusBanner(
                      icon: Icons.check_circle_outline,
                      message:
                          'All provider responses reviewed. View sharing history anytime.',
                    ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.push(
                        '${AppRoutes.parentMarketplace}/${widget.marketplaceRequestId}/consents',
                      ),
                      child: const Text('Consent history'),
                    ),
                  ),
                  ...sorted.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _InterestCard(
                        item: item,
                        marketplaceRequestId: widget.marketplaceRequestId,
                        canReview: false,
                        onReportConcern: () => _reportProviderConcern(item),
                      ),
                    ),
                  ),
                  Center(
                    child: TextButton(
                      onPressed: () => context.go(AppRoutes.parentMarketplace),
                      child: const Text('Back to marketplace'),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sorted.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (requestInactive)
                        _RequestStatusBanner(
                          icon: Icons.pause_circle_outline,
                          message: requestStatus == 'CLOSED'
                              ? 'This request is closed — finish reviewing pending responses below.'
                              : 'This request is paused — you can still approve providers who already responded.',
                        ),
                      Card(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            '$pendingCount provider${pendingCount == 1 ? '' : 's'} '
                            'awaiting your review · ${sorted.length} total',
                          ),
                        ),
                      ),
                    ],
                  );
                }
                final item = sorted[index - 1];
                return _InterestCard(
                  item: item,
                  marketplaceRequestId: widget.marketplaceRequestId,
                  canReview:
                      !requestInactive &&
                      item.status == 'PENDING_PARENT_REVIEW',
                  onReportConcern: () => _reportProviderConcern(item),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _RequestStatusBanner extends StatelessWidget {
  const _RequestStatusBanner({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _InterestCard extends StatelessWidget {
  const _InterestCard({
    required this.item,
    required this.marketplaceRequestId,
    required this.canReview,
    required this.onReportConcern,
  });

  final MarketplaceInterestModel item;
  final String marketplaceRequestId;
  final bool canReview;
  final VoidCallback onReportConcern;

  @override
  Widget build(BuildContext context) {
    final awaitingReview = item.status == 'PENDING_PARENT_REVIEW';
    final statusLabel = switch (item.status) {
      'ACCEPTED' => 'Approved · details shared',
      'REJECTED' => 'Declined',
      'WITHDRAWN' => 'Withdrawn by provider',
      'PENDING_PARENT_REVIEW' => 'Awaiting your approval',
      _ => item.status,
    };

    return Card(
      color: awaitingReview && canReview
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
              '${item.accountType} · ${item.verifiedStatus}\n$statusLabel'
              '${item.message != null ? '\n${item.message}' : ''}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (canReview) ...[
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
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onReportConcern,
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: const Text('Report concern'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
