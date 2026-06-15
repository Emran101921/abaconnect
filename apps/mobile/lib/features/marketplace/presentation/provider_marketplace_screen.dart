import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_healthcare_illustration.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../../../shared/widgets/role_tab_scaffold.dart';
import '../data/marketplace_repository.dart';
import '../widgets/marketplace_approx_map.dart';
import '../widgets/marketplace_request_card.dart';
import 'provider_marketplace_onboarding_screen.dart';

enum MarketplaceProviderShell { therapist, agency }

class ProviderMarketplaceScreen extends ConsumerStatefulWidget {
  const ProviderMarketplaceScreen({
    super.key,
    this.shell = MarketplaceProviderShell.therapist,
  });

  final MarketplaceProviderShell shell;

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
  bool _hasSearched = false;
  String? _searchError;
  String? _locationType;
  String? _urgency;
  String? _authorizationStatus;
  List<MarketplaceRequestModel> _requests = [];

  String get _marketplaceBaseRoute => switch (widget.shell) {
        MarketplaceProviderShell.therapist => AppRoutes.therapistMarketplace,
        MarketplaceProviderShell.agency => AppRoutes.agencyMarketplace,
      };

  Widget _wrapMarketplaceShell({
    required String title,
    required Widget body,
    String? subtitle,
    List<Widget>? actions,
  }) {
    return switch (widget.shell) {
      MarketplaceProviderShell.therapist => TherapistTabScaffold(
          title: title,
          subtitle: subtitle,
          actions: actions,
          body: body,
        ),
      MarketplaceProviderShell.agency => AppScaffold(
          title: title,
          subtitle: subtitle,
          actions: actions,
          body: body,
        ),
    };
  }

