import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/layout/dashboard_card.dart';
import '../../../shared/widgets/app_data_table.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/app_status_badge.dart';
import '../../../shared/widgets/app_stat_card.dart';
import '../../../shared/widgets/app_trust_notice.dart';
import '../../agency/presentation/agency_profile_screen.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../data/ei_billing_repository.dart';
import 'ei_billing_forms.dart';

AppStatusKind eiStatusKind(String status) {
  return switch (status.toUpperCase()) {
    'PAID' => AppStatusKind.paid,
    'SUBMITTED' || 'RESUBMITTED' => AppStatusKind.billingSubmitted,
    'DENIED' || 'REJECTED' => AppStatusKind.denied,
    'READY_AUTHORIZED_SUBMISSION' => AppStatusKind.approved,
    'MISSING_INFORMATION' || 'CORRECTION_NEEDED' => AppStatusKind.inProgress,
    'DRAFT_INCOMPLETE' => AppStatusKind.draft,
    _ => AppStatusKind.pending,
  };
}

class EiBillingShellScreen extends ConsumerStatefulWidget {
  const EiBillingShellScreen({
    super.key,
    this.showClearinghouseTab = false,
    this.canManageBilling = true,
    this.canSubmitClaims = false,
    this.isAdminContext = false,
  });

  final bool showClearinghouseTab;
  final bool canManageBilling;
  final bool canSubmitClaims;
  final bool isAdminContext;

  @override
  ConsumerState<EiBillingShellScreen> createState() =>
      _EiBillingShellScreenState();
}

class _EiBillingShellScreenState extends ConsumerState<EiBillingShellScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    final tabCount = widget.showClearinghouseTab ? 13 : 12;
    _tabController = TabController(length: tabCount, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Tab>[
      const Tab(text: 'Dashboard'),
      const Tab(text: 'Claim queue'),
      const Tab(text: 'Session review'),
      const Tab(text: 'Missing info'),
      const Tab(text: 'Submitted'),
      const Tab(text: 'Denials'),
      const Tab(text: 'Payments/ERA'),
      const Tab(text: 'Providers'),
      const Tab(text: 'Case profiles'),
      const Tab(text: 'Agency profile'),
      if (widget.showClearinghouseTab) const Tab(text: 'Clearinghouse'),
      const Tab(text: 'Reports'),
      const Tab(text: 'Audit logs'),
    ];

    final views = <Widget>[
      const _EiDashboardTab(),
      _EiQueueTab(isAdminContext: widget.isAdminContext),
      _EiSessionReviewTab(isAdminContext: widget.isAdminContext),
      _EiMissingInfoTab(
        status: 'MISSING_INFORMATION',
        isAdminContext: widget.isAdminContext,
      ),
      _EiSubmittedTab(isAdminContext: widget.isAdminContext),
      _EiDenialsTab(isAdminContext: widget.isAdminContext),
      _EiPaymentsTab(isAdminContext: widget.isAdminContext),
      _EiProviderEnrollmentTab(canManageBilling: widget.canManageBilling),
      _EiCaseProfilesTab(canManageBilling: widget.canManageBilling),
      _EiAgencyProfileTab(canManageBilling: widget.canManageBilling),
      if (widget.showClearinghouseTab) const _EiClearinghouseTab(),
      const _EiReportsTab(),
      const _EiAuditLogsTab(),
    ];

    return AppScaffold(
      title: 'NY Early Intervention billing',
      subtitle: 'Medicaid EI claims — separate from commercial insurance',
      showPageBreadcrumbs: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: AppTrustNotice(
              dense: true,
              message:
                  'EI billing requires signed BAA, completed enrollment, and explicit authorized submission. No auto-submit.',
            ),
          ),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: tabs,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: views,
            ),
          ),
        ],
      ),
    );
  }
}

