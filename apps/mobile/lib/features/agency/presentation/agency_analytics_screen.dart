import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';

import '../../../shared/models/analytics_date_range.dart';
import '../../../shared/models/analytics_metric.dart';
import '../../../shared/presentation/analytics_copy_link.dart';
import '../../../shared/presentation/analytics_date_range_filter.dart';
import '../../../shared/presentation/analytics_date_range_url.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../admin/presentation/admin_stat_card.dart';
import '../data/agency_repository.dart';
import 'agency_providers.dart';

class AgencyAnalyticsScreen extends ConsumerWidget {
  const AgencyAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(agencyAnalyticsProvider);
    final claims = ref.watch(agencyClaimsPipelineProvider);
    final screenings = ref.watch(agencyScreeningFunnelProvider);
    final dateRange = ref.watch(agencyAnalyticsDateRangeProvider);
    final currency = NumberFormat.currency(symbol: '\$');
    final dateFormat = DateFormat.yMMMd();

    Future<void> refresh() async {
      ref.invalidate(agencyAnalyticsProvider);
      ref.invalidate(agencyClaimsPipelineProvider);
      ref.invalidate(agencyScreeningFunnelProvider);
      await Future.wait([
        ref.read(agencyAnalyticsProvider.future),
        ref.read(agencyClaimsPipelineProvider.future),
        ref.read(agencyScreeningFunnelProvider.future),
      ]);
    }

