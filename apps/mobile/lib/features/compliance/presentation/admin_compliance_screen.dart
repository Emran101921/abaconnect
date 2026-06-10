import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../data/privacy_repository.dart';

final adminAcknowledgmentsProvider =
    FutureProvider.autoDispose<List<AdminAcknowledgmentModel>>((ref) {
      return ref.watch(privacyRepositoryProvider).adminListAcknowledgments();
    });

final adminPrivacyRequestsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      return ref.watch(privacyRepositoryProvider).adminListPrivacyRequests();
    });

final adminNoticeVersionsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      return ref.watch(privacyRepositoryProvider).adminListNoticeVersions();
    });

final adminPrivacyAuditProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      return ref.watch(privacyRepositoryProvider).adminListAuditLogs();
    });

class AdminComplianceScreen extends ConsumerWidget {
  const AdminComplianceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      title: 'Compliance',
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.verified_user),
            title: const Text('HIPAA acknowledgments'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.adminComplianceAcknowledgments),
          ),
          ListTile(
            leading: const Icon(Icons.article),
            title: const Text('Notice versions'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.adminComplianceNoticeVersions),
          ),
          ListTile(
            leading: const Icon(Icons.assignment),
            title: const Text('Privacy rights requests'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.adminCompliancePrivacyRequests),
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('Audit logs'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.adminComplianceAuditLogs),
          ),
        ],
      ),
    );
  }
}

class AdminComplianceAcknowledgmentsScreen extends ConsumerStatefulWidget {
  const AdminComplianceAcknowledgmentsScreen({super.key});

  @override
  ConsumerState<AdminComplianceAcknowledgmentsScreen> createState() =>
      _AdminComplianceAcknowledgmentsScreenState();
}

class _AdminComplianceAcknowledgmentsScreenState
    extends ConsumerState<AdminComplianceAcknowledgmentsScreen> {
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(adminAcknowledgmentsProvider);

    return AppScaffold(
      title: 'Acknowledgments',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _email,
                    decoration: const InputDecoration(
                      labelText: 'Search by email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () async {
                    final results = await ref
                        .read(privacyRepositoryProvider)
                        .adminListAcknowledgments(
                          email: _email.text.trim(),
                        );
                    if (!context.mounted) return;
                    await showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Search results'),
                        content: SizedBox(
                          width: double.maxFinite,
                          child: ListView(
                            shrinkWrap: true,
                            children: results
                                .map(
                                  (a) => ListTile(
                                    title: Text(a.userEmail),
                                    subtitle: Text(
                                      'v${a.noticeVersion} · ${a.acknowledgedAt}',
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Search'),
                ),
              ],
            ),
          ),
          Expanded(
            child: list.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(child: Text('Failed to load')),
              data: (rows) => ListView.builder(
                itemCount: rows.length,
                itemBuilder: (context, i) {
                  final a = rows[i];
                  return ListTile(
                    title: Text(a.userName.isEmpty ? a.userEmail : a.userName),
                    subtitle: Text(
                      '${a.userEmail}\nNotice v${a.noticeVersion} · ${a.acknowledgedAt.toLocal()}',
                    ),
                    isThreeLine: true,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminComplianceNoticeVersionsScreen extends ConsumerWidget {
  const AdminComplianceNoticeVersionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versions = ref.watch(adminNoticeVersionsProvider);
    return AppScaffold(
      title: 'Notice versions',
      body: versions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Failed to load')),
        data: (rows) => ListView.builder(
          itemCount: rows.length,
          itemBuilder: (context, i) {
            final v = rows[i];
            final active = v['isActive'] == true;
            return ListTile(
              title: Text('Version ${v['versionNumber']}'),
              subtitle: Text(v['title'] as String? ?? ''),
              trailing: active
                  ? const Chip(label: Text('Active'))
                  : TextButton(
                      onPressed: () async {
                        await ref
                            .read(privacyRepositoryProvider)
                            .adminPublishNoticeVersion(v['id'] as String);
                        ref.invalidate(adminNoticeVersionsProvider);
                      },
                      child: const Text('Publish'),
                    ),
            );
          },
        ),
      ),
    );
  }
}

class AdminCompliancePrivacyRequestsScreen extends ConsumerWidget {
  const AdminCompliancePrivacyRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(adminPrivacyRequestsProvider);
    return AppScaffold(
      title: 'Privacy requests',
      body: requests.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Failed to load')),
        data: (rows) => ListView.builder(
          itemCount: rows.length,
          itemBuilder: (context, i) {
            final r = rows[i];
            final user = r['user'] as Map<String, dynamic>? ?? {};
            return ListTile(
              title: Text(r['requestType'] as String? ?? ''),
              subtitle: Text(
                '${user['email'] ?? ''}\nStatus: ${r['status']}',
              ),
              isThreeLine: true,
              onTap: () => _showStatusDialog(context, ref, r),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showStatusDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> row,
  ) async {
    final notes = TextEditingController(
      text: row['internalNotes'] as String? ?? '',
    );
    String status = row['status'] as String? ?? 'NEW';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: status,
              items: const [
                'NEW',
                'IN_REVIEW',
                'COMPLETED',
                'DENIED',
                'NEEDS_MORE_INFO',
              ]
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => status = v ?? status,
              decoration: const InputDecoration(labelText: 'Status'),
            ),
            TextField(
              controller: notes,
              decoration: const InputDecoration(labelText: 'Internal notes'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await ref.read(privacyRepositoryProvider).adminUpdatePrivacyRequest(
                    row['id'] as String,
                    status: status,
                    internalNotes: notes.text.trim(),
                  );
              ref.invalidate(adminPrivacyRequestsProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    notes.dispose();
  }
}

class AdminComplianceAuditLogsScreen extends ConsumerWidget {
  const AdminComplianceAuditLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(adminPrivacyAuditProvider);
    return AppScaffold(
      title: 'Audit logs',
      body: logs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Failed to load')),
        data: (rows) => ListView.builder(
          itemCount: rows.length,
          itemBuilder: (context, i) {
            final log = rows[i];
            final meta = log['metadata'] as Map<String, dynamic>?;
            return ListTile(
              title: Text(log['action'] as String? ?? ''),
              subtitle: Text(
                '${log['resourceType'] ?? ''} · ${meta?['privacyEvent'] ?? ''}\n'
                '${log['createdAt'] ?? ''}',
              ),
              isThreeLine: true,
            );
          },
        ),
      ),
    );
  }
}