class _EiDashboardTab extends ConsumerWidget {
  const _EiDashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(eiBillingDashboardProvider);
    return dashboard.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _EmptyState(
        title: 'Unable to load dashboard',
        message: '$e',
        icon: Icons.error_outline,
      ),
      data: (data) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(eiBillingDashboardProvider);
          await ref.read(eiBillingDashboardProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                AppStatCard(
                  label: 'Total records',
                  value: '${data.totalRecords}',
                  icon: Icons.receipt_long_outlined,
                ),
                AppStatCard(
                  label: 'Ready for review',
                  value: '${data.readyAgencyReview}',
                  icon: Icons.fact_check_outlined,
                ),
                AppStatCard(
                  label: 'Missing information',
                  value: '${data.missingInformation}',
                  icon: Icons.warning_amber_outlined,
                ),
                AppStatCard(
                  label: 'Submitted',
                  value: '${data.submitted}',
                  icon: Icons.upload_outlined,
                ),
                AppStatCard(
                  label: 'Paid',
                  value: '${data.paid}',
                  icon: Icons.payments_outlined,
                ),
                AppStatCard(
                  label: 'Denials & corrections',
                  value: '${data.denialsAndCorrections}',
                  icon: Icons.gavel_outlined,
                ),
              ],
            ),
            const SizedBox(height: 24),
            DashboardCard(
              title: 'Workflow guidance',
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  data.totalRecords == 0
                      ? 'No EI billing records yet. Complete agency enrollment, provider credentials, and case authorization profiles before creating claims from completed sessions.'
                      : 'Review missing-information claims, advance validated records through agency and billing approval, then export or submit with explicit authorization.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EiQueueTab extends ConsumerWidget {
  const _EiQueueTab({required this.isAdminContext});

  final bool isAdminContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _EiRecordsTable(
      provider: eiBillingQueueProvider(null),
      isAdminContext: isAdminContext,
      emptyTitle: 'Claim queue is empty',
      emptyMessage:
          'Completed EI sessions with signed documentation will appear here once billing records are created.',
    );
  }
}

class _EiSessionReviewTab extends ConsumerWidget {
  const _EiSessionReviewTab({required this.isAdminContext});

  final bool isAdminContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _EiRecordsTable(
      provider: eiBillingQueueProvider('READY_AGENCY_REVIEW'),
      isAdminContext: isAdminContext,
      emptyTitle: 'No sessions awaiting review',
      emptyMessage:
          'Sessions ready for agency clinical review will appear after validation passes.',
    );
  }
}

class _EiMissingInfoTab extends ConsumerWidget {
  const _EiMissingInfoTab({
    required this.status,
    required this.isAdminContext,
  });

  final String status;
  final bool isAdminContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _EiRecordsTable(
      provider: eiBillingQueueProvider(status),
      isAdminContext: isAdminContext,
      emptyTitle: 'No missing-information claims',
      emptyMessage:
          'Validation issues such as unsigned notes, expired credentials, or missing IFSP authorization will surface here.',
    );
  }
}

class _EiSubmittedTab extends ConsumerWidget {
  const _EiSubmittedTab({required this.isAdminContext});

  final bool isAdminContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _EiRecordsTable(
      provider: eiBillingQueueProvider('SUBMITTED'),
      isAdminContext: isAdminContext,
      emptyTitle: 'No submitted claims',
      emptyMessage:
          'Authorized submissions transmitted to the configured clearinghouse workflow will appear here.',
    );
  }
}

class _EiDenialsTab extends ConsumerWidget {
  const _EiDenialsTab({required this.isAdminContext});

  final bool isAdminContext;

