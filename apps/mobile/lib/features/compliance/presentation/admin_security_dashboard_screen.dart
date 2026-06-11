import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../admin/presentation/admin_providers.dart';

final adminSecurityDashboardProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
      return ref.watch(privacyRepositoryProvider).adminSecurityDashboard();
    });

class AdminSecurityDashboardScreen extends ConsumerWidget {
  const AdminSecurityDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(adminSecurityDashboardProvider);
    final users = ref.watch(adminUsersProvider);

    return AppScaffold(
      title: 'Security dashboard',
      body: dashboard.when(
        data: (d) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatTile(label: 'Active users', value: '${d['activeUsers'] ?? 0}'),
            _StatTile(
              label: 'Inactive users',
              value: '${d['inactiveUsers'] ?? 0}',
            ),
            _StatTile(
              label: 'Failed logins (24h)',
              value: '${d['failedLogins24h'] ?? 0}',
            ),
            _StatTile(
              label: 'Claim submissions (7d)',
              value: '${d['claimSubmissions7d'] ?? 0}',
            ),
            const SizedBox(height: 16),
            Text(
              'User security actions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            users.when(
              data: (list) => Column(
                children: list.take(12).map((u) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(u.fullName),
                      subtitle: Text('${u.email} · ${u.role}'),
                      trailing: u.isActive
                          ? PopupMenuButton<String>(
                              onSelected: (action) => _runAction(
                                context,
                                ref,
                                u.id,
                                action,
                              ),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'disable',
                                  child: Text('Disable user'),
                                ),
                                PopupMenuItem(
                                  value: 'reset_password',
                                  child: Text('Force password reset'),
                                ),
                                PopupMenuItem(
                                  value: 'reset_mfa',
                                  child: Text('Reset MFA'),
                                ),
                              ],
                            )
                          : const Chip(label: Text('Inactive')),
                    ),
                  );
                }).toList(),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Users: $e'),
            ),
            const SizedBox(height: 16),
            Text(
              'Recent PHI access',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if ((d['recentPhiAccess'] as List?)?.isEmpty ?? true)
              const Text('No recent entries')
            else
              ...(d['recentPhiAccess'] as List).take(5).map(
                (e) => ListTile(
                  dense: true,
                  title: Text('${e['action']} · ${e['entityType']}'),
                  subtitle: Text(e['createdAt']?.toString() ?? ''),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Security alerts',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if ((d['securityAlerts'] as List?)?.isEmpty ?? true)
              const Text('No active alerts')
            else
              ...(d['securityAlerts'] as List).map(
                (e) => ListTile(
                  dense: true,
                  leading: Icon(
                    e['severity'] == 'CRITICAL'
                        ? Icons.error
                        : Icons.warning_amber,
                  ),
                  title: Text(e['eventType']?.toString() ?? 'Alert'),
                  subtitle: Text(e['createdAt']?.toString() ?? ''),
                ),
              ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _runAction(
    BuildContext context,
    WidgetRef ref,
    String userId,
    String action,
  ) async {
    final repo = ref.read(privacyRepositoryProvider);
    try {
      switch (action) {
        case 'disable':
          await repo.adminDisableUser(userId);
          break;
        case 'reset_password':
          await repo.adminForcePasswordReset(userId);
          break;
        case 'reset_mfa':
          await repo.adminResetMfa(userId);
          break;
      }
      ref.invalidate(adminUsersProvider);
      ref.invalidate(adminSecurityDashboardProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action completed: $action')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(label),
        trailing: Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }
}
