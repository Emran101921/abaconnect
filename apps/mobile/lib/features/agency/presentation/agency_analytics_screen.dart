import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';

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

    String metricLabel(String key) {
      switch (key) {
        case 'appointments_7d':
          return 'Appointments (7d)';
        case 'sessions_completed':
          return 'Sessions completed';
        case 'revenue_paid':
          return 'Revenue paid';
        case 'active_children':
          return 'Active clients';
        default:
          return key;
      }
    }

    return AppScaffold(
      title: 'Analytics',
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
                  final key = m['key'] as String? ?? '';
                  final value = (m['value'] as num?)?.toDouble() ?? 0;
                  final display = key == 'revenue_paid'
                      ? currency.format(value)
                      : value.toStringAsFixed(
                          value == value.roundToDouble() ? 0 : 2,
                        );
                  return AdminStatCard(
                    label: metricLabel(key),
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
                  onTap: () => context.push(
                    '${AppRoutes.agencyHome}/analytics/claims/filter/draft',
                  ),
                ),
                AdminStatCard(
                  label: 'Submitted',
                  value: pipeline.summary.submittedCount,
                  onTap: () => context.push(
                    '${AppRoutes.agencyHome}/analytics/claims/filter/submitted',
                  ),
                ),
                AdminStatCard(
                  label: 'Pending',
                  value: pipeline.summary.pendingCount,
                  onTap: () => context.push(
                    '${AppRoutes.agencyHome}/analytics/claims/filter/pending',
                  ),
                ),
                AdminStatCard(
                  label: 'Paid',
                  value: pipeline.summary.paidCount,
                  highlight: true,
                  onTap: () => context.push(
                    '${AppRoutes.agencyHome}/analytics/claims/filter/paid',
                  ),
                ),
                AdminStatCard(
                  label: 'Denied',
                  value: pipeline.summary.deniedCount,
                  onTap: () => context.push(
                    '${AppRoutes.agencyHome}/analytics/claims/filter/denied',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _RecentClaimsList(
              claims: pipeline.recentClaims,
              currency: currency,
              dateFormat: dateFormat,
              onClaimTap: (id) => context.push(
                '${AppRoutes.agencyHome}/analytics/claims/$id',
              ),
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
                  onTap: () => context.push(
                    '${AppRoutes.agencyHome}/analytics/screenings/filter/all',
                  ),
                ),
                AdminStatCard(
                  label: 'Low risk',
                  value: funnel.summary.lowRiskCount,
                  onTap: () => context.push(
                    '${AppRoutes.agencyHome}/analytics/screenings/filter/low',
                  ),
                ),
                AdminStatCard(
                  label: 'Medium risk',
                  value: funnel.summary.moderateRiskCount,
                  onTap: () => context.push(
                    '${AppRoutes.agencyHome}/analytics/screenings/filter/moderate',
                  ),
                ),
                AdminStatCard(
                  label: 'High risk',
                  value: funnel.summary.highRiskCount,
                  highlight: funnel.summary.highRiskCount > 0,
                  onTap: () => context.push(
                    '${AppRoutes.agencyHome}/analytics/screenings/filter/high',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _RecentScreeningsList(
              screenings: funnel.recentScreenings,
              dateFormat: dateFormat,
              onScreeningTap: (id) => context.push(
                '${AppRoutes.agencyHome}/analytics/screenings/$id',
              ),
            ),
          ],
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
