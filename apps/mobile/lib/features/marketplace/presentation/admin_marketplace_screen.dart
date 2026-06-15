import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/glossy_button.dart';

class AdminMarketplaceListing {
  const AdminMarketplaceListing({
    required this.id,
    required this.anonymousPublicId,
    required this.serviceAreaLabel,
    required this.status,
    required this.ageRangeLabel,
  });

  final String id;
  final String anonymousPublicId;
  final String serviceAreaLabel;
  final String status;
  final String ageRangeLabel;

  factory AdminMarketplaceListing.fromJson(Map<String, dynamic> json) {
    return AdminMarketplaceListing(
      id: json['id'] as String,
      anonymousPublicId: json['anonymousPublicId'] as String,
      serviceAreaLabel: json['serviceAreaLabel'] as String? ?? '',
      status: json['status'] as String? ?? 'ACTIVE',
      ageRangeLabel: json['ageRangeLabel'] as String? ?? '',
    );
  }
}

class AdminMarketplaceReport {
  const AdminMarketplaceReport({
    required this.id,
    required this.reason,
    required this.status,
    required this.createdAt,
    required this.marketplaceRequestId,
    this.details,
    this.anonymousPublicId,
    this.reporterName,
    this.reporterEmail,
  });

  final String id;
  final String reason;
  final String? details;
  final String status;
  final DateTime createdAt;
  final String marketplaceRequestId;
  final String? anonymousPublicId;
  final String? reporterName;
  final String? reporterEmail;

  factory AdminMarketplaceReport.fromJson(Map<String, dynamic> json) {
    return AdminMarketplaceReport(
      id: json['id'] as String,
      reason: json['reason'] as String? ?? '',
      details: json['details'] as String?,
      status: json['status'] as String? ?? 'OPEN',
      createdAt: DateTime.parse(json['createdAt'] as String),
      marketplaceRequestId: json['marketplaceRequestId'] as String,
      anonymousPublicId: json['anonymousPublicId'] as String?,
      reporterName: json['reporterName'] as String?,
      reporterEmail: json['reporterEmail'] as String?,
    );
  }
}

class AdminPendingProvider {
  const AdminPendingProvider({
    required this.id,
    required this.displayName,
    required this.legalName,
    required this.accountType,
    required this.verifiedStatus,
    required this.userId,
    required this.createdAt,
  });

  final String id;
  final String displayName;
  final String legalName;
  final String accountType;
  final String verifiedStatus;
  final String userId;
  final DateTime createdAt;