  @override
  void dispose() {
    _zipController.dispose();
    _languageController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _searchError = null;
    });
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
      if (mounted) {
        setState(() {
          _requests = list;
          _hasSearched = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchError = e.toString();
          _hasSearched = true;
        });
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          requestPermission ? 'Request parent permission?' : 'Express availability?',
        ),
        content: Text(
          requestPermission
              ? 'Send a permission request for ${request.anonymousPublicId}. '
                  'The parent will review before any identifiable details are shared.'
              : 'Tell the parent you are available for ${request.anonymousPublicId}. '
                  'They will review your interest before sharing contact details.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          GlossyButton(
            title: requestPermission ? 'Send request' : 'Submit availability',
            size: GlossyButtonSize.small,
            fullWidth: false,
            variant: GlossyButtonVariant.tealBlue,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
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
              '$_marketplaceBaseRoute/${request.id}/authorized-child',
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
        '$_marketplaceBaseRoute/${request.id}/authorized-child',
      ),
      onReport: () => _reportListing(request),
    );
  }

  void _applySavedSearch(MarketplaceSavedSearchModel search) {
    setState(() {
      _zipController.text = search.zipCode ?? '';
      _languageController.text = search.language ?? '';
      _radius = search.radiusMiles ?? 25;
      _locationType = search.locationType;
      _urgency = search.urgency;
      _authorizationStatus = search.authorizationStatus;
    });
    _search();
  }

  Future<void> _saveCurrentSearch() async {
    final nameController = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save search & alerts'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Search name',
            hintText: 'e.g. Brooklyn speech — urgent',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          GlossyButton(
            title: 'Save',
            size: GlossyButtonSize.small,
            fullWidth: false,
            variant: GlossyButtonVariant.greenTeal,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (saved != true || nameController.text.trim().isEmpty) {
      nameController.dispose();
      return;
    }
    try {
      await ref.read(marketplaceRepositoryProvider).saveSearch(
            name: nameController.text.trim(),
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved search created. Alerts are on by default.'),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save search: $e')),
        );
      }
    } finally {
      nameController.dispose();
    }
  }

  String _savedSearchSummary(MarketplaceSavedSearchModel search) {
    String label(String? value, Map<String, String> labels) {
      if (value == null) return '';
      return labels[value] ?? value;
    }

    final parts = <String>[
      if (search.zipCode != null) 'ZIP ${search.zipCode}',
      if (search.radiusMiles != null) '${search.radiusMiles!.round()} mi',
      if (search.language != null && search.language!.isNotEmpty)
        search.language!,
      label(search.locationType, const {
        'HOME': 'Home',
        'CLINIC': 'Clinic',
        'TELEHEALTH': 'Telehealth',
      }),
      label(search.urgency, const {
        'ROUTINE': 'Routine',
        'URGENT': 'Urgent',
      }),
      label(search.authorizationStatus, const {
        'PARENT_SCREENING_ONLY': 'Screening only',
        'EVALUATION_NEEDED': 'Evaluation needed',
        'SERVICE_AUTHORIZED': 'Service authorized',
      }),
    ]..removeWhere((part) => part.isEmpty);
    return parts.isEmpty ? 'All marketplace requests' : parts.join(' · ');
  }

  Future<bool> _confirmDeleteSavedSearch(
    BuildContext ctx,
    MarketplaceSavedSearchModel search,
  ) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete saved search?'),
        content: Text(
          '"${search.name}" will be removed and alerts will stop.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
    await ref.read(marketplaceRepositoryProvider).deleteSavedSearch(search.id);
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('Deleted "${search.name}"')),
      );
    }
    return true;
  }

  Future<void> _showSavedSearches() async {
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetCtx) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              Future<List<MarketplaceSavedSearchModel>> loadSearches() {
                return ref
                    .read(marketplaceRepositoryProvider)
                    .fetchSavedSearches();
              }

              return SafeArea(
                child: DraggableScrollableSheet(
                  expand: false,
                  initialChildSize: 0.55,
                  minChildSize: 0.35,
                  maxChildSize: 0.9,
                  builder: (context, scrollController) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Saved searches & alerts',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Refresh',
                                icon: const Icon(Icons.refresh),
                                onPressed: () => setSheetState(() {}),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Get notified when new anonymous requests match your filters.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: FutureBuilder<
                                List<MarketplaceSavedSearchModel>>(
                              future: loadSearches(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                                if (snapshot.hasError) {
                                  return Center(
                                    child: Text(
                                      'Could not load saved searches: ${snapshot.error}',
                                    ),
                                  );
                                }
                                final searches = snapshot.data ?? [];
                                if (searches.isEmpty) {
                                  return Center(
                                    child: Text(
                                      'No saved searches yet. Save your current filters '
                                      'to turn on alerts.',
                                      textAlign: TextAlign.center,
                                      style:
                                          Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  );
                                }
                                return ListView.separated(
                                  controller: scrollController,
                                  itemCount: searches.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final search = searches[index];
                                    return Dismissible(
                                      key: ValueKey(search.id),
                                      direction: DismissDirection.endToStart,
                                      confirmDismiss: (_) =>
                                          _confirmDeleteSavedSearch(
                                        sheetCtx,
                                        search,
                                      ),
                                      onDismissed: (_) => setSheetState(() {}),
                                      background: Container(
                                        alignment: Alignment.centerRight,
                                        padding:
                                            const EdgeInsets.only(right: 20),
                                        color: Theme.of(context)
                                            .colorScheme
                                            .errorContainer,
                                        child: Icon(
                                          Icons.delete_outline,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onErrorContainer,
                                        ),
                                      ),
                                      child: Card(
                                        child: ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor: search.alertsEnabled
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .primaryContainer
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .surfaceContainerHighest,
                                            child: Icon(
                                              search.alertsEnabled
                                                  ? Icons.notifications_active
                                                  : Icons
                                                      .notifications_off_outlined,
                                              size: 20,
                                            ),
                                          ),
                                          title: Text(search.name),
                                          subtitle: Text(
                                            _savedSearchSummary(search),
                                          ),
                                          trailing: Switch.adaptive(
                                            value: search.alertsEnabled,
                                            onChanged: (enabled) async {
                                              await ref
                                                  .read(
                                                    marketplaceRepositoryProvider,
                                                  )
                                                  .setSavedSearchAlerts(
                                                    savedSearchId: search.id,
                                                    alertsEnabled: enabled,
                                                  );
                                              if (context.mounted) {
                                                setSheetState(() {});
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      enabled
                                                          ? 'Alerts on for "${search.name}"'
                                                          : 'Alerts off for "${search.name}"',
                                                    ),
                                                    duration: const Duration(
                                                      seconds: 2,
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                          ),
                                          onTap: () {
                                            Navigator.pop(sheetCtx);
                                            _applySavedSearch(search);
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap to apply filters · toggle alerts · swipe left to delete',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load saved searches: $e')),
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
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Could not load marketplace profile',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '$e',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                GlossyButton(
                  title: 'Retry',
                  icon: Icons.refresh_rounded,
                  variant: GlossyButtonVariant.neutral,
                  onPressed: () => ref.invalidate(providerMarketplaceProfileProvider),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (p) {
        if (p == null || !p.isReady) {
          return ProviderMarketplaceOnboardingScreen(shell: widget.shell);
        }
        return _buildBrowse(context);
      },
    );
  }

  Widget _buildBrowse(BuildContext context) {
    return _wrapMarketplaceShell(
      title: 'Marketplace',
      subtitle: 'Anonymous requests by ZIP area',
      actions: [
        IconButton(
          tooltip: 'Saved searches',
          onPressed: _showSavedSearches,
          icon: const Icon(Icons.bookmarks_outlined),
        ),
        IconButton(
          tooltip: 'Save current search',
          onPressed: _saveCurrentSearch,
          icon: const Icon(Icons.bookmark_add_outlined),
        ),
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
                GlossyButton(
                  title: 'Search requests',
                  variant: GlossyButtonVariant.bluePurple,
                  loading: _loading,
                  onPressed: _search,
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildResults(context),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    if (_loading && !_hasSearched) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 48),
              const SizedBox(height: 16),
              Text(
                'Could not load marketplace requests',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _searchError!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              GlossyButton(
                title: 'Try again',
                icon: Icons.refresh_rounded,
                variant: GlossyButtonVariant.bluePurple,
                onPressed: _search,
              ),
            ],
          ),
        ),
      );
    }

    if (!_hasSearched) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AppHealthcareIllustration(
                type: AppIllustrationType.scheduling,
                size: 100,
              ),
              const SizedBox(height: 20),
              Text(
                'Browse anonymous parent requests',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Set your ZIP radius and filters, then tap Search requests. '
                'Save frequent filters to get alerts when new matches appear.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    if (_requests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'No matching requests',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Try widening your radius, clearing filters, or saving this search for alerts.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              GlossyButton(
                title: 'Save search for alerts',
                icon: Icons.bookmark_add_outlined,
                variant: GlossyButtonVariant.tealBlue,
                size: GlossyButtonSize.small,
                onPressed: _saveCurrentSearch,
              ),
            ],
          ),
        ),
      );
    }

    if (_mapView) {
      return ListView(
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
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _requests.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _requestCard(_requests[index]),
    );
  }
}
