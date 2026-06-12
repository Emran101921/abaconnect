import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';

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

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
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
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Remove'),
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
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Verify'),
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
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Suspend'),
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
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('Error: $_error'))
                    : TabBarView(
                        controller: _tabs,
                        children: [
                          RefreshIndicator(
                            onRefresh: _load,
                            child: _listings.isEmpty
                                ? ListView(
                                    children: const [
                                      SizedBox(height: 120),
                                      Center(child: Text('No marketplace listings')),
                                    ],
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: _listings.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
                                      final item = _listings[index];
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
                            child: _reports.isEmpty
                                ? ListView(
                                    children: const [
                                      SizedBox(height: 120),
                                      Center(child: Text('No marketplace reports')),
                                    ],
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: _reports.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
                                      final report = _reports[index];
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
                            child: _providers.isEmpty
                                ? ListView(
                                    children: const [
                                      SizedBox(height: 120),
                                      Center(
                                        child: Text('No pending providers'),
                                      ),
                                    ],
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: _providers.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
                                      final provider = _providers[index];
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
                            child: _audit.isEmpty
                                ? ListView(
                                    children: const [
                                      SizedBox(height: 120),
                                      Center(child: Text('No marketplace audit events')),
                                    ],
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: _audit.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
                                      final entry = _audit[index];
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
