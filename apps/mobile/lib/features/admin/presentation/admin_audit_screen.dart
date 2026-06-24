import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/app_data_table.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../data/admin_repository.dart';
import 'admin_providers.dart';

class AdminAuditScreen extends ConsumerWidget {
  const AdminAuditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audits = ref.watch(adminAuditLogsProvider);

    return AppScaffold(
      title: 'Audit logs',
      subtitle: 'Platform activity and access history',
      showPageBreadcrumbs: true,
      body: audits.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            AppSkeleton(height: 44),
            SizedBox(height: 12),
            AppSkeletonCard(lines: 4),
            AppSkeletonCard(lines: 4),
          ],
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(adminAuditLogsProvider);
              await ref.read(adminAuditLogsProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AppDataTable<AuditLogModel>(
                  rows: list,
                  searchPredicate: (log, q) {
                    final needle = q.toLowerCase();
                    return log.action.toLowerCase().contains(needle) ||
                        log.entityType.toLowerCase().contains(needle) ||
                        (log.actorEmail ?? '').toLowerCase().contains(needle);
                  },
                  columns: [
                    AppDataColumn(
                      label: 'Action',
                      mobilePriority: true,
                      cellBuilder: (context, log) => Text(
                        log.action,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    AppDataColumn(
                      label: 'Entity',
                      mobilePriority: true,
                      cellBuilder: (context, log) => Text(log.entityType),
                    ),
                    AppDataColumn(
                      label: 'Actor',
                      cellBuilder: (context, log) =>
                          Text(log.actorEmail ?? 'system'),
                    ),
                    AppDataColumn(
                      label: 'When',
                      flex: 2,
                      cellBuilder: (context, log) => Text(
                        DateFormat.yMMMd().add_jm().format(log.createdAt),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
