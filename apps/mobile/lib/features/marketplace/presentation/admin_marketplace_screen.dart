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
  List<AdminAuditEntry> _audit = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
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
      final auditRes = await api.get<List<dynamic>>('/admin/audit-logs');
      final listings = (listingsRes.data ?? [])
          .map((e) => AdminMarketplaceListing.fromJson(e as Map<String, dynamic>))
          .toList();
      final audit = (auditRes.data ?? [])
          .map((e) => AdminAuditEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() {
          _listings = listings;
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

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Marketplace moderation',
      subtitle: 'Review anonymous listings and audit trail',
      body: Column(
        children: [
          TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'Listings'),
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
