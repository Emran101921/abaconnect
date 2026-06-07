import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';

import '../../../shared/presentation/analytics_copy_link.dart';
import '../../../shared/presentation/analytics_date_range_filter.dart';
import '../../../shared/presentation/analytics_date_range_url.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../data/admin_repository.dart';
import 'admin_providers.dart';
import 'admin_stat_card.dart';

class AdminAnalyticsScreen extends ConsumerWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(adminAnalyticsProvider);
    final claims = ref.watch(adminClaimsPipelineProvider);
    final screenings = ref.watch(adminScreeningFunnelProvider);
    final currency = NumberFormat.currency(symbol: '\$');
    final dateFormat = DateFormat.yMMMd();

    Future<void> refresh() async {
      ref.invalidate(adminAnalyticsProvider);
      ref.invalidate(adminClaimsPipelineProvider);
      ref.invalidate(adminScreeningFunnelProvider);
      await Future.wait([
        ref.read(adminAnalyticsProvider.future),
        ref.read(adminClaimsPipelineProvider.future),
        ref.read(adminScreeningFunnelProvider.future),
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

    String metricLabel(String key) {
      switch (key) {
        case 'appointments_7d':
          return 'Appointments (7d)';
        case 'sessions_completed':
          return 'Sessions completed';
        case 'revenue_paid':
          return 'Revenue paid';
        case 'active_children':
          return 'Active children';
        default:
          return key;
      }
    }

    return AnalyticsDateRangeSync(
      dateRangeProvider: adminAnalyticsDateRangeProvider,
      child: AppScaffold(
        title: 'Analytics',
        actions: const [AnalyticsCopyLinkButton()],
        body: RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
            Text(
              'Platform metrics, claims pipeline, and screening funnel.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            AnalyticsDateRangeBar(
              dateRangeProvider: adminAnalyticsDateRangeProvider,
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
                  final display = m.metricKey == 'revenue_paid'
                      ? currency.format(m.metricValue)
                      : m.metricValue.toStringAsFixed(
                          m.metricValue == m.metricValue.roundToDouble()
                              ? 0
                              : 2,
                        );
                  return AdminStatCard(
                    label: metricLabel(m.metricKey),
                    value: display,
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
                  onTap: () {
                    final range = ref.read(adminAnalyticsDateRangeProvider);
                    context.push(analyticsPathWithDateRange(
                      '${AppRoutes.adminHome}/analytics/claims/filter/draft',
                      range,
                    ));
                  },
                ),
                AdminStatCard(
                  label: 'Submitted',
                  value: pipeline.summary.submittedCount,
                  onTap: () {
                    final range = ref.read(adminAnalyticsDateRangeProvider);
                    context.push(analyticsPathWithDateRange(
                      '${AppRoutes.adminHome}/analytics/claims/filter/submitted',
                      range,
                    ));
                  },
                ),
                AdminStatCard(
                  label: 'Pending',
                  value: pipeline.summary.pendingCount,
                  onTap: () {
                    final range = ref.read(adminAnalyticsDateRangeProvider);
                    context.push(analyticsPathWithDateRange(
                      '${AppRoutes.adminHome}/analytics/claims/filter/pending',
                      range,
                    ));
                  },
                ),
                AdminStatCard(
                  label: 'Paid',
                  value: pipeline.summary.paidCount,
                  highlight: true,
                  onTap: () {
                    final range = ref.read(adminAnalyticsDateRangeProvider);
                    context.push(analyticsPathWithDateRange(
                      '${AppRoutes.adminHome}/analytics/claims/filter/paid',
                      range,
                    ));
                  },
                ),
                AdminStatCard(
                  label: 'Denied',
                  value: pipeline.summary.deniedCount,
                  onTap: () {
                    final range = ref.read(adminAnalyticsDateRangeProvider);
                    context.push(analyticsPathWithDateRange(
                      '${AppRoutes.adminHome}/analytics/claims/filter/denied',
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
                final range = ref.read(adminAnalyticsDateRangeProvider);
                context.push(analyticsPathWithDateRange(
                  '${AppRoutes.adminHome}/analytics/claims/$id',
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
                  onTap: () {
                    final range = ref.read(adminAnalyticsDateRangeProvider);
                    context.push(analyticsPathWithDateRange(
                      '${AppRoutes.adminHome}/analytics/screenings/filter/all',
                      range,
                    ));
                  },
                ),
                AdminStatCard(
                  label: 'Low risk',
                  value: funnel.summary.lowRiskCount,
                  onTap: () {
                    final range = ref.read(adminAnalyticsDateRangeProvider);
                    context.push(analyticsPathWithDateRange(
                      '${AppRoutes.adminHome}/analytics/screenings/filter/low',
                      range,
                    ));
                  },
                ),
                AdminStatCard(
                  label: 'Medium risk',
                  value: funnel.summary.moderateRiskCount,
                  onTap: () {
                    final range = ref.read(adminAnalyticsDateRangeProvider);
                    context.push(analyticsPathWithDateRange(
                      '${AppRoutes.adminHome}/analytics/screenings/filter/moderate',
                      range,
                    ));
                  },
                ),
                AdminStatCard(
                  label: 'High risk',
                  value: funnel.summary.highRiskCount,
                  highlight: funnel.summary.highRiskCount > 0,
                  onTap: () {
                    final range = ref.read(adminAnalyticsDateRangeProvider);
                    context.push(analyticsPathWithDateRange(
                      '${AppRoutes.adminHome}/analytics/screenings/filter/high',
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
                final range = ref.read(adminAnalyticsDateRangeProvider);
                context.push(analyticsPathWithDateRange(
                  '${AppRoutes.adminHome}/analytics/screenings/$id',
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

  final List<AnalyticsClaimSummaryModel> claims;
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

  final List<AnalyticsScreeningSummaryModel> screenings;
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
