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
  final _languageController = TextEditingController();
  double _radius = 25;
  bool _mapView = false;
  bool _loading = false;
  String? _locationType;
  String? _urgency;
  String? _authorizationStatus;
  List<MarketplaceRequestModel> _requests = [];

  @override
  void dispose() {
    _zipController.dispose();
    _languageController.dispose();
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
            language: _languageController.text.trim().isEmpty
                ? null
                : _languageController.text.trim(),
            locationType: _locationType,
            urgency: _urgency,
            authorizationStatus: _authorizationStatus,
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

  Future<void> _expressInterest(
    MarketplaceRequestModel request, {
    required bool requestPermission,
  }) async {
    final message = requestPermission
        ? 'I would like parent permission to review authorized child details for care coordination.'
        : "I'm available to support this anonymous service request in my coverage area.";
    try {
      await ref.read(marketplaceRepositoryProvider).submitInterest(
            marketplaceRequestId: request.id,
            message: message,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            requestPermission
                ? 'Permission request sent for parent review.'
                : 'Availability submitted for parent review.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not submit interest: $e')),
        );
      }
    }
  }

  Future<void> _reportListing(MarketplaceRequestModel request) async {
    final reasonController = TextEditingController();
    final detailsController = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report listing'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'e.g. Suspected PHI exposure',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: detailsController,
              decoration: const InputDecoration(
                labelText: 'Details (optional)',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit report'),
          ),
        ],
      ),
    );
    if (submitted != true || reasonController.text.trim().isEmpty) return;
    try {
      await ref.read(marketplaceRepositoryProvider).reportListing(
            marketplaceRequestId: request.id,
            reason: reasonController.text.trim(),
            details: detailsController.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted to compliance review.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Report failed: $e')),
        );
      }
    } finally {
      reasonController.dispose();
      detailsController.dispose();
    }
  }

  void _showRequestDetail(MarketplaceRequestModel request) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: MarketplaceRequestCard(
          request: request,
          showProviderActions: true,
          onAvailable: () {
            Navigator.pop(ctx);
            _expressInterest(request, requestPermission: false);
          },
          onRequestPermission: () {
            Navigator.pop(ctx);
            _expressInterest(request, requestPermission: true);
          },
          onViewAuthorizedDetails: () {
            Navigator.pop(ctx);
            context.push(
              '${AppRoutes.therapistMarketplace}/${request.id}/authorized-child',
            );
          },
          onReport: () {
            Navigator.pop(ctx);
            _reportListing(request);
          },
        ),
      ),
    );
  }

  Widget _requestCard(MarketplaceRequestModel request) {
    return MarketplaceRequestCard(
      request: request,
      showProviderActions: true,
      onAvailable: () => _expressInterest(request, requestPermission: false),
      onRequestPermission: () =>
          _expressInterest(request, requestPermission: true),
      onViewAuthorizedDetails: () => context.push(
        '${AppRoutes.therapistMarketplace}/${request.id}/authorized-child',
      ),
      onReport: () => _reportListing(request),
    );
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
                TextField(
                  controller: _languageController,
                  decoration: const InputDecoration(
                    labelText: 'Language',
                    hintText: 'e.g. English, Spanish',
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
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    DropdownMenu<String?>(
                      label: const Text('Location'),
                      initialSelection: _locationType,
                      dropdownMenuEntries: const [
                        DropdownMenuEntry(value: null, label: 'Any'),
                        DropdownMenuEntry(value: 'HOME', label: 'Home'),
                        DropdownMenuEntry(value: 'CLINIC', label: 'Clinic'),
                        DropdownMenuEntry(
                          value: 'TELEHEALTH',
                          label: 'Telehealth',
                        ),
                      ],
                      onSelected: (v) => setState(() => _locationType = v),
                    ),
                    DropdownMenu<String?>(
                      label: const Text('Urgency'),
                      initialSelection: _urgency,
                      dropdownMenuEntries: const [
                        DropdownMenuEntry(value: null, label: 'Any'),
                        DropdownMenuEntry(value: 'ROUTINE', label: 'Routine'),
                        DropdownMenuEntry(value: 'URGENT', label: 'Urgent'),
                      ],
                      onSelected: (v) => setState(() => _urgency = v),
                    ),
                    DropdownMenu<String?>(
                      label: const Text('Authorization'),
                      initialSelection: _authorizationStatus,
                      dropdownMenuEntries: const [
                        DropdownMenuEntry(value: null, label: 'Any'),
                        DropdownMenuEntry(
                          value: 'PARENT_SCREENING_ONLY',
                          label: 'Screening only',
                        ),
                        DropdownMenuEntry(
                          value: 'EVALUATION_NEEDED',
                          label: 'Evaluation needed',
                        ),
                        DropdownMenuEntry(
                          value: 'SERVICE_AUTHORIZED',
                          label: 'Service authorized',
                        ),
                      ],
                      onSelected: (v) =>
                          setState(() => _authorizationStatus = v),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
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
                        onPinTap: _showRequestDetail,
                      ),
                      ..._requests.map(
                        (request) => Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          child: _requestCard(request),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _requests.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _requestCard(_requests[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
