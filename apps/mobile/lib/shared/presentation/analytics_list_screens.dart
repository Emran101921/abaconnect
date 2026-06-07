import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../features/admin/data/admin_repository.dart';
import '../../features/admin/presentation/admin_providers.dart';
import '../../features/agency/data/agency_repository.dart';
import '../../features/agency/presentation/agency_providers.dart';
import '../presentation/analytics_date_range_filter.dart';
import '../presentation/analytics_date_range_url.dart';
import '../utils/analytics_csv_export.dart';
import '../widgets/app_scaffold.dart';

List<Widget>? analyticsExportActions({
  required VoidCallback? onExport,
}) {
  if (onExport == null) return null;
  return [
    IconButton(
      icon: const Icon(Icons.download),
      tooltip: 'Export CSV',
      onPressed: onExport,
    ),
  ];
}

String analyticsClaimFilterFromPath(String pathFilter) =>
    pathFilter.toUpperCase();

String? analyticsScreeningRiskFromPath(String pathFilter) {
  switch (pathFilter.toLowerCase()) {
    case 'all':
      return null;
    case 'low':
      return 'LOW';
    case 'moderate':
      return 'MODERATE';
    case 'high':
      return 'HIGH';
    default:
      return null;
  }
}

String analyticsClaimListTitle(String pathFilter) {
  switch (pathFilter.toLowerCase()) {
    case 'draft':
      return 'Draft claims';
    case 'submitted':
      return 'Submitted claims';
    case 'pending':
      return 'Pending claims';
    case 'paid':
      return 'Paid claims';
    case 'denied':
      return 'Denied claims';
    default:
      return 'Claims';
  }
}

String analyticsScreeningListTitle(String pathFilter) {
  switch (pathFilter.toLowerCase()) {
    case 'all':
      return 'Completed screenings';
    case 'low':
      return 'Low risk screenings';
    case 'moderate':
      return 'Medium risk screenings';
    case 'high':
      return 'High risk screenings';
    default:
      return 'Screenings';
  }
}

class AdminAnalyticsClaimsListScreen extends ConsumerWidget {
  const AdminAnalyticsClaimsListScreen({
    super.key,
    required this.statusFilter,
    required this.detailBasePath,
  });

  final String statusFilter;
  final String detailBasePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apiFilter = analyticsClaimFilterFromPath(statusFilter);
    final dateRange = ref.watch(adminAnalyticsDateRangeProvider);
    final claims = ref.watch(adminAnalyticsClaimsListProvider(apiFilter));
    final currency = NumberFormat.currency(symbol: '\$');
    final dateFormat = DateFormat.yMMMd();

