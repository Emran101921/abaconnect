import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers/app_providers.dart';
import '../../features/admin/data/admin_repository.dart';
import '../../features/admin/presentation/admin_providers.dart';
import '../../features/agency/data/agency_repository.dart';
import '../../features/agency/presentation/agency_providers.dart';
import '../models/analytics_date_range.dart';
import '../presentation/analytics_copy_link.dart';
import '../presentation/analytics_date_range_filter.dart';
import '../presentation/analytics_date_range_url.dart';
import '../widgets/app_scaffold.dart';

class AdminAnalyticsClaimDetailScreen extends ConsumerWidget {
  const AdminAnalyticsClaimDetailScreen({super.key, required this.claimId});

  final String claimId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claim = ref.watch(adminAnalyticsClaimDetailProvider(claimId));
    return AnalyticsDateRangeSync(
      dateRangeProvider: adminAnalyticsDateRangeProvider,
      defaultPreset: analyticsDefaultDateRangePreset,
      defaultSuppressedProvider:
          adminAnalyticsDateRangeDefaultSuppressedProvider,
      child: AppScaffold(
        title: 'Claim detail',
        actions: const [AnalyticsCopyLinkButton()],
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: AnalyticsDateRangeBar(
                dateRangeProvider: adminAnalyticsDateRangeProvider,
                defaultSuppressedProvider:
                    adminAnalyticsDateRangeDefaultSuppressedProvider,
              ),
            ),
            Expanded(
              child: claim.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (c) => AnalyticsClaimDetailBody(
                  status: c.status,
                  payerName: c.payerName,
                  billedAmount: c.billedAmount,
                  approvedAmount: c.approvedAmount,
                  serviceDate: c.serviceDate,
                  childName: c.childName,
                  parentEmail: c.parentEmail,
                  denialReason: c.denialReason,
                  claimNumber: c.claimNumber,
                  sessionId: c.sessionId,
                  ediReady: c.ediReady,
                  clearinghouseStatus: c.clearinghouseStatus,
                  actions: _adminClaimActions(context, ref, c, claimId),
                  onRefresh: () async {
                    ref.invalidate(adminAnalyticsClaimDetailProvider(claimId));
                    ref.invalidate(adminClaimsPipelineProvider);
                    await ref
                        .read(adminAnalyticsClaimDetailProvider(claimId).future);
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

class AgencyAnalyticsClaimDetailScreen extends ConsumerWidget {
  const AgencyAnalyticsClaimDetailScreen({super.key, required this.claimId});

  final String claimId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claim = ref.watch(agencyAnalyticsClaimDetailProvider(claimId));
    return AnalyticsDateRangeSync(
      dateRangeProvider: agencyAnalyticsDateRangeProvider,
      defaultPreset: analyticsDefaultDateRangePreset,
      defaultSuppressedProvider:
          agencyAnalyticsDateRangeDefaultSuppressedProvider,
      child: AppScaffold(
        title: 'Claim detail',
        actions: const [AnalyticsCopyLinkButton()],
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: AnalyticsDateRangeBar(
                dateRangeProvider: agencyAnalyticsDateRangeProvider,
                defaultSuppressedProvider:
                    agencyAnalyticsDateRangeDefaultSuppressedProvider,
              ),
            ),
            Expanded(
              child: claim.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (c) => AnalyticsClaimDetailBody(
                  status: c.status,
                  payerName: c.payerName,
                  billedAmount: c.billedAmount,
                  approvedAmount: c.approvedAmount,
                  serviceDate: c.serviceDate,
                  childName: c.childName,
                  parentEmail: c.parentEmail,
                  denialReason: c.denialReason,
                  claimNumber: c.claimNumber,
                  sessionId: c.sessionId,
                  ediReady: c.ediReady,
                  clearinghouseStatus: c.clearinghouseStatus,
                  actions: _agencyClaimActions(context, ref, c, claimId),
                  onRefresh: () async {
                    ref.invalidate(agencyAnalyticsClaimDetailProvider(claimId));
                    ref.invalidate(agencyClaimsPipelineProvider);
                    await ref
                        .read(agencyAnalyticsClaimDetailProvider(claimId).future);
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

class AdminAnalyticsScreeningDetailScreen extends ConsumerWidget {
  const AdminAnalyticsScreeningDetailScreen({
    super.key,
    required this.screeningId,
  });

  final String screeningId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screening =
        ref.watch(adminAnalyticsScreeningDetailProvider(screeningId));
    return AnalyticsDateRangeSync(
      dateRangeProvider: adminAnalyticsDateRangeProvider,
      defaultPreset: analyticsDefaultDateRangePreset,
      defaultSuppressedProvider:
          adminAnalyticsDateRangeDefaultSuppressedProvider,
      child: AppScaffold(
        title: 'Screening detail',
        actions: const [AnalyticsCopyLinkButton()],
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: AnalyticsDateRangeBar(
                dateRangeProvider: adminAnalyticsDateRangeProvider,
                defaultSuppressedProvider:
                    adminAnalyticsDateRangeDefaultSuppressedProvider,
              ),
            ),
            Expanded(
              child: screening.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (s) => AnalyticsScreeningDetailBody(
                  completedAt: s.completedAt,
                  childName: s.childName,
                  templateName: s.templateName,
                  score: s.score,
                  riskLevel: s.riskLevel,
                  responsesJson: s.responsesJson,
                  onRefresh: () async {
                    ref.invalidate(
                        adminAnalyticsScreeningDetailProvider(screeningId));
                    await ref.read(
                        adminAnalyticsScreeningDetailProvider(screeningId).future);
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

class AgencyAnalyticsScreeningDetailScreen extends ConsumerWidget {
  const AgencyAnalyticsScreeningDetailScreen({
    super.key,
    required this.screeningId,
  });

  final String screeningId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screening =
        ref.watch(agencyAnalyticsScreeningDetailProvider(screeningId));
    return AnalyticsDateRangeSync(
      dateRangeProvider: agencyAnalyticsDateRangeProvider,
      defaultPreset: analyticsDefaultDateRangePreset,
      defaultSuppressedProvider:
          agencyAnalyticsDateRangeDefaultSuppressedProvider,
      child: AppScaffold(
        title: 'Screening detail',
        actions: const [AnalyticsCopyLinkButton()],
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: AnalyticsDateRangeBar(
                dateRangeProvider: agencyAnalyticsDateRangeProvider,
                defaultSuppressedProvider:
                    agencyAnalyticsDateRangeDefaultSuppressedProvider,
              ),
            ),
            Expanded(
              child: screening.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (s) => AnalyticsScreeningDetailBody(
                  completedAt: s.completedAt,
                  childName: s.childName,
                  templateName: s.templateName,
                  score: s.score,
                  riskLevel: s.riskLevel,
                  responsesJson: s.responsesJson,
                  onRefresh: () async {
                    ref.invalidate(
                        agencyAnalyticsScreeningDetailProvider(screeningId));
                    await ref.read(
                        agencyAnalyticsScreeningDetailProvider(screeningId).future);
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

Widget? _adminClaimActions(
  BuildContext context,
  WidgetRef ref,
  AdminInsuranceClaimModel claim,
  String claimId,
) {
  final actionable = [
    'DRAFT',
    'SUBMITTED',
    'PENDING',
    'UNDER_REVIEW',
    'DENIED',
    'APPROVED',
  ].contains(claim.status);
  if (!actionable) return null;

  Future<void> refresh() async {
    ref.invalidate(adminAnalyticsClaimDetailProvider(claimId));
    ref.invalidate(adminClaimsPipelineProvider);
  }

  return Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      if (claim.status == 'DENIED')
        FilledButton(
          onPressed: () async {
            await ref.read(adminRepositoryProvider).updateInsuranceClaim(
                  claimId: claimId,
                  status: 'APPEALED',
                  denialReason: 'Appeal filed — resubmitting for review',
                );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Claim marked as appealed')),
              );
            }
            await refresh();
          },
          child: const Text('File appeal'),
        ),
      if (['SUBMITTED', 'PENDING', 'UNDER_REVIEW', 'APPROVED']
          .contains(claim.status))
        FilledButton.tonal(
          onPressed: () async {
            await ref
                .read(adminRepositoryProvider)
                .processClaimRemittance835(claimId);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('835 remittance processed')),
              );
            }
            await refresh();
          },
          child: const Text('Post 835 remittance'),
        ),
      if (claim.status != 'PAID')
        FilledButton(
          onPressed: () async {
            await ref.read(adminRepositoryProvider).updateInsuranceClaim(
                  claimId: claimId,
                  status: 'PAID',
                  approvedAmount: claim.billedAmount,
                );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Claim marked paid')),
              );
            }
            await refresh();
          },
          child: const Text('Mark paid'),
        ),
      if (claim.status != 'DENIED')
        OutlinedButton(
          onPressed: () async {
            await ref.read(adminRepositoryProvider).updateInsuranceClaim(
                  claimId: claimId,
                  status: 'DENIED',
                  denialReason: 'Not covered under plan',
                );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Claim denied')),
              );
            }
            await refresh();
          },
          child: const Text('Deny'),
        ),
    ],
  );
}

Widget? _agencyClaimActions(
  BuildContext context,
  WidgetRef ref,
  AgencyClaimDetailModel claim,
  String claimId,
) {
  if (!['DENIED', 'SUBMITTED', 'PENDING', 'UNDER_REVIEW'].contains(claim.status)) {
    return null;
  }

  Future<void> refresh() async {
    ref.invalidate(agencyAnalyticsClaimDetailProvider(claimId));
    ref.invalidate(agencyClaimsPipelineProvider);
  }

  return Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      if (claim.status == 'DENIED')
        FilledButton(
          onPressed: () async {
            await ref.read(agencyRepositoryProvider).updateInsuranceClaim(
                  claimId: claimId,
                  status: 'APPEALED',
                  denialReason: 'Agency appeal — requesting reconsideration',
                );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Appeal filed')),
              );
            }
            await refresh();
          },
          child: const Text('Appeal denial'),
        ),
      if (claim.status != 'DENIED')
        FilledButton.tonal(
          onPressed: () async {
            await ref
                .read(agencyRepositoryProvider)
                .processClaimRemittance835(claimId);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('835 remittance posted')),
              );
            }
            await refresh();
          },
          child: const Text('Post 835 remittance'),
        ),
    ],
  );
}

class AnalyticsClaimDetailBody extends StatelessWidget {
  const AnalyticsClaimDetailBody({
    super.key,
    required this.status,
    required this.payerName,
    required this.billedAmount,
    required this.serviceDate,
    this.approvedAmount,
    this.childName,
    this.parentEmail,
    this.denialReason,
    this.claimNumber,
    this.sessionId,
    this.ediReady,
    this.clearinghouseStatus,
    this.actions,
    required this.onRefresh,
  });

  final String status;
  final String payerName;
  final double billedAmount;
  final DateTime serviceDate;
  final double? approvedAmount;
  final String? childName;
  final String? parentEmail;
  final String? denialReason;
  final String? claimNumber;
  final String? sessionId;
  final bool? ediReady;
  final String? clearinghouseStatus;
  final Widget? actions;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$');
    final dateFormat = DateFormat.yMMMd();

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$payerName · $status',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(label: 'Child', value: childName),
                  _DetailRow(label: 'Parent', value: parentEmail),
                  _DetailRow(
                    label: 'Service date',
                    value: dateFormat.format(serviceDate),
                  ),
                  _DetailRow(
                    label: 'Billed',
                    value: currency.format(billedAmount),
                  ),
                  if (approvedAmount != null)
                    _DetailRow(
                      label: 'Approved',
                      value: currency.format(approvedAmount),
                    ),
                  _DetailRow(label: 'Claim #', value: claimNumber),
                  _DetailRow(label: 'Session', value: sessionId),
                  if (ediReady == true)
                    const _DetailRow(label: 'EDI', value: '837 ready'),
                  _DetailRow(
                    label: 'Clearinghouse',
                    value: clearinghouseStatus,
                  ),
                  if (denialReason != null)
                    _DetailRow(label: 'Denial reason', value: denialReason),
                  if (actions != null) ...[
                    const SizedBox(height: 16),
                    actions!,
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AnalyticsScreeningDetailBody extends StatelessWidget {
  const AnalyticsScreeningDetailBody({
    super.key,
    required this.completedAt,
    this.childName,
    this.templateName,
    this.score,
    this.riskLevel,
    this.responsesJson,
    required this.onRefresh,
  });

  final DateTime completedAt;
  final String? childName;
  final String? templateName;
  final double? score;
  final String? riskLevel;
  final String? responsesJson;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMMMd().add_jm();
    final responses = _parseResponses(responsesJson);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    templateName ?? 'Screening',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  _DetailRow(label: 'Child', value: childName),
                  _DetailRow(
                    label: 'Completed',
                    value: dateFormat.format(completedAt),
                  ),
                  _DetailRow(
                    label: 'Score',
                    value: score?.toStringAsFixed(2),
                  ),
                  _DetailRow(label: 'Risk level', value: riskLevel),
                ],
              ),
            ),
          ),
          if (responses.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Responses',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: responses.entries.map((entry) {
                  return ListTile(
                    dense: true,
                    title: Text(entry.key),
                    trailing: Text(_formatResponseValue(entry.value)),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Map<String, dynamic> _parseResponses(String? json) {
    if (json == null || json.isEmpty) return {};
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return {};
  }

  String _formatResponseValue(dynamic value) {
    if (value is bool) return value ? 'Yes' : 'No';
    if (value is num) return value.toString();
    return value?.toString() ?? '—';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(child: Text(value!)),
        ],
      ),
    );
  }
}
