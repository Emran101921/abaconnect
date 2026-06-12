import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../data/marketplace_repository.dart';
import '../widgets/marketplace_approx_map.dart';
import '../widgets/marketplace_request_card.dart';
import 'provider_marketplace_onboarding_screen.dart';

class ProviderMarketplaceScreen extends ConsumerStatefulWidget {
  const ProviderMarketplaceScreen({super.key});

  @override
  ConsumerState<ProviderMarketplaceScreen> createState() =>
      _ProviderMarketplaceScreenState();
}

class _ProviderMarketplaceScreenState
    extends ConsumerState<ProviderMarketplaceScreen> {
  final _zipController = TextEditingController();
  double _radius = 25;
  bool _mapView = false;
  bool _loading = false;
  List<MarketplaceRequestModel> _requests = [];

  @override
  void dispose() {
    _zipController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      final list = await ref.read(marketplaceRepositoryProvider).browseRequests(
            zipCode: _zipController.text.trim().isEmpty
                ? null
                : _zipController.text.trim(),
            radiusMiles: _radius,
          );
      if (mounted) setState(() => _requests = list);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _expressInterest(MarketplaceRequestModel request) async {
    try {
      await ref.read(marketplaceRepositoryProvider).submitInterest(
            marketplaceRequestId: request.id,
            message: "I'm available to support this service request.",
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Interest submitted for parent review.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not submit interest: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(providerMarketplaceProfileProvider);
    return profile.when(
      loading: () => const AppScaffold(
        title: 'Marketplace',
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AppScaffold(
        title: 'Marketplace',
        body: Center(child: Text('Error: $e')),
      ),
      data: (p) {
        if (p == null || !p.isReady) {
          return const ProviderMarketplaceOnboardingScreen();
        }
        return _buildBrowse(context);
      },
    );
  }

  Widget _buildBrowse(BuildContext context) {
    return AppScaffold(
      title: 'Marketplace',
      subtitle: 'Anonymous requests by ZIP area',
      actions: [
        IconButton(
          tooltip: _mapView ? 'List view' : 'Map view',
          onPressed: () => setState(() => _mapView = !_mapView),
          icon: Icon(_mapView ? Icons.list : Icons.map_outlined),
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _zipController,
                  decoration: const InputDecoration(
                    labelText: 'ZIP code',
                    hintText: 'Filter by service area',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Radius (mi)'),
                    Expanded(
                      child: Slider(
                        value: _radius,
                        min: 1,
                        max: 50,
                        divisions: 49,
                        label: _radius.round().toString(),
                        onChanged: (v) => setState(() => _radius = v),
                      ),
                    ),
                  ],
                ),
                FilledButton(
                  onPressed: _loading ? null : _search,
                  child: _loading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Search requests'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _mapView
                ? ListView(
                    children: [
                      MarketplaceApproxMap(
                        requests: _requests,
                        onPinTap: _expressInterest,
                      ),
                      ..._requests.map(
                        (request) => Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          child: MarketplaceRequestCard(
                            request: request,
                            showProviderActions: true,
                            onAvailable: () => _expressInterest(request),
                            onRequestPermission: () => _expressInterest(request),
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _requests.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final request = _requests[index];
                      return MarketplaceRequestCard(
                        request: request,
                        showProviderActions: true,
                        onAvailable: () => _expressInterest(request),
                        onRequestPermission: () => _expressInterest(request),
                        onViewAuthorizedDetails: () => context.push(
                          '${AppRoutes.therapistMarketplace}/${request.id}/authorized-child',
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
