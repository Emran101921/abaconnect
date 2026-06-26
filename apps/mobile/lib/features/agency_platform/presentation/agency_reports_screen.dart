import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/layout/dashboard_card.dart';
import '../../../shared/models/analytics_date_range.dart';
import '../../../shared/utils/analytics_csv_export.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../../agency/data/agency_repository.dart';
import '../../agency/presentation/agency_providers.dart';
import '../data/agency_platform_repository.dart';
import '../utils/agency_report_export.dart';

class AgencyReportsScreen extends ConsumerStatefulWidget {
  const AgencyReportsScreen({super.key});

  @override
  ConsumerState<AgencyReportsScreen> createState() =>
      _AgencyReportsScreenState();
}

class _AgencyReportsScreenState extends ConsumerState<AgencyReportsScreen> {
  var _step = 0;
  String _reportType = 'productivity';
  AnalyticsDateRangePreset _preset = AnalyticsDateRangePreset.last30Days;

  static const _reportTypes = <String, String>{
    'productivity': 'Provider productivity',
    'billing': 'Billing pipeline',
    'compliance': 'Compliance & signatures',
    'audit': 'Audit export',
  };

  @override
  Widget build(BuildContext context) {
    final range = _preset.range;
    return AppScaffold(
      title: 'Reports',
      subtitle: 'Operational and financial reporting wizard',
      showPageBreadcrumbs: true,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DashboardCard(
            title: 'Report wizard',
            subtitle: 'Step ${_step + 1} of 3',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(value: (_step + 1) / 3),
                const SizedBox(height: 16),
                if (_step == 0) ...[
                  const Text('Choose report type'),
                  const SizedBox(height: 8),
                  ..._reportTypes.entries.map(
                    (entry) => RadioListTile<String>(
                      value: entry.key,
                      groupValue: _reportType,
                      onChanged: (v) => setState(() => _reportType = v!),
                      title: Text(entry.value),
                    ),
                  ),
                ] else if (_step == 1) ...[
                  const Text('Date range'),
                  const SizedBox(height: 8),
                  SegmentedButton<AnalyticsDateRangePreset>(
                    segments: AnalyticsDateRangePreset.values
                        .map(
                          (preset) => ButtonSegment(
                            value: preset,
                            label: Text(preset.label),
                          ),
                        )
                        .toList(),
                    selected: {_preset},
                    onSelectionChanged: (values) {
                      setState(() => _preset = values.first);
                    },
                  ),
                ] else ...[
                  Text('Preview: ${_reportTypes[_reportType]}'),
                  const SizedBox(height: 8),
                  Text(
                    'Range: ${range.label}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Download a CSV snapshot for the selected report type and date range.',
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (_step > 0)
                      TextButton(
                        onPressed: () => setState(() => _step -= 1),
                        child: const Text('Back'),
                      ),
                    const Spacer(),
                    if (_step < 2)
                      GlossyButton(
                        title: 'Next',
                        fullWidth: false,
                        size: GlossyButtonSize.small,
                        onPressed: () => setState(() => _step += 1),
                      )
                    else ...[
                      TextButton(
                        onPressed: () => _openLiveView(context, range),
                        child: const Text('Open live view'),
                      ),
                      const SizedBox(width: 8),
                      GlossyButton(
                        title: 'Export CSV',
                        icon: Icons.download_outlined,
                        fullWidth: false,
                        size: GlossyButtonSize.small,
                        onPressed: () => _exportReport(context, range),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          DashboardCard(
            title: 'Quick operational reports',
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.draw_outlined),
                  title: const Text('Unsigned session notes'),
                  subtitle: const Text('Providers and caregivers'),
                  onTap: () => context.push(
                    '${AppRoutes.agencyHome}/session-notes',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: const Text('Billing pipeline'),
                  onTap: () => context.push(AppRoutes.agencyEiBilling),
                ),
                ListTile(
                  leading: const Icon(Icons.history_outlined),
                  title: const Text('Audit log export'),
                  onTap: () => context.push(AppRoutes.agencyAuditLogs),
                ),
                ListTile(
                  leading: const Icon(Icons.analytics_outlined),
                  title: const Text('Analytics dashboards'),
                  onTap: () {
                    ref.read(agencyAnalyticsDateRangeProvider.notifier).state =
                        range;
                    context.push('${AppRoutes.agencyHome}/analytics');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openLiveView(BuildContext context, AnalyticsDateRange range) {
    switch (_reportType) {
      case 'billing':
        context.push(AppRoutes.agencyEiBilling);
      case 'compliance':
        context.push('${AppRoutes.agencyHome}/session-notes');
      case 'audit':
        context.push(AppRoutes.agencyAuditLogs);
      case 'productivity':
      default:
        ref.read(agencyAnalyticsDateRangeProvider.notifier).state = range;
        context.push('${AppRoutes.agencyHome}/analytics');
    }
  }

  Future<void> _exportReport(
    BuildContext context,
    AnalyticsDateRange range,
  ) async {
    try {
      final repo = ref.read(agencyRepositoryProvider);
      final platformRepo = ref.read(agencyPlatformRepositoryProvider);
      late final String csv;
      late final String filename;

      switch (_reportType) {
        case 'billing':
          final claims = <AgencyClaimSummaryModel>[];
          for (final status in const [
            'DRAFT',
            'SUBMITTED',
            'PENDING',
            'PAID',
            'DENIED',
          ]) {
            final batch = await repo.fetchAnalyticsClaimsList(
              status,
              limit: 500,
              fromDate: range.graphqlFrom,
              toDate: range.graphqlTo,
            );
            claims.addAll(batch);
          }
          csv = claimsCsvFromAgency(claims);
          filename = analyticsExportFilename(
            'agency-report',
            'billing',
            dateRangeSuffix: range.filenameSuffix,
          );
        case 'compliance':
          final notes = await repo.fetchSessionNotes();
          csv = complianceReportCsv(notes);
          filename = analyticsExportFilename(
            'agency-report',
            'compliance',
            dateRangeSuffix: range.filenameSuffix,
          );
        case 'audit':
          final logs = await platformRepo.fetchAuditLogs();
          csv = auditReportCsv(logs);
          filename = analyticsExportFilename(
            'agency-report',
            'audit',
            dateRangeSuffix: range.filenameSuffix,
          );
        case 'productivity':
        default:
          final metrics = await repo.fetchTenantAnalytics(
            fromDate: range.graphqlFrom,
            toDate: range.graphqlTo,
          );
          csv = productivityReportCsv(metrics, range.label);
          filename = analyticsExportFilename(
            'agency-report',
            'productivity',
            dateRangeSuffix: range.filenameSuffix,
          );
      }

      if (!context.mounted) return;
      await exportAnalyticsCsv(context, csv: csv, filename: filename);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }
}
