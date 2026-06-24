import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/layout/dashboard_card.dart';
import '../../../shared/models/child_medical_chart_model.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/app_status_badge.dart';
import '../../../shared/widgets/app_trust_notice.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../../clinical/data/clinical_charts_repository.dart';
import '../../job_opportunities/data/job_opportunities_repository.dart';
import '../../ei_billing/data/ei_billing_repository.dart';
import '../../ei_billing/presentation/ei_billing_forms.dart';
import 'agency_profile_screen.dart';

final agencyChildChartProvider =
    FutureProvider.family<ChildMedicalChartModel?, String>((ref, childId) async {
  final charts = await ref.watch(
    clinicalChartsProvider(ClinicalChartsAudience.agency).future,
  );
  try {
    return charts.firstWhere((c) => c.childId == childId);
  } catch (_) {
    return null;
  }
});

class AgencyChildChartScreen extends ConsumerWidget {
  const AgencyChildChartScreen({super.key, required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chartAsync = ref.watch(agencyChildChartProvider(childId));

    return chartAsync.when(
      loading: () => AppScaffold(
        title: 'Child chart',
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AppScaffold(
        title: 'Child chart',
        body: Center(child: Text(AppSnackBar.messageFromError(e))),
      ),
      data: (chart) {
        if (chart == null) {
          return AppScaffold(
            title: 'Child chart',
            body: const Center(child: Text('Chart not found')),
          );
        }
        final managed = ref.watch(agencyManagedChildrenProvider);
        final managedChild = managed.maybeWhen(
          data: (children) {
            try {
              return children.firstWhere((c) => c.id == childId);
            } catch (_) {
              return null;
            }
          },
          orElse: () => null,
        );
        return _AgencyChildChartTabs(
          chart: chart,
          childId: childId,
          showBillingTab: managedChild != null,
        );
      },
    );
  }
}

class _AgencyChildChartTabs extends ConsumerStatefulWidget {
  const _AgencyChildChartTabs({
    required this.chart,
    required this.childId,
    this.showBillingTab = false,
  });

  final ChildMedicalChartModel chart;
  final String childId;
  final bool showBillingTab;

  @override
  ConsumerState<_AgencyChildChartTabs> createState() =>
      _AgencyChildChartTabsState();
}

class _AgencyChildChartTabsState extends ConsumerState<_AgencyChildChartTabs>
    with SingleTickerProviderStateMixin {
  TabController? _tabs;

  List<String> get _tabLabels => [
        'Overview',
        'Documents',
        'Service needs',
        'Notes',
        if (widget.showBillingTab) 'Billing',
      ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _tabLabels.length, vsync: this);
  }

  @override
  void didUpdateWidget(covariant _AgencyChildChartTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showBillingTab != widget.showBillingTab) {
      final index = _tabs?.index ?? 0;
      _tabs?.dispose();
      _tabs = TabController(
        length: _tabLabels.length,
        vsync: this,
        initialIndex: index.clamp(0, _tabLabels.length - 1),
      );
    }
  }

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    if (tabs == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final chart = widget.chart;
    final dateFmt = DateFormat.yMMMd();
    final managed = ref.watch(agencyManagedChildrenProvider);
    final managedChild = managed.maybeWhen(
      data: (children) {
        try {
          return children.firstWhere((c) => c.id == widget.childId);
        } catch (_) {
          return null;
        }
      },
      orElse: () => null,
    );

    return AppScaffold(
      title: chart.displayName,
      subtitle: chart.chartNumber,
      showPageBreadcrumbs: true,
      actions: managedChild == null
          ? null
          : [
              IconButton(
                tooltip: 'Edit child profile',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () async {
                  final updated = await showAgencyChildProfileSheet(
                    context,
                    existing: managedChild,
                  );
                  if (updated == null || !context.mounted) return;
                  AppSnackBar.showSuccess(
                    context,
                    '${updated.displayName} updated.',
                  );
                  ref.invalidate(clinicalChartsProvider(ClinicalChartsAudience.agency));
                  ref.invalidate(agencyManagedChildrenProvider);
                  ref.invalidate(agencyChildChartProvider(widget.childId));
                },
              ),
            ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  child: Text(
                    chart.firstName.characters.first.toUpperCase(),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chart.displayName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Text(
                        'DOB ${dateFmt.format(chart.dateOfBirth)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                AppStatusBadge.fromKind(
                  AppStatusKind.active,
                  label: 'Agency caseload',
                ),
              ],
            ),
          ),
          TabBar(
            controller: tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final label in _tabLabels) Tab(text: label)],
          ),
          Expanded(
            child: TabBarView(
              controller: tabs,
              children: [
                _OverviewTab(chart: chart, onEdit: managedChild == null
                    ? null
                    : () async {
                        final updated = await showAgencyChildProfileSheet(
                          context,
                          existing: managedChild,
                        );
                        if (updated == null || !context.mounted) return;
                        AppSnackBar.showSuccess(
                          context,
                          '${updated.displayName} updated.',
                        );
                        ref.invalidate(
                          clinicalChartsProvider(ClinicalChartsAudience.agency),
                        );
                        ref.invalidate(agencyManagedChildrenProvider);
                        ref.invalidate(agencyChildChartProvider(widget.childId));
                      }),
                _DocumentsTab(childId: chart.childId),
                _ServiceNeedsTab(chart: chart),
                _NotesTab(chart: chart),
                if (widget.showBillingTab)
                  _BillingTab(
                    childId: widget.childId,
                    childDisplayName: chart.displayName,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.chart, this.onEdit});

  final ChildMedicalChartModel chart;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat.yMMMd();
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const AppTrustNotice.dataProtected(dense: true),
        const SizedBox(height: AppSpacing.md),
        if (onEdit != null) ...[
          GlossyButton(
            title: 'Edit child profile',
            icon: Icons.edit_outlined,
            variant: GlossyButtonVariant.secondary,
            onPressed: onEdit,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        DashboardCard(
          title: 'Chart summary',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow('Chart #', chart.chartNumber),
              _InfoRow('Date of birth', dateFmt.format(chart.dateOfBirth)),
              if (chart.gender != null) _InfoRow('Sex', chart.gender!),
              if (chart.primaryLanguage != null)
                _InfoRow('Language', chart.primaryLanguage!),
              _InfoRow(
                'Parent / guardian',
                chart.guardianName ?? chart.parentName,
              ),
              if (chart.pediatricianName != null)
                _InfoRow('Pediatrician', chart.pediatricianName!),
              if (chart.insuranceType != null)
                _InfoRow('Insurance', chart.insuranceType!),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatChip(
                    label: 'Upcoming visits',
                    value: '${chart.upcomingAppointments}',
                  ),
                  _StatChip(
                    label: 'Completed sessions',
                    value: '${chart.completedSessions}',
                  ),
                  _StatChip(
                    label: 'Notes due',
                    value: '${chart.pendingDocumentation}',
                    highlight: chart.pendingDocumentation > 0,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DocumentsTab extends StatelessWidget {
  const _DocumentsTab({required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const AppTrustNotice.protectedInfo(dense: true),
        const SizedBox(height: AppSpacing.md),
        DashboardCard(
          title: 'Clinical documentation',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Session notes, consents, and evaluation reports for this child '
                'appear here as your team documents care.',
              ),
              const SizedBox(height: AppSpacing.md),
              GlossyButton(
                title: 'Open document library',
                variant: GlossyButtonVariant.secondary,
                onPressed: () => context.push(AppRoutes.documents),
              ),
              const SizedBox(height: AppSpacing.sm),
              GlossyButton(
                title: 'Agency session notes',
                variant: GlossyButtonVariant.bluePurple,
                onPressed: () =>
                    context.push('${AppRoutes.agencyHome}/session-notes'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ServiceNeedsTab extends ConsumerWidget {
  const _ServiceNeedsTab({required this.chart});

  final ChildMedicalChartModel chart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final needs = ref.watch(agencyChildServiceNeedsProvider);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const AppTrustNotice.protectedInfo(dense: true),
        const SizedBox(height: AppSpacing.md),
        GlossyButton(
          title: 'Create service need',
          variant: GlossyButtonVariant.greenTeal,
          onPressed: () => context.push(AppRoutes.agencyServiceNeeds),
        ),
        const SizedBox(height: AppSpacing.md),
        needs.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text(AppSnackBar.messageFromError(e)),
          data: (list) {
            final childNeeds = list
                .where((n) => n.childDisplayName == chart.displayName)
                .toList();
            if (childNeeds.isEmpty) {
              return const DashboardCard(
                title: 'No service needs',
                child: Text(
                  'Internal staffing needs for this child will appear here.',
                ),
              );
            }
            return Column(
              children: childNeeds
                  .map(
                    (need) => DashboardCard(
                      title: need.serviceType,
                      child: Text(need.status),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _BillingTab extends ConsumerWidget {
  const _BillingTab({
    required this.childId,
    required this.childDisplayName,
  });

  final String childId;
  final String childDisplayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(eiCaseBillingProfileProvider(childId));

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const AppTrustNotice.protectedInfo(dense: true),
        const SizedBox(height: AppSpacing.md),
        profile.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text(AppSnackBar.messageFromError(e)),
          data: (row) {
            final configured = row != null;
            return DashboardCard(
              title: 'EI case billing profile',
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      configured
                          ? 'IFSP: ${row.ifspAuthorizationNumber ?? '—'} · ${row.consentStatus}'
                          : 'Billing profile not configured for this child.',
                    ),
                    if (configured) ...[
                      if (row.municipality != null)
                        Text('Municipality: ${row.municipality}'),
                      if (row.medicaidCin != null)
                        Text('Medicaid CIN: ${row.medicaidCin}'),
                      if (row.serviceType != null)
                        Text('Service type: ${row.serviceType}'),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    AppStatusBadge.fromKind(
                      configured
                          ? AppStatusKind.approved
                          : AppStatusKind.pending,
                      label: configured ? 'Configured' : 'Incomplete',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    GlossyButton(
                      title: 'Edit billing profile',
                      icon: Icons.edit_outlined,
                      variant: GlossyButtonVariant.secondary,
                      onPressed: () async {
                        final saved = await showEiCaseBillingSheet(
                          context,
                          childId: childId,
                          childDisplayName: childDisplayName,
                          existing: row,
                        );
                        if (saved != null) {
                          ref.invalidate(eiCaseBillingProfileProvider(childId));
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        GlossyButton(
          title: 'View EI billing queue',
          variant: GlossyButtonVariant.bluePurple,
          onPressed: () => context.push(AppRoutes.agencyEiBilling),
        ),
      ],
    );
  }
}

class _NotesTab extends StatelessWidget {
  const _NotesTab({required this.chart});

  final ChildMedicalChartModel chart;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const AppTrustNotice.dataProtected(dense: true),
        const SizedBox(height: AppSpacing.md),
        DashboardCard(
          title: 'Care coordination notes',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Internal notes and session documentation for ${chart.displayName}.',
              ),
              if (chart.lastVisitAt != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Last visit ${DateFormat.yMMMd().format(chart.lastVisitAt!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              GlossyButton(
                title: 'View session notes',
                variant: GlossyButtonVariant.bluePurple,
                onPressed: () =>
                    context.push('${AppRoutes.agencyHome}/session-notes'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = highlight
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.secondaryContainer;
    final fg = highlight
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: theme.textTheme.labelMedium?.copyWith(color: fg),
      ),
    );
  }
}
