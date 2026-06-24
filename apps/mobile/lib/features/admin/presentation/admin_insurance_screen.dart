import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_data_table.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/app_status_badge.dart';
import '../data/admin_repository.dart';
import 'admin_providers.dart';

AppStatusKind _claimStatusKind(String status) {
  return switch (status.toUpperCase()) {
    'APPROVED' => AppStatusKind.approved,
    'DENIED' => AppStatusKind.denied,
    'PAID' => AppStatusKind.paid,
    'DRAFT' => AppStatusKind.draft,
    'IN_PROGRESS' || 'UNDER_REVIEW' => AppStatusKind.inProgress,
    'SUBMITTED' || 'PENDING' => AppStatusKind.billingSubmitted,
    _ => AppStatusKind.pending,
  };
}

class AdminInsuranceScreen extends ConsumerWidget {
  const AdminInsuranceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claims = ref.watch(adminInsuranceClaimsProvider);
    final currency = NumberFormat.currency(symbol: '\$');

    return AppScaffold(
      title: 'Insurance claims',
      subtitle: 'Approve, deny, or mark claims paid',
      showPageBreadcrumbs: true,
      body: claims.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            AppSkeleton(height: 44),
            SizedBox(height: 12),
            AppSkeletonCard(lines: 4),
          ],
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(adminInsuranceClaimsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AppDataTable<AdminInsuranceClaimModel>(
                  rows: list,
                  searchHint: 'Search claims…',
                  searchPredicate: (c, q) {
                    final needle = q.toLowerCase();
                    return c.payerName.toLowerCase().contains(needle) ||
                        c.status.toLowerCase().contains(needle) ||
                        (c.childName ?? '').toLowerCase().contains(needle) ||
                        (c.parentEmail ?? '').toLowerCase().contains(needle) ||
                        (c.claimNumber ?? '').toLowerCase().contains(needle);
                  },
                  columns: [
                    AppDataColumn(
                      label: 'Payer',
                      mobilePriority: true,
                      cellBuilder: (context, c) => Text(
                        c.payerName,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    AppDataColumn(
                      label: 'Status',
                      mobilePriority: true,
                      cellBuilder: (context, c) => AppStatusBadge.fromKind(
                        _claimStatusKind(c.status),
                        label: c.status,
                      ),
                    ),
                    AppDataColumn(
                      label: 'Child',
                      cellBuilder: (context, c) =>
                          Text(c.childName ?? '—'),
                    ),
                    AppDataColumn(
                      label: 'Amount',
                      cellBuilder: (context, c) =>
                          Text(currency.format(c.billedAmount)),
                    ),
                    AppDataColumn(
                      label: 'Claim #',
                      cellBuilder: (context, c) =>
                          Text(c.claimNumber ?? '—'),
                    ),
                  ],
                  actionsBuilder: (context, c) {
                    final actionable = [
                      'SUBMITTED',
                      'PENDING',
                      'UNDER_REVIEW',
                      'DRAFT',
                    ].contains(c.status);
                    if (!actionable &&
                        !(c.isLocked &&
                            c.status == 'DENIED' &&
                            c.resubmissionOfId == null)) {
                      return const SizedBox.shrink();
                    }
                    return PopupMenuButton<String>(
                      onSelected: (action) {
                        switch (action) {
                          case 'resubmit':
                            _resubmit(context, ref, c);
                          case 'submit837':
                            _submitClearinghouse(context, ref, c);
                          case 'approve':
                            _update(
                              context,
                              ref,
                              c,
                              'APPROVED',
                              c.billedAmount,
                            );
                          case 'deny':
                            _update(
                              context,
                              ref,
                              c,
                              'DENIED',
                              null,
                              denial: 'Not covered under plan',
                            );
                          case 'paid':
                            _update(
                              context,
                              ref,
                              c,
                              'PAID',
                              c.billedAmount,
                            );
                        }
                      },
                      itemBuilder: (ctx) => [
                        if (c.isLocked &&
                            c.status == 'DENIED' &&
                            c.resubmissionOfId == null)
                          const PopupMenuItem(
                            value: 'resubmit',
                            child: Text('Create resubmission'),
                          ),
                        if (c.status == 'DRAFT' || c.status == 'PENDING')
                          const PopupMenuItem(
                            value: 'submit837',
                            child: Text('Submit 837'),
                          ),
                        if (actionable) ...[
                          const PopupMenuItem(
                            value: 'approve',
                            child: Text('Approve'),
                          ),
                          const PopupMenuItem(
                            value: 'deny',
                            child: Text('Deny'),
                          ),
                          const PopupMenuItem(
                            value: 'paid',
                            child: Text('Mark paid'),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _resubmit(
    BuildContext context,
    WidgetRef ref,
    AdminInsuranceClaimModel c,
  ) async {
    try {
      await ref.read(adminRepositoryProvider).resubmitInsuranceClaim(c.id);
      ref.invalidate(adminInsuranceClaimsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Resubmission draft created')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Resubmit failed: $e')),
        );
      }
    }
  }

  Future<void> _submitClearinghouse(
    BuildContext context,
    WidgetRef ref,
    AdminInsuranceClaimModel c,
  ) async {
    try {
      await ref.read(adminRepositoryProvider).submitClaimToClearinghouse(c.id);
      ref.invalidate(adminInsuranceClaimsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Submitted to clearinghouse')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Submit failed: $e')));
      }
    }
  }

  Future<void> _update(
    BuildContext context,
    WidgetRef ref,
    AdminInsuranceClaimModel c,
    String status,
    double? approvedAmount, {
    String? denial,
  }) async {
    try {
      await ref
          .read(adminRepositoryProvider)
          .updateInsuranceClaim(
            claimId: c.id,
            status: status,
            approvedAmount: approvedAmount,
            denialReason: denial,
          );
      ref.invalidate(adminInsuranceClaimsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Claim $status')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }
}
