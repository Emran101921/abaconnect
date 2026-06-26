import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/layout/dashboard_card.dart';
import '../../../shared/models/analytics_date_range.dart';
import '../../../shared/utils/analytics_csv_export.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../data/agency_platform_repository.dart';
import '../utils/agency_report_export.dart';

final agencyPayrollRunProvider =
    FutureProvider.family<AgencyPayrollRunPreviewModel, AnalyticsDateRange>((
  ref,
  range,
) async {
  return ref.watch(agencyPlatformRepositoryProvider).fetchPayrollRunPreview(
        from: range.from ?? analyticsToday.subtract(const Duration(days: 29)),
        to: range.to ?? analyticsToday,
      );
});

class AgencyPayrollScreen extends ConsumerStatefulWidget {
  const AgencyPayrollScreen({super.key});

  @override
  ConsumerState<AgencyPayrollScreen> createState() =>
      _AgencyPayrollScreenState();
}

class _AgencyPayrollScreenState extends ConsumerState<AgencyPayrollScreen> {
  AnalyticsDateRangePreset _preset = AnalyticsDateRangePreset.last30Days;

  @override
  Widget build(BuildContext context) {
    final range = _preset.range;
    final from = range.from ?? analyticsToday.subtract(const Duration(days: 29));
    final to = range.to ?? analyticsToday;
    final preview = ref.watch(agencyPayrollRunProvider(range));
    final currency = NumberFormat.currency(symbol: '\$');

    return AppScaffold(
      title: 'Payroll runs',
      subtitle: 'Estimated provider pay from completed sessions',
      showPageBreadcrumbs: true,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DashboardCard(
            title: 'Pay period',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                const SizedBox(height: 8),
                Text(
                  '${DateFormat.yMMMd().format(from)} – ${DateFormat.yMMMd().format(to)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          preview.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => DashboardCard(
              title: 'Preview unavailable',
              child: Text('$e'),
            ),
            data: (run) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DashboardCard(
                    title: 'Run total (estimated)',
                    subtitle:
                        '${run.lines.length} provider${run.lines.length == 1 ? '' : 's'}',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currency.format(run.totalEstimatedPayCents / 100),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        GlossyButton(
                          title: 'Export CSV',
                          icon: Icons.download_outlined,
                          size: GlossyButtonSize.small,
                          fullWidth: false,
                          onPressed: () => exportAnalyticsCsv(
                            context,
                            csv: payrollRunCsv(run),
                            filename: analyticsExportFilename(
                              'agency-payroll',
                              'run',
                              dateRangeSuffix: '-${range.label.toLowerCase().replaceAll(' ', '-')}',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (run.lines.isEmpty)
                    const DashboardCard(
                      title: 'No completed sessions',
                      child: Text(
                        'No completed agency sessions were found in this date range.',
                      ),
                    )
                  else
                    ...run.lines.map(
                      (line) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: DashboardCard(
                          title: line.therapistName,
                          subtitle: line.rateDisplay,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text('${line.sessionCount} sessions'),
                              ),
                              Text('${line.hours.toStringAsFixed(1)} hrs'),
                              const SizedBox(width: 12),
                              Text(
                                currency.format(line.estimatedPayCents / 100),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