    return AnalyticsDateRangeSync(
      dateRangeProvider: adminAnalyticsDateRangeProvider,
      child: AppScaffold(
      title: analyticsClaimListTitle(statusFilter),
      actions: analyticsExportActions(
        onExport: claims.maybeWhen(
          data: (list) => () => exportAnalyticsCsv(
            context,
            csv: claimsCsvFromAdmin(list),
            filename: analyticsExportFilename(
              'claims',
              statusFilter,
              dateRangeSuffix: dateRange.filenameSuffix,
            ),
          ),
          orElse: () => null,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: AnalyticsDateRangeBar(
              dateRangeProvider: adminAnalyticsDateRangeProvider,
            ),
          ),
          Expanded(
            child: claims.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (list) => AnalyticsClaimsListBody(
                claims: list,
                currency: currency,
                dateFormat: dateFormat,
                onClaimTap: (id) {
                  final range = ref.read(adminAnalyticsDateRangeProvider);
                  context.push(analyticsPathWithDateRange(
                    '$detailBasePath/$id',
                    range,
                  ));
                },
                onRefresh: () async {
                  ref.invalidate(adminAnalyticsClaimsListProvider(apiFilter));
                  await ref
                      .read(adminAnalyticsClaimsListProvider(apiFilter).future);
                },
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }
}

class AgencyAnalyticsClaimsListScreen extends ConsumerWidget {
  const AgencyAnalyticsClaimsListScreen({
    super.key,
    required this.statusFilter,
    required this.detailBasePath,
  });

  final String statusFilter;
  final String detailBasePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apiFilter = analyticsClaimFilterFromPath(statusFilter);
    final dateRange = ref.watch(agencyAnalyticsDateRangeProvider);
    final claims = ref.watch(agencyAnalyticsClaimsListProvider(apiFilter));
    final currency = NumberFormat.currency(symbol: '\$');
    final dateFormat = DateFormat.yMMMd();

    return AnalyticsDateRangeSync(
      dateRangeProvider: agencyAnalyticsDateRangeProvider,
      child: AppScaffold(
      title: analyticsClaimListTitle(statusFilter),
      actions: analyticsExportActions(
        onExport: claims.maybeWhen(
          data: (list) => () => exportAnalyticsCsv(
            context,
            csv: claimsCsvFromAgency(list),
            filename: analyticsExportFilename(
              'claims',
              statusFilter,
              dateRangeSuffix: dateRange.filenameSuffix,
            ),
          ),
          orElse: () => null,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: AnalyticsDateRangeBar(
              dateRangeProvider: agencyAnalyticsDateRangeProvider,
            ),
          ),
          Expanded(
            child: claims.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (list) => AgencyAnalyticsClaimsListBody(
                claims: list,
                currency: currency,
                dateFormat: dateFormat,
                onClaimTap: (id) {
                  final range = ref.read(agencyAnalyticsDateRangeProvider);
                  context.push(analyticsPathWithDateRange(
                    '$detailBasePath/$id',
                    range,
                  ));
                },
                onRefresh: () async {
                  ref.invalidate(agencyAnalyticsClaimsListProvider(apiFilter));
                  await ref
                      .read(agencyAnalyticsClaimsListProvider(apiFilter).future);
                },
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }
}

class AdminAnalyticsScreeningsListScreen extends ConsumerWidget {
  const AdminAnalyticsScreeningsListScreen({
    super.key,
    required this.riskFilter,
    required this.detailBasePath,
  });

  final String riskFilter;
  final String detailBasePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apiRisk = analyticsScreeningRiskFromPath(riskFilter);
    final riskKey = apiRisk ?? 'all';
    final dateRange = ref.watch(adminAnalyticsDateRangeProvider);
    final screenings = ref.watch(adminAnalyticsScreeningsListProvider(riskKey));
    final dateFormat = DateFormat.yMMMd();

    return AnalyticsDateRangeSync(
      dateRangeProvider: adminAnalyticsDateRangeProvider,
      child: AppScaffold(
      title: analyticsScreeningListTitle(riskFilter),
      actions: analyticsExportActions(
        onExport: screenings.maybeWhen(
          data: (list) => () => exportAnalyticsCsv(
            context,
            csv: screeningsCsvFromAdmin(list),
            filename: analyticsExportFilename(
              'screenings',
              riskFilter,
              dateRangeSuffix: dateRange.filenameSuffix,
            ),
          ),
          orElse: () => null,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: AnalyticsDateRangeBar(
              dateRangeProvider: adminAnalyticsDateRangeProvider,
            ),
          ),
          Expanded(
            child: screenings.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (list) => AnalyticsScreeningsListBody(
                screenings: list,
                dateFormat: dateFormat,
                onScreeningTap: (id) {
                  final range = ref.read(adminAnalyticsDateRangeProvider);
                  context.push(analyticsPathWithDateRange(
                    '$detailBasePath/$id',
                    range,
                  ));
                },
                onRefresh: () async {
                  ref.invalidate(adminAnalyticsScreeningsListProvider(riskKey));
                  await ref
                      .read(adminAnalyticsScreeningsListProvider(riskKey).future);
                },
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }
}

class AgencyAnalyticsScreeningsListScreen extends ConsumerWidget {
  const AgencyAnalyticsScreeningsListScreen({
    super.key,
    required this.riskFilter,
    required this.detailBasePath,
  });

  final String riskFilter;
  final String detailBasePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apiRisk = analyticsScreeningRiskFromPath(riskFilter);
    final riskKey = apiRisk ?? 'all';
    final dateRange = ref.watch(agencyAnalyticsDateRangeProvider);
    final screenings = ref.watch(agencyAnalyticsScreeningsListProvider(riskKey));
    final dateFormat = DateFormat.yMMMd();

    return AnalyticsDateRangeSync(
      dateRangeProvider: agencyAnalyticsDateRangeProvider,
      child: AppScaffold(
      title: analyticsScreeningListTitle(riskFilter),
      actions: analyticsExportActions(
        onExport: screenings.maybeWhen(
          data: (list) => () => exportAnalyticsCsv(
            context,
            csv: screeningsCsvFromAgency(list),
            filename: analyticsExportFilename(
              'screenings',
              riskFilter,
              dateRangeSuffix: dateRange.filenameSuffix,
            ),
          ),
          orElse: () => null,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: AnalyticsDateRangeBar(
              dateRangeProvider: agencyAnalyticsDateRangeProvider,
            ),
          ),
          Expanded(
            child: screenings.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (list) => AgencyAnalyticsScreeningsListBody(
                screenings: list,
                dateFormat: dateFormat,
                onScreeningTap: (id) {
                  final range = ref.read(agencyAnalyticsDateRangeProvider);
                  context.push(analyticsPathWithDateRange(
                    '$detailBasePath/$id',
                    range,
                  ));
                },
                onRefresh: () async {
                  ref.invalidate(agencyAnalyticsScreeningsListProvider(riskKey));
                  await ref
                      .read(agencyAnalyticsScreeningsListProvider(riskKey).future);
                },
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }
}

class AnalyticsClaimsListBody extends StatelessWidget {
  const AnalyticsClaimsListBody({
    super.key,
    required this.claims,
    required this.currency,
    required this.dateFormat,
    required this.onClaimTap,
    required this.onRefresh,
  });

  final List<AnalyticsClaimSummaryModel> claims;
  final NumberFormat currency;
  final DateFormat dateFormat;
  final void Function(String id) onClaimTap;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (claims.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(child: Text('No matching claims')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: claims.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final c = claims[index];
          return Card(
            child: ListTile(
              title: Text(c.childName ?? c.payerName),
              subtitle: Text(
                '${c.status} · ${dateFormat.format(c.serviceDate)}',
              ),
              trailing: Text(currency.format(c.billedAmount)),
              onTap: () => onClaimTap(c.id),
            ),
          );
        },
      ),
    );
  }
}

class AgencyAnalyticsClaimsListBody extends StatelessWidget {
  const AgencyAnalyticsClaimsListBody({
    super.key,
    required this.claims,
    required this.currency,
    required this.dateFormat,
    required this.onClaimTap,
    required this.onRefresh,
  });

  final List<AgencyClaimSummaryModel> claims;
  final NumberFormat currency;
  final DateFormat dateFormat;
  final void Function(String id) onClaimTap;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (claims.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(child: Text('No matching claims')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: claims.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final c = claims[index];
          return Card(
            child: ListTile(
              title: Text(c.childName ?? c.payerName),
              subtitle: Text(
                '${c.status} · ${dateFormat.format(c.serviceDate)}',
              ),
              trailing: Text(currency.format(c.billedAmount)),
              onTap: () => onClaimTap(c.id),
            ),
          );
        },
      ),
    );
  }
}

class AnalyticsScreeningsListBody extends StatelessWidget {
  const AnalyticsScreeningsListBody({
    super.key,
    required this.screenings,
    required this.dateFormat,
    required this.onScreeningTap,
    required this.onRefresh,
  });

  final List<AnalyticsScreeningSummaryModel> screenings;
  final DateFormat dateFormat;
  final void Function(String id) onScreeningTap;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (screenings.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(child: Text('No matching screenings')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: screenings.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final s = screenings[index];
          return Card(
            child: ListTile(
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
          );
        },
      ),
    );
  }
}

class AgencyAnalyticsScreeningsListBody extends StatelessWidget {
  const AgencyAnalyticsScreeningsListBody({
    super.key,
    required this.screenings,
    required this.dateFormat,
    required this.onScreeningTap,
    required this.onRefresh,
  });

  final List<AgencyScreeningSummaryModel> screenings;
  final DateFormat dateFormat;
  final void Function(String id) onScreeningTap;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (screenings.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(child: Text('No matching screenings')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: screenings.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final s = screenings[index];
          return Card(
            child: ListTile(
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
          );
        },
      ),
    );
  }
}