  void _openRecord(BuildContext context, String recordId) {
    final path = isAdminContext
        ? AppRoutes.adminEiBillingRecord(recordId)
        : AppRoutes.agencyEiBillingRecord(recordId);
    context.push(path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final denials = ref.watch(eiBillingDenialsProvider);
    return denials.when(
      loading: () => ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          AppSkeleton(height: 44),
          SizedBox(height: 12),
          AppSkeletonCard(lines: 4),
        ],
      ),
      error: (e, _) => _EmptyState(
        title: 'Unable to load denials',
        message: '$e',
        icon: Icons.gavel_outlined,
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return const _EmptyState(
            title: 'No denials or corrections',
            message:
                'Payer denials, rejections, and correction tasks will be tracked here for billing staff follow-up.',
            icon: Icons.gavel_outlined,
          );
        }
        return AppDataTable<EiDenialListItemModel>(
          rows: rows,
          searchHint: 'Search denials…',
          onRowTap: (row) => _openRecord(context, row.recordId),
          searchPredicate: (row, q) {
            final needle = q.toLowerCase();
            return row.code.toLowerCase().contains(needle) ||
                row.reason.toLowerCase().contains(needle) ||
                (row.payerName ?? '').toLowerCase().contains(needle) ||
                (row.childDisplayName ?? '').toLowerCase().contains(needle);
          },
          columns: [
            AppDataColumn(
              label: 'Code',
              mobilePriority: true,
              cellBuilder: (context, row) => Text(row.code),
            ),
            AppDataColumn(
              label: 'Reason',
              mobilePriority: true,
              cellBuilder: (context, row) => Text(row.reason),
            ),
            AppDataColumn(
              label: 'Payer',
              cellBuilder: (context, row) => Text(row.payerName ?? '—'),
            ),
            AppDataColumn(
              label: 'Child',
              cellBuilder: (context, row) =>
                  Text(row.childDisplayName ?? '—'),
            ),
            AppDataColumn(
              label: 'Record status',
              cellBuilder: (context, row) => AppStatusBadge.fromKind(
                eiStatusKind(row.recordQueueStatus),
                label: row.recordQueueStatus,
              ),
            ),
            AppDataColumn(
              label: 'Received',
              cellBuilder: (context, row) => Text(
                row.receivedAt != null
                    ? DateFormat.yMMMd().format(row.receivedAt!)
                    : '—',
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EiPaymentsTab extends ConsumerWidget {
  const _EiPaymentsTab({required this.isAdminContext});

  final bool isAdminContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _EiRecordsTable(
      provider: eiBillingQueueProvider('PAID'),
      isAdminContext: isAdminContext,
      emptyTitle: 'No payment postings yet',
      emptyMessage:
          'Manual payment postings and future ERA imports will reconcile against submitted EI claims here.',
    );
  }
}

class _EiProviderEnrollmentTab extends ConsumerWidget {
  const _EiProviderEnrollmentTab({required this.canManageBilling});

  final bool canManageBilling;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enrollments = ref.watch(eiProviderEnrollmentsProvider);
    return enrollments.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _EmptyState(
        title: 'Provider enrollment unavailable',
        message: '$e',
        icon: Icons.badge_outlined,
      ),
      data: (rows) {
        if (rows.isEmpty && !canManageBilling) {
          return const _EmptyState(
            title: 'No provider enrollments',
            message:
                'Enroll rendering therapists with NPI, license, Medicaid status, and SCR clearance before billing.',
            icon: Icons.badge_outlined,
          );
        }
        return Stack(
          children: [
            if (rows.isEmpty)
              const _EmptyState(
                title: 'No provider enrollments',
                message:
                    'Enroll rendering therapists with NPI, license, Medicaid status, and SCR clearance before billing.',
                icon: Icons.badge_outlined,
              )
            else
              ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final row = rows[index];
                  return DashboardCard(
                    title: row.therapistName,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      subtitle: Text(
                        'Credential: ${row.credentialStatus}'
                        '${row.renderingNpi != null ? ' · NPI ${row.renderingNpi}' : ''}',
                      ),
                      trailing: AppStatusBadge.fromKind(
                        row.isActive
                            ? AppStatusKind.approved
                            : AppStatusKind.pending,
                        label: row.isActive ? 'Active' : 'Inactive',
                      ),
                      onTap: canManageBilling
                          ? () async {
                              final saved = await showEiProviderEnrollmentSheet(
                                context,
                                existing: row,
                              );
                              if (saved != null) {
                                ref.invalidate(eiProviderEnrollmentsProvider);
                              }
                            }
                          : null,
                    ),
                  );
                },
              ),
            if (canManageBilling)
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton.extended(
                  onPressed: () async {
                    final saved = await showEiProviderEnrollmentSheet(context);
                    if (saved != null) {
                      ref.invalidate(eiProviderEnrollmentsProvider);
                    }
                  },
                  icon: const Icon(Icons.person_add_outlined),
                  label: const Text('Enroll provider'),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _EiCaseProfilesTab extends ConsumerWidget {
  const _EiCaseProfilesTab({required this.canManageBilling});

  final bool canManageBilling;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(agencyManagedChildrenProvider);
    return children.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _EmptyState(
        title: 'Caseload unavailable',
        message: '$e',
        icon: Icons.child_care_outlined,
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return _EmptyState(
            title: 'No managed children',
            message: canManageBilling
                ? 'Add children to the agency caseload first, then configure IFSP authorization and Medicaid billing details for each case.'
                : 'Case billing profiles are managed per child on the agency caseload.',
            icon: Icons.child_care_outlined,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final child = rows[index];
            return _EiCaseProfileRow(
              childId: child.id,
              childDisplayName: '${child.firstName} ${child.lastName}',
              canManageBilling: canManageBilling,
            );
          },
        );
      },
    );
  }
}

class _EiCaseProfileRow extends ConsumerWidget {
  const _EiCaseProfileRow({
    required this.childId,
    required this.childDisplayName,
    required this.canManageBilling,
  });

  final String childId;
  final String childDisplayName;
  final bool canManageBilling;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(eiCaseBillingProfileProvider(childId));
    return profile.when(
      loading: () => DashboardCard(
        title: childDisplayName,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: LinearProgressIndicator(),
        ),
      ),
      error: (e, _) => DashboardCard(
        title: childDisplayName,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          subtitle: Text('Could not load profile: $e'),
        ),
      ),
      data: (row) {
        final configured = row != null;
        return DashboardCard(
          title: childDisplayName,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            subtitle: Text(
              configured
                  ? 'IFSP: ${row.ifspAuthorizationNumber ?? '—'} · ${row.consentStatus}'
                  : 'Billing profile not configured',
            ),
            trailing: AppStatusBadge.fromKind(
              configured ? AppStatusKind.approved : AppStatusKind.pending,
              label: configured ? 'Configured' : 'Incomplete',
            ),
            onTap: canManageBilling
                ? () async {
                    final saved = await showEiCaseBillingSheet(
                      context,
                      childId: childId,
                      childDisplayName: childDisplayName,
                      existing: row,
                    );
                    if (saved != null) {
                      ref.invalidate(eiCaseBillingProfileProvider(childId));
                    }
                  }
                : null,
          ),
        );
      },
    );
  }
}

