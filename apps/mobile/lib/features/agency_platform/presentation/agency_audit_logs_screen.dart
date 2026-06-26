import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/utils/analytics_csv_export.dart';
import '../../../shared/widgets/app_data_table.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../data/agency_platform_repository.dart';
import '../utils/agency_report_export.dart';
import '../widgets/bloomora_compliance_disclaimer.dart';
import 'agency_platform_providers.dart';

class AgencyAuditLogsScreen extends ConsumerWidget {
  const AgencyAuditLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(agencyAuditLogsProvider);

    return AppScaffold(
      title: 'Audit logs',
      subtitle: 'PHI access, permission changes, and sensitive actions',
      showPageBreadcrumbs: true,
      actions: [
        logs.maybeWhen(
          data: (list) => GlossyButton(
            title: 'Export CSV',
            icon: Icons.download_outlined,
            size: GlossyButtonSize.small,
            fullWidth: false,
            onPressed: list.isEmpty
                ? null
                : () => exportAnalyticsCsv(
                      context,
                      csv: auditReportCsv(list),
                      filename: analyticsExportFilename(
                        'agency-audit',
                        'export',
                      ),
                    ),
          ),
          orElse: () => const SizedBox.shrink(),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: BloomoraComplianceDisclaimer(dense: true),
          ),
          Expanded(
            child: logs.when(
              loading: () => ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  AppSkeleton(height: 44),
                  SizedBox(height: 12),
                  AppSkeletonCard(lines: 4),
                ],
              ),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (list) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(agencyAuditLogsProvider);
                  await ref.read(agencyAuditLogsProvider.future);
                },
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    AppDataTable<AgencyAuditLogModel>(
                      rows: list,
                      searchPredicate: (log, q) {
                        final needle = q.toLowerCase();
                        return log.action.toLowerCase().contains(needle) ||
                            log.entityType.toLowerCase().contains(needle) ||
                            (log.actorRole ?? '').toLowerCase().contains(needle);
                      },
                      columns: [
                        AppDataColumn(
                          label: 'Action',
                          mobilePriority: true,
                          cellBuilder: (_, log) => Text(log.action),
                        ),
                        AppDataColumn(
                          label: 'Entity',
                          mobilePriority: true,
                          cellBuilder: (_, log) => Text(log.entityType),
                        ),
                        AppDataColumn(
                          label: 'Role',
                          cellBuilder: (_, log) => Text(log.actorRole ?? '—'),
                        ),
                        AppDataColumn(
                          label: 'When',
                          flex: 2,
                          cellBuilder: (_, log) => Text(
                            DateFormat.yMMMd().add_jm().format(log.createdAt),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