  factory AdminPendingProvider.fromJson(Map<String, dynamic> json) {
    return AdminPendingProvider(
      id: json['id'] as String,
      displayName: json['displayName'] as String? ?? '',
      legalName: json['legalName'] as String? ?? '',
      accountType: json['accountType'] as String? ?? 'THERAPIST',
      verifiedStatus: json['verifiedStatus'] as String? ?? 'PENDING',
      userId: json['userId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class AdminAuditEntry {
  const AdminAuditEntry({
    required this.id,
    required this.action,
    required this.entityType,
    required this.createdAt,
  });

  final String id;
  final String action;
  final String entityType;
  final DateTime createdAt;

  factory AdminAuditEntry.fromJson(Map<String, dynamic> json) {
    return AdminAuditEntry(
      id: json['id'] as String,
      action: json['action'] as String,
      entityType: json['entityType'] as String? ?? json['entity_type'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String? ?? json['created_at'] as String),
    );
  }
}

class AdminMarketplaceScreen extends ConsumerStatefulWidget {
  const AdminMarketplaceScreen({super.key});

  @override
  ConsumerState<AdminMarketplaceScreen> createState() =>
      _AdminMarketplaceScreenState();
}

class _AdminMarketplaceScreenState extends ConsumerState<AdminMarketplaceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  var _loading = true;
  List<AdminMarketplaceListing> _listings = [];
  List<AdminMarketplaceReport> _reports = [];
  List<AdminPendingProvider> _providers = [];
  List<AdminAuditEntry> _audit = [];
  String? _error;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _listingStatusFilter;
  String? _reportStatusFilter;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabs.dispose();
    super.dispose();
  }

  bool _matchesSearch(String value) {
    if (_searchQuery.isEmpty) return true;
    return value.toLowerCase().contains(_searchQuery);
  }

  List<AdminMarketplaceListing> get _filteredListings {
    return _listings.where((item) {
      if (_listingStatusFilter != null && item.status != _listingStatusFilter) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      return _matchesSearch(item.anonymousPublicId) ||
          _matchesSearch(item.serviceAreaLabel) ||
          _matchesSearch(item.ageRangeLabel) ||
          _matchesSearch(item.status);
    }).toList();
  }

  List<AdminMarketplaceReport> get _filteredReports {
    return _reports.where((report) {
      if (_reportStatusFilter != null && report.status != _reportStatusFilter) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      return _matchesSearch(report.reason) ||
          _matchesSearch(report.status) ||
          _matchesSearch(report.marketplaceRequestId) ||
          _matchesSearch(report.anonymousPublicId ?? '') ||
          _matchesSearch(report.reporterName ?? '') ||
          _matchesSearch(report.reporterEmail ?? '') ||
          _matchesSearch(report.details ?? '');
    }).toList();
  }

  List<AdminPendingProvider> get _filteredProviders {
    return _providers.where((provider) {
      if (_searchQuery.isEmpty) return true;
      return _matchesSearch(provider.displayName) ||
          _matchesSearch(provider.legalName) ||
          _matchesSearch(provider.accountType) ||
          _matchesSearch(provider.verifiedStatus);
    }).toList();
  }

  List<AdminAuditEntry> get _filteredAudit {
    return _audit.where((entry) {
      if (_searchQuery.isEmpty) return true;
      return _matchesSearch(entry.action) || _matchesSearch(entry.entityType);
    }).toList();
  }

  Widget _statusFilterChips({
    required List<String> statuses,
    required String? selected,
    required ValueChanged<String?> onSelected,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          FilterChip(
            label: const Text('All'),
            selected: selected == null,
            onSelected: (_) => onSelected(null),
          ),
          const SizedBox(width: 8),
          ...statuses.map(
            (status) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(status),
                selected: selected == status,
                onSelected: (_) => onSelected(status),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search listings, reports, providers…',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final listingsRes = await api.get<List<dynamic>>('/admin/marketplace-requests');
      final reportsRes = await api.get<List<dynamic>>('/admin/marketplace-reports');
      final providersRes = await api.get<List<dynamic>>('/admin/marketplace-providers');
      final auditRes = await api.get<List<dynamic>>('/admin/audit-logs');
      final listings = (listingsRes.data ?? [])
          .map((e) => AdminMarketplaceListing.fromJson(e as Map<String, dynamic>))
          .toList();
      final reports = (reportsRes.data ?? [])
          .map((e) => AdminMarketplaceReport.fromJson(e as Map<String, dynamic>))
          .toList();
      final providers = (providersRes.data ?? [])
          .map((e) => AdminPendingProvider.fromJson(e as Map<String, dynamic>))
          .toList();
      final audit = (auditRes.data ?? [])
          .map((e) => AdminAuditEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() {
          _listings = listings;
          _reports = reports;
          _providers = providers;
          _audit = audit;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _removeListing(AdminMarketplaceListing listing) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Remove listing'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Reason'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            GlossyButton(
              title: 'Remove',
              size: GlossyButtonSize.small,
              fullWidth: false,
              variant: GlossyButtonVariant.redDarkRed,
              onPressed: () => Navigator.pop(ctx, controller.text),
            ),
          ],
        );
      },
    );
    if (reason == null) return;
    try {
      await ref.read(apiClientProvider).post(
        '/admin/marketplace-requests/${listing.id}/remove',
        data: {'reason': reason.isEmpty ? 'Removed by admin' : reason},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Listing removed.')),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Remove failed: $e')),
        );
      }
    }
  }

  Future<void> _verifyProvider(AdminPendingProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verify provider?'),
        content: Text(
          'Approve ${provider.displayName} for marketplace access?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          GlossyButton(
            title: 'Verify',
            size: GlossyButtonSize.small,
            fullWidth: false,
            variant: GlossyButtonVariant.greenTeal,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(apiClientProvider).post(
        '/admin/provider-agency/${provider.id}/verify',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${provider.displayName} verified.')),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verify failed: $e')),
        );
      }
    }
  }

  Widget _emptyTabList(String message, {IconData icon = Icons.inbox_outlined}) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
        Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 16),
        Center(child: Text(message, textAlign: TextAlign.center)),
      ],
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text(
              'Could not load moderation data',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              AppSnackBar.messageFromError(_error ?? 'Unknown error'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            GlossyButton(
              title: 'Retry',
              icon: Icons.refresh_rounded,
              variant: GlossyButtonVariant.neutral,
              onPressed: _load,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _suspendProvider(AdminPendingProvider provider) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Suspend provider'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Reason'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            GlossyButton(
              title: 'Suspend',
              size: GlossyButtonSize.small,
              fullWidth: false,
              variant: GlossyButtonVariant.redDarkRed,
              onPressed: () => Navigator.pop(ctx, controller.text),
            ),
          ],
        );
      },
    );
    if (reason == null) return;
    try {
      await ref.read(apiClientProvider).post(
        '/admin/users/${provider.userId}/suspend',
        data: {'reason': reason.isEmpty ? 'Suspended by admin' : reason},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${provider.displayName} suspended.')),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Suspend failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Marketplace moderation',
      subtitle: 'Listings, reports, providers, and audit trail',
      body: Column(
        children: [
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabs: const [
              Tab(text: 'Listings'),
              Tab(text: 'Reports'),
              Tab(text: 'Providers'),
              Tab(text: 'Audit log'),
            ],
          ),
          if (!_loading && _error == null) ...[
            _searchBar(),
            if (_tabs.index == 0)
              _statusFilterChips(
                statuses: const ['ACTIVE', 'PAUSED', 'CLOSED'],
                selected: _listingStatusFilter,
                onSelected: (value) =>
                    setState(() => _listingStatusFilter = value),
              )
            else if (_tabs.index == 1)
              _statusFilterChips(
                statuses: const ['OPEN', 'RESOLVED', 'DISMISSED'],
                selected: _reportStatusFilter,
                onSelected: (value) =>
                    setState(() => _reportStatusFilter = value),
              ),
          ],
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildLoadError()
                    : TabBarView(
                        controller: _tabs,
                        children: [
                          RefreshIndicator(
                            onRefresh: _load,
                            child: _filteredListings.isEmpty
                                ? _emptyTabList(
                                    _listings.isEmpty
                                        ? 'No active marketplace listings to review.'
                                        : 'No listings match your search or filter.',
                                    icon: Icons.storefront_outlined,
                                  )
                                : ListView.separated(
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    padding: const EdgeInsets.all(16),
                                    itemCount: _filteredListings.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
                                      final item = _filteredListings[index];
                                      return Card(
                                        child: ListTile(
                                          title: Text(item.anonymousPublicId),
                                          subtitle: Text(
                                            '${item.serviceAreaLabel}\n'
                                            '${item.ageRangeLabel} · ${item.status}',
                                          ),
                                          isThreeLine: true,
                                          trailing: IconButton(
                                            tooltip: 'Remove listing',
                                            icon: const Icon(Icons.block),
                                            onPressed: () => _removeListing(item),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          RefreshIndicator(
                            onRefresh: _load,
                            child: _filteredReports.isEmpty
                                ? _emptyTabList(
                                    _reports.isEmpty
                                        ? 'No marketplace reports filed yet.'
                                        : 'No reports match your search or filter.',
                                    icon: Icons.flag_outlined,
                                  )
                                : ListView.separated(
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    padding: const EdgeInsets.all(16),
                                    itemCount: _filteredReports.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
                                      final report = _filteredReports[index];
                                      return Card(
                                        child: ListTile(
                                          title: Text(report.reason),
                                          subtitle: Text(
                                            '${report.anonymousPublicId ?? report.marketplaceRequestId}\n'
                                            '${report.reporterName ?? report.reporterEmail ?? 'Reporter'}\n'
                                            '${report.details ?? ''}\n'
                                            '${report.status} · '
                                            '${DateFormat.yMMMd().add_jm().format(report.createdAt)}',
                                          ),
                                          isThreeLine: true,
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          RefreshIndicator(
                            onRefresh: _load,
                            child: _filteredProviders.isEmpty
                                ? _emptyTabList(
                                    _providers.isEmpty
                                        ? 'No providers awaiting marketplace verification.'
                                        : 'No providers match your search.',
                                    icon: Icons.verified_user_outlined,
                                  )
                                : ListView.separated(
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    padding: const EdgeInsets.all(16),
                                    itemCount: _filteredProviders.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
                                      final provider = _filteredProviders[index];
                                      return Card(
                                        child: ListTile(
                                          title: Text(provider.displayName),
                                          subtitle: Text(
                                            '${provider.accountType} · ${provider.verifiedStatus}\n'
                                            '${provider.legalName}\n'
                                            'Joined ${DateFormat.yMMMd().format(provider.createdAt)}',
                                          ),
                                          isThreeLine: true,
                                          trailing: Wrap(
                                            spacing: 4,
                                            children: [
                                              if (provider.verifiedStatus ==
                                                  'PENDING')
                                                IconButton(
                                                  tooltip: 'Verify provider',
                                                  icon: const Icon(
                                                    Icons.verified_user,
                                                  ),
                                                  onPressed: () =>
                                                      _verifyProvider(provider),
                                                ),
                                              IconButton(
                                                tooltip: 'Suspend provider',
                                                icon: const Icon(Icons.gpp_bad),
                                                onPressed: () =>
                                                    _suspendProvider(provider),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          RefreshIndicator(
                            onRefresh: _load,
                            child: _filteredAudit.isEmpty
                                ? _emptyTabList(
                                    _audit.isEmpty
                                        ? 'No marketplace audit events recorded yet.'
                                        : 'No audit events match your search.',
                                    icon: Icons.history,
                                  )
                                : ListView.separated(
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    padding: const EdgeInsets.all(16),
                                    itemCount: _filteredAudit.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
                                      final entry = _filteredAudit[index];
                                      return Card(
                                        child: ListTile(
                                          title: Text('${entry.action} · ${entry.entityType}'),
                                          subtitle: Text(
                                            DateFormat.yMMMd()
                                                .add_jm()
                                                .format(entry.createdAt),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