    final loading = metrics.isLoading ||
        claims.isLoading ||
        screenings.isLoading;
    if (loading) {
      return const AppScaffold(
        title: 'Analytics',
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final error = metrics.hasError
        ? metrics.error
        : claims.hasError
            ? claims.error
            : screenings.hasError
                ? screenings.error
                : null;
    if (error != null) {
      return AppScaffold(
        title: 'Analytics',
        body: Center(child: Text('Error: $error')),
      );
    }

    final metricList = metrics.requireValue;
    final pipeline = claims.requireValue;
    final funnel = screenings.requireValue;

    String metricLabel(String key) => analyticsOverviewMetricLabel(
          key,
          dateRange,
          activeChildrenLabel: 'Active clients',
        );

    return AnalyticsDateRangeSync(
      dateRangeProvider: agencyAnalyticsDateRangeProvider,
      defaultPreset: analyticsDefaultDateRangePreset,
      defaultSuppressedProvider:
          agencyAnalyticsDateRangeDefaultSuppressedProvider,
      child: AppScaffold(
        title: 'Analytics',
        actions: const [AnalyticsCopyLinkButton()],
        body: RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
            Text(
              'Agency metrics, claims pipeline, and screening funnel.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            AnalyticsDateRangeBar(
              dateRangeProvider: agencyAnalyticsDateRangeProvider,
              defaultSuppressedProvider:
                  agencyAnalyticsDateRangeDefaultSuppressedProvider,
            ),
            const SizedBox(height: 16),
            if (metricList.isNotEmpty) ...[
              Text(
                'Overview',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: metricList.map((m) {
                  final isRevenue = m.metricKey == 'revenue_paid';
                  final display = isRevenue
                      ? currency.format(m.metricValue)
                      : m.metricValue.toStringAsFixed(
                          m.metricValue == m.metricValue.roundToDouble()
                              ? 0
                              : 2,
                        );
                  final periodDelta = analyticsOverviewComparisonKeys
                          .contains(m.metricKey)
                      ? formatAnalyticsPeriodDelta(
                          m.metricValue,
                          m.priorPeriodValue,
                          isCurrency: isRevenue,
                        )
                      : null;
                  return AdminStatCard(
                    label: metricLabel(m.metricKey),
                    value: display,
                    periodDelta: periodDelta,
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],
            Text(
              'Claims pipeline',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                AdminStatCard(
                  label: 'Draft',
                  value: pipeline.summary.draftCount,
                  periodDelta: formatCountPeriodDelta(
                    pipeline.summary.draftCount,
                    pipeline.summary.priorDraftCount,
                  ),
                  onTap: () {
                    final range = ref.read(agencyAnalyticsDateRangeProvider);
                    context.push(analyticsPathWithDateRange(
                      '${AppRoutes.agencyHome}/analytics/claims/filter/draft',
                      range,
                    ));
                  },
                ),
                AdminStatCard(
                  label: 'Submitted',
                  value: pipeline.summary.submittedCount,
                  periodDelta: formatCountPeriodDelta(
                    pipeline.summary.submittedCount,
                    pipeline.summary.priorSubmittedCount,
                  ),
                  onTap: () {
                    final range = ref.read(agencyAnalyticsDateRangeProvider);
                    context.push(analyticsPathWithDateRange(
                      '${AppRoutes.agencyHome}/analytics/claims/filter/submitted',
                      range,
                    ));
                  },
                ),
                AdminStatCard(
                  label: 'Pending',
                  value: pipeline.summary.pendingCount,
                  periodDelta: formatCountPeriodDelta(
                    pipeline.summary.pendingCount,
                    pipeline.summary.priorPendingCount,
                  ),
                  onTap: () {
                    final range = ref.read(agencyAnalyticsDateRangeProvider);
                    context.push(analyticsPathWithDateRange(
                      '${AppRoutes.agencyHome}/analytics/claims/filter/pending',
                      range,
                    ));
                  },
                ),
                AdminStatCard(
                  label: 'Paid',
                  value: pipeline.summary.paidCount,
                  periodDelta: formatCountPeriodDelta(
                    pipeline.summary.paidCount,
                    pipeline.summary.priorPaidCount,
                  ),
                  highlight: true,
                  onTap: () {
                    final range = ref.read(agencyAnalyticsDateRangeProvider);
                    context.push(analyticsPathWithDateRange(
                      '${AppRoutes.agencyHome}/analytics/claims/filter/paid',
                      range,
                    ));
                  },
                ),
                AdminStatCard(
                  label: 'Denied',
                  value: pipeline.summary.deniedCount,
                  periodDelta: formatCountPeriodDelta(
                    pipeline.summary.deniedCount,
                    pipeline.summary.priorDeniedCount,
                  ),
                  onTap: () {
                    final range = ref.read(agencyAnalyticsDateRangeProvider);
                    context.push(analyticsPathWithDateRange(
                      '${AppRoutes.agencyHome}/analytics/claims/filter/denied',
                      range,
                    ));
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            _RecentClaimsList(
              claims: pipeline.recentClaims,
              currency: currency,
              dateFormat: dateFormat,
              onClaimTap: (id) {
                final range = ref.read(agencyAnalyticsDateRangeProvider);
                context.push(analyticsPathWithDateRange(
                  '${AppRoutes.agencyHome}/analytics/claims/$id',
                  range,
                ));
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Screening funnel',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                AdminStatCard(
                  label: 'Completed',
                  value: funnel.summary.completedCount,
                  periodDelta: formatCountPeriodDelta(
                    funnel.summary.completedCount,
                    funnel.summary.priorCompletedCount,
                  ),
                  onTap: () {
                    final range = ref.read(agencyAnalyticsDateRangeProvider);
                    context.push(analyticsPathWithDateRange(
                      '${AppRoutes.agencyHome}/analytics/screenings/filter/all',
                      range,
                    ));
                  },
                ),
                AdminStatCard(
                  label: 'Low risk',
                  value: funnel.summary.lowRiskCount,
                  periodDelta: formatCountPeriodDelta(
                    funnel.summary.lowRiskCount,
                    funnel.summary.priorLowRiskCount,
                  ),
                  onTap: () {
                    final range = ref.read(agencyAnalyticsDateRangeProvider);
                    context.push(analyticsPathWithDateRange(
                      '${AppRoutes.agencyHome}/analytics/screenings/filter/low',
                      range,
                    ));
                  },
                ),
                AdminStatCard(
                  label: 'Medium risk',
                  value: funnel.summary.moderateRiskCount,
                  periodDelta: formatCountPeriodDelta(
                    funnel.summary.moderateRiskCount,
                    funnel.summary.priorModerateRiskCount,
                  ),
                  onTap: () {
                    final range = ref.read(agencyAnalyticsDateRangeProvider);
                    context.push(analyticsPathWithDateRange(
                      '${AppRoutes.agencyHome}/analytics/screenings/filter/moderate',
                      range,
                    ));
                  },
                ),
                AdminStatCard(
                  label: 'High risk',
                  value: funnel.summary.highRiskCount,
                  periodDelta: formatCountPeriodDelta(
                    funnel.summary.highRiskCount,
                    funnel.summary.priorHighRiskCount,
                  ),
                  highlight: funnel.summary.highRiskCount > 0,
                  onTap: () {
                    final range = ref.read(agencyAnalyticsDateRangeProvider);
                    context.push(analyticsPathWithDateRange(
                      '${AppRoutes.agencyHome}/analytics/screenings/filter/high',
                      range,
                    ));
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            _RecentScreeningsList(
              screenings: funnel.recentScreenings,
              dateFormat: dateFormat,
              onScreeningTap: (id) {
                final range = ref.read(agencyAnalyticsDateRangeProvider);
                context.push(analyticsPathWithDateRange(
                  '${AppRoutes.agencyHome}/analytics/screenings/$id',
                  range,
                ));
              },
            ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentClaimsList extends StatelessWidget {
  const _RecentClaimsList({
    required this.claims,
    required this.currency,
    required this.dateFormat,
    required this.onClaimTap,
  });

  final List<AgencyClaimSummaryModel> claims;
  final NumberFormat currency;
  final DateFormat dateFormat;
  final void Function(String id) onClaimTap;

  @override
  Widget build(BuildContext context) {
    if (claims.isEmpty) {
      return const Card(
        child: ListTile(title: Text('No recent claims')),
      );
    }
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Recent claims',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          ...claims.map(
            (c) => ListTile(
              dense: true,
              title: Text(c.childName ?? c.payerName),
              subtitle: Text(
                '${c.status} · ${dateFormat.format(c.serviceDate)}',
              ),
              trailing: Text(currency.format(c.billedAmount)),
              onTap: () => onClaimTap(c.id),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentScreeningsList extends StatelessWidget {
  const _RecentScreeningsList({
    required this.screenings,
    required this.dateFormat,
    required this.onScreeningTap,
  });

  final List<AgencyScreeningSummaryModel> screenings;
  final DateFormat dateFormat;
  final void Function(String id) onScreeningTap;

  @override
  Widget build(BuildContext context) {
    if (screenings.isEmpty) {
      return const Card(
        child: ListTile(title: Text('No screening history yet')),
      );
    }
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Recent screenings',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          ...screenings.map(
            (s) => ListTile(
              dense: true,
              title: Text(s.childName ?? 'Unknown child'),
              subtitle: Text(
                [
                  s.templateName,
                  s.riskLevel,
                  dateFormat.format(s.completedAt),
                ].whereType<String>().join(' · '),
              ),
              trailing: s.score != null ? Text('${s.score}') : null,
              onTap: () => onScreeningTap(s.id),
            ),
          ),
        ],
      ),
    );
  }
}
