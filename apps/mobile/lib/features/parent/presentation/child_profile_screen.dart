import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/layout/dashboard_card.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/app_status_badge.dart';
import '../../../shared/widgets/app_trust_notice.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../data/parent_booking_repository.dart';

final parentChildProvider = FutureProvider.family<ChildModel?, String>((
  ref,
  childId,
) async {
  final children =
      await ref.watch(parentBookingRepositoryProvider).fetchChildren();
  try {
    return children.firstWhere((c) => c.id == childId);
  } catch (_) {
    return null;
  }
});

class ChildProfileScreen extends ConsumerWidget {
  const ChildProfileScreen({super.key, required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childAsync = ref.watch(parentChildProvider(childId));

    return childAsync.when(
      loading: () => AppScaffold(
        title: 'Child profile',
        bottomNavigationBar: const RoleBottomNav(current: CoreNavTab.profile),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AppScaffold(
        title: 'Child profile',
        body: Center(child: Text(AppSnackBar.messageFromError(e))),
      ),
      data: (child) {
        if (child == null) {
          return AppScaffold(
            title: 'Child profile',
            body: const Center(child: Text('Child not found')),
          );
        }
        return _ChildProfileTabs(child: child);
      },
    );
  }
}

class _ChildProfileTabs extends ConsumerStatefulWidget {
  const _ChildProfileTabs({required this.child});

  final ChildModel child;

  @override
  ConsumerState<_ChildProfileTabs> createState() => _ChildProfileTabsState();
}

class _ChildProfileTabsState extends ConsumerState<_ChildProfileTabs>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  static const _tabLabels = [
    'Overview',
    'Screening',
    'Services',
    'Schedule',
    'Messages',
    'Calls',
    'Documents',
    'Billing',
    'Audit',
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _tabLabels.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    final dateFmt = DateFormat.yMMMd();

    return AppScaffold(
      title: child.displayName,
      subtitle: 'Child care profile',
      showPageBreadcrumbs: true,
      bottomNavigationBar: const RoleBottomNav(current: CoreNavTab.profile),
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
                    child.firstName.characters.first.toUpperCase(),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        child.displayName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Text(
                        'DOB ${dateFmt.format(child.dateOfBirth)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final label in _tabLabels) Tab(text: label)],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _OverviewTab(child: child),
                _LinkTab(
                  icon: Icons.fact_check_outlined,
                  title: 'Screening & intake',
                  description:
                      'View screening history, complete EI questionnaires, and track risk level.',
                  actionLabel: 'Open screening',
                  onAction: () => context.push(
                    '${AppRoutes.parentScreening}?childId=${child.id}',
                  ),
                ),
                _LinkTab(
                  icon: Icons.medical_services_outlined,
                  title: 'Services & care team',
                  description:
                      'Treatment plans, assigned therapists, and service coordinator contacts.',
                  actionLabel: 'Treatment plans',
                  onAction: () => context.push(
                    '${AppRoutes.parentHome}/treatment-plans',
                  ),
                ),
                _LinkTab(
                  icon: Icons.calendar_month_outlined,
                  title: 'Schedule',
                  description: 'Upcoming and past appointments for this child.',
                  actionLabel: 'View appointments',
                  onAction: () => context.push(AppRoutes.parentAppointments),
                ),
                _LinkTab(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Messages',
                  description: 'Secure messaging with your care team.',
                  actionLabel: 'Open messages',
                  onAction: () => context.push(AppRoutes.messages),
                ),
                _LinkTab(
                  icon: Icons.call_outlined,
                  title: 'Secure calls',
                  description: 'HIPAA-aware audio and video calls — numbers are never shared.',
                  actionLabel: 'Call history',
                  onAction: () => context.push(AppRoutes.callHistory),
                ),
                _LinkTab(
                  icon: Icons.folder_outlined,
                  title: 'Documents',
                  description: 'Consents, session notes shared with you, and uploaded files.',
                  actionLabel: 'View documents',
                  onAction: () => context.push(AppRoutes.documents),
                ),
                _LinkTab(
                  icon: Icons.receipt_long_outlined,
                  title: 'Billing',
                  description: 'Payments, insurance claims, and billing status.',
                  actionLabel: 'Payments & billing',
                  onAction: () => context.push(AppRoutes.payments),
                ),
                _LinkTab(
                  icon: Icons.history_outlined,
                  title: 'Audit log',
                  description:
                      'Record of who accessed this child\'s information and when.',
                  actionLabel: 'Privacy center',
                  onAction: () => context.push(AppRoutes.settingsPrivacy),
                  trustNotice: const AppTrustNotice.protectedInfo(dense: true),
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
  const _OverviewTab({required this.child});

  final ChildModel child;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat.yMMMd();
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const AppTrustNotice.dataProtected(dense: true),
        const SizedBox(height: AppSpacing.md),
        DashboardCard(
          title: 'Profile summary',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow('Date of birth', dateFmt.format(child.dateOfBirth)),
              if (child.gender != null)
                _InfoRow('Sex', child.gender!),
              if (child.primaryLanguage != null)
                _InfoRow('Language', child.primaryLanguage!),
              if (child.guardianName != null)
                _InfoRow('Guardian', child.guardianName!),
              if (child.insuranceType != null)
                _InfoRow('Insurance', child.insuranceType!),
              const SizedBox(height: AppSpacing.sm),
              AppStatusBadge.fromKind(AppStatusKind.active, label: 'Active profile'),
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

class _LinkTab extends StatelessWidget {
  const _LinkTab({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
    this.trustNotice,
  });

  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onAction;
  final Widget? trustNotice;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        DashboardCard(
          title: title,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: AppSpacing.md),
              Text(description),
              if (trustNotice != null) ...[
                const SizedBox(height: AppSpacing.md),
                trustNotice!,
              ],
              const SizedBox(height: AppSpacing.lg),
              GlossyButton(
                title: actionLabel,
                icon: icon,
                variant: GlossyButtonVariant.primary,
                onPressed: onAction,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
