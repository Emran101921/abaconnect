import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/app_scaffold.dart';
import 'admin_providers.dart';

class AdminAuditScreen extends ConsumerWidget {
  const AdminAuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audits = ref.watch(adminAuditLogsProvider);

    return AppScaffold(
      title: 'Audit logs',
      body: audits.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No audit logs'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(adminAuditLogsProvider);
              await ref.read(adminAuditLogsProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final log = list[index];
                return Card(
                  child: ListTile(
                    title: Text('${log.action} · ${log.entityType}'),
                    subtitle: Text(
                      '${log.actorEmail ?? 'system'}\n'
                      '${DateFormat.yMMMd().add_jm().format(log.createdAt)}',
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