class _EiAgencyProfileTab extends ConsumerWidget {
  const _EiAgencyProfileTab({required this.canManageBilling});

  final bool canManageBilling;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(eiAgencyBillingProfileProvider);
    return profile.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _EmptyState(
        title: 'Agency profile unavailable',
        message: '$e',
        icon: Icons.business_outlined,
      ),
      data: (row) {
        if (row == null) {
          return Stack(
            children: [
              const _EmptyState(
                title: 'Agency billing profile not configured',
                message:
                    'Complete legal name, NPI, Medicaid provider ID, EIN, and BAA attestation before EI claim submission.',
                icon: Icons.business_outlined,
              ),
              if (canManageBilling)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton.extended(
                    onPressed: () async {
                      final saved = await showEiAgencyProfileSheet(context);
                      if (saved != null) {
                        ref.invalidate(eiAgencyBillingProfileProvider);
                      }
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit profile'),
                  ),
                ),
            ],
          );
        }
        return Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              children: [
                DashboardCard(
                  title: row.legalName,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('NPI: ${row.npi ?? '—'}'),
                        Text('Medicaid ID: ${row.medicaidProviderId ?? '—'}'),
                        Text('EIN: ${row.ein ?? '—'}'),
                        Text('ETIN: ${row.etin ?? '—'}'),
                        Text('EI-Hub ref: ${row.eiHubReferenceId ?? '—'}'),
                        Text('EFT: ${row.eftEnrollmentStatus ?? '—'}'),
                        Text('${row.city ?? '—'}, ${row.state ?? '—'}'),
                        Text(
                          'BAA signed: ${row.baaSignedAt != null ? DateFormat.yMMMd().format(row.baaSignedAt!) : 'Not signed'}',
                        ),
                        const SizedBox(height: 8),
                        AppStatusBadge.fromKind(
                          row.enrollmentComplete
                              ? AppStatusKind.approved
                              : AppStatusKind.pending,
                          label: row.enrollmentComplete
                              ? 'Enrollment complete'
                              : 'Enrollment incomplete',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (canManageBilling)
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton.extended(
                  onPressed: () async {
                    final saved = await showEiAgencyProfileSheet(
                      context,
                      existing: row,
                    );
                    if (saved != null) {
                      ref.invalidate(eiAgencyBillingProfileProvider);
                    }
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit profile'),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _EiClearinghouseTab extends ConsumerWidget {
  const _EiClearinghouseTab();

  Future<void> _testConnection(
    BuildContext context,
    WidgetRef ref,
    String configId,
  ) async {
    try {
      final result = await ref
          .read(eiBillingRepositoryProvider)
          .testClearinghouseConnection(configId);
      ref.invalidate(eiClearinghouseConfigsProvider);
      if (context.mounted) {
        AppSnackBar.showSuccess(
          context,
          result.success ? result.message : 'Test failed: ${result.message}',
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.showError(
          context,
          'Connection test failed: ${AppSnackBar.messageFromError(e)}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configs = ref.watch(eiClearinghouseConfigsProvider);
    return configs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _EmptyState(
        title: 'Clearinghouse settings unavailable',
        message: '$e',
        icon: Icons.hub_outlined,
      ),
      data: (rows) {
        return Stack(
          children: [
            if (rows.isEmpty)
              const _EmptyState(
                title: 'No clearinghouse configurations',
                message:
                    'Platform administrators configure EI-Hub, eMedNY, 837P export, or authorized API adapters. Live endpoints are never hardcoded.',
                icon: Icons.hub_outlined,
              )
            else
              ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final row = rows[index];
                  return DashboardCard(
                    title: row.name,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            subtitle: Text(
                              'Workflow: ${row.workflow}'
                              '${row.tradingPartnerId != null ? ' · TP ${row.tradingPartnerId}' : ''}',
                            ),
                            trailing: AppStatusBadge.fromKind(
                              row.isActive
                                  ? AppStatusKind.approved
                                  : AppStatusKind.draft,
                              label: row.testMode ? 'Test mode' : 'Production',
                            ),
                            onTap: () async {
                              final saved = await showEiClearinghouseConfigSheet(
                                context,
                                existing: row,
                              );
                              if (saved != null) {
                                ref.invalidate(eiClearinghouseConfigsProvider);
                              }
                            },
                          ),
                          if (row.baaSignedAt != null)
                            Text(
                              'BAA signed: ${DateFormat.yMMMd().format(row.baaSignedAt!)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          if (row.lastConnectionTestAt != null)
                            Text(
                              'Last test: ${DateFormat.yMMMd().add_jm().format(row.lastConnectionTestAt!)}'
                              '${row.lastConnectionTestResult != null ? ' — ${row.lastConnectionTestResult}' : ''}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _testConnection(context, ref, row.id),
                            icon: const Icon(Icons.network_check_outlined),
                            label: const Text('Test connection'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.extended(
                onPressed: () async {
                  final saved = await showEiClearinghouseConfigSheet(context);
                  if (saved != null) {
                    ref.invalidate(eiClearinghouseConfigsProvider);
                  }
                },
                icon: const Icon(Icons.add_outlined),
                label: const Text('Add config'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EiReportsTab extends ConsumerWidget {
  const _EiReportsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(eiBillingReportsProvider);
    return reports.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _EmptyState(
        title: 'Reports unavailable',
        message: '$e',
        icon: Icons.insights_outlined,
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return const _EmptyState(
            title: 'No billing activity to report',
            message:
                'Status summaries will populate as EI billing records move through the queue.',
            icon: Icons.insights_outlined,
          );
        }
        final currency = NumberFormat.currency(symbol: r'$');
        return AppDataTable<EiBillingReportRowModel>(
          rows: rows,
          searchHint: 'Filter by status…',
          searchPredicate: (row, q) =>
              row.status.toLowerCase().contains(q.toLowerCase()),
          columns: [
            AppDataColumn(
              label: 'Status',
              mobilePriority: true,
              cellBuilder: (context, row) => AppStatusBadge.fromKind(
                eiStatusKind(row.status),
                label: row.status,
              ),
            ),
            AppDataColumn(
              label: 'Count',
              mobilePriority: true,
              cellBuilder: (context, row) => Text('${row.count}'),
            ),
            AppDataColumn(
              label: 'Billed',
              cellBuilder: (context, row) => Text(
                row.billedTotal != null
                    ? currency.format(row.billedTotal)
                    : '—',
              ),
            ),
            AppDataColumn(
              label: 'Allowed',
              cellBuilder: (context, row) => Text(
                row.allowedTotal != null
                    ? currency.format(row.allowedTotal)
                    : '—',
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EiAuditLogsTab extends ConsumerWidget {
  const _EiAuditLogsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(eiBillingAuditLogsProvider);
    return logs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _EmptyState(
        title: 'Audit logs unavailable',
        message: '$e',
        icon: Icons.history,
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return const _EmptyState(
            title: 'No EI billing audit events',
            message:
                'Immutable audit entries for profile updates, validations, exports, and submissions will appear here.',
            icon: Icons.history,
          );
        }
        return AppDataTable<EiBillingAuditLogModel>(
          rows: rows,
          searchHint: 'Search audit events…',
          searchPredicate: (row, q) =>
              row.action.toLowerCase().contains(q.toLowerCase()) ||
              (row.actorName ?? '').toLowerCase().contains(q.toLowerCase()),
          columns: [
            AppDataColumn(
              label: 'Action',
              mobilePriority: true,
              cellBuilder: (context, row) => Text(row.action),
            ),
            AppDataColumn(
              label: 'Actor',
              cellBuilder: (context, row) => Text(row.actorName ?? 'System'),
            ),
            AppDataColumn(
              label: 'When',
              mobilePriority: true,
              cellBuilder: (context, row) =>
                  Text(DateFormat.yMMMd().add_jm().format(row.createdAt)),
            ),
          ],
        );
      },
    );
  }
}

class _EiRecordsTable extends ConsumerWidget {
  const _EiRecordsTable({
    required this.provider,
    required this.isAdminContext,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final AutoDisposeFutureProvider<List<EiBillingRecordModel>> provider;
  final bool isAdminContext;
  final String emptyTitle;
  final String emptyMessage;

  void _openRecord(BuildContext context, String recordId) {
    final path = isAdminContext
        ? AppRoutes.adminEiBillingRecord(recordId)
        : AppRoutes.agencyEiBillingRecord(recordId);
    context.push(path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(provider);
    return records.when(
      loading: () => ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          AppSkeleton(height: 44),
          SizedBox(height: 12),
          AppSkeletonCard(lines: 4),
        ],
      ),
      error: (e, _) => _EmptyState(
        title: 'Unable to load records',
        message: '$e',
        icon: Icons.receipt_long_outlined,
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return _EmptyState(
            title: emptyTitle,
            message: emptyMessage,
            icon: Icons.receipt_long_outlined,
          );
        }
        return AppDataTable<EiBillingRecordModel>(
          rows: rows,
          searchHint: 'Search claims…',
          onRowTap: (row) => _openRecord(context, row.id),
          searchPredicate: (row, q) {
            final needle = q.toLowerCase();
            return row.queueStatus.toLowerCase().contains(needle) ||
                (row.childDisplayName ?? '').toLowerCase().contains(needle) ||
                (row.therapistName ?? '').toLowerCase().contains(needle);
          },
          columns: [
            AppDataColumn(
              label: 'Child',
              mobilePriority: true,
              cellBuilder: (context, row) =>
                  Text(row.childDisplayName ?? 'Child'),
            ),
            AppDataColumn(
              label: 'Status',
              mobilePriority: true,
              cellBuilder: (context, row) => AppStatusBadge.fromKind(
                eiStatusKind(row.queueStatus),
                label: row.queueStatus,
              ),
            ),
            AppDataColumn(
              label: 'Service date',
              cellBuilder: (context, row) =>
                  Text(DateFormat.yMMMd().format(row.serviceDate)),
            ),
            AppDataColumn(
              label: 'Units',
              cellBuilder: (context, row) => Text('${row.units}'),
            ),
            AppDataColumn(
              label: 'Provider',
              cellBuilder: (context, row) =>
                  Text(row.therapistName ?? '—'),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
