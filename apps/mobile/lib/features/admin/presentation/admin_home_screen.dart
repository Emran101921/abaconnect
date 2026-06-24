import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/layout/action_button.dart';
import '../../../shared/layout/app_page_header.dart';
import '../../../shared/layout/user_role_badge.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_section_header.dart';
import '../../../shared/widgets/app_trust_notice.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../../notifications/notification_providers.dart';
import 'admin_providers.dart';
import 'admin_stat_card.dart';

class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(adminDashboardProvider);
    final pending = ref.watch(pendingTherapistsProvider);
    final complaints = ref.watch(adminComplaintsProvider);
    final unread = ref.watch(unreadNotificationsProvider);
    final unreadCount = unread.maybeWhen(data: (c) => c, orElse: () => 0);

    final user = ref.watch(authStateProvider).valueOrNull?.user;

    return AppScaffold(
      title: 'Admin dashboard',
      subtitle: 'Platform operations & compliance',
      constrainBodyOnWide: false,
      bottomNavigationBar: const RoleBottomNav(current: CoreNavTab.home),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(adminDashboardProvider);
          ref.invalidate(pendingTherapistsProvider);
          ref.invalidate(adminComplaintsProvider);
          ref.invalidate(unreadNotificationsProvider);
        },
        child: AppContentContainer(
          padding: EdgeInsets.zero,
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AppPageHeader(
                  title: 'Platform administration',
                  description:
                      'Secure oversight for users, marketplace listings, compliance, and support workflows.',
                  badge: user != null
                      ? UserRoleBadge(role: user.role, compact: true)
                      : null,
                  actions: [
                    ActionButton(
                      label: 'User management',
                      icon: Icons.people_outline,
                      onPressed: () =>
                          context.push('${AppRoutes.adminHome}/users'),
                      fullWidth: false,
                      size: GlossyButtonSize.medium,
                    ),
                    ActionButton(
                      label: 'Analytics',
                      icon: Icons.insights_outlined,
                      onPressed: () =>
                          context.push('${AppRoutes.adminHome}/analytics'),
                      variant: GlossyButtonVariant.secondary,
                      fullWidth: false,
                      size: GlossyButtonSize.medium,
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: AppTrustNotice(dense: true),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: AppSectionHeader(
                  title: 'Overview',
                  subtitle: 'Platform operations dashboard',
                ),
              ),
              const SizedBox(height: 12),
              dashboard.when(
                data: (d) => Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    AdminStatCard(label: 'Users', value: d.userCount),
                    AdminStatCard(label: 'Parents', value: d.parentCount),
                    AdminStatCard(label: 'Therapists', value: d.therapistCount),
                    AdminStatCard(
                      label: 'Appointments',
                      value: d.appointmentCount,
                    ),
                    AdminStatCard(
                      label: 'Pending verify',
                      value: d.pendingTherapists,
                      highlight: d.pendingTherapists > 0,
                    ),
                    AdminStatCard(
                      label: 'Open complaints',
                      value: d.openComplaints,
                      highlight: d.openComplaints > 0,
                    ),
                  ],
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Overview error: $e'),
              ),
              const SizedBox(height: 24),
              Text('Operations', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text(
                'Choose a workflow below. Each screen has actions you can run '
                '(verify, resolve, approve, publish, etc.).',
              ),
              const SizedBox(height: 16),
              _OpsTile(
                title: unreadCount > 0
                    ? 'Notifications ($unreadCount)'
                    : 'Notifications',
                subtitle: 'Platform alerts and activity',
                icon: Icons.notifications,
                onTap: () => context.push(AppRoutes.notifications),
              ),
              _OpsTile(
                title: 'Therapist verification',
                subtitle: 'Approve licenses for new providers',
                icon: Icons.verified_user,
                badge: pending.maybeWhen(
                  data: (l) => l.length,
                  orElse: () => null,
                ),
                onTap: () =>
                    context.push('${AppRoutes.adminHome}/verifications'),
              ),
              _OpsTile(
                title: 'Complaints',
                subtitle: 'Review and resolve parent reports',
                icon: Icons.report,
                badge: complaints.maybeWhen(
                  data: (l) => l.length,
                  orElse: () => null,
                ),
                onTap: () => context.push('${AppRoutes.adminHome}/complaints'),
              ),
              _OpsTile(
                title: 'Payment disputes',
                subtitle: 'Resolve billing disputes',
                icon: Icons.gavel,
                onTap: () => context.push('${AppRoutes.adminHome}/disputes'),
              ),
              _OpsTile(
                title: 'Therapist payouts',
                subtitle: 'Mark payouts as paid',
                icon: Icons.payments,
                onTap: () => context.push('${AppRoutes.adminHome}/payouts'),
              ),
              _OpsTile(
                title: 'Insurance claims',
                subtitle: 'Approve, deny, or mark claims paid',
                icon: Icons.health_and_safety,
                onTap: () => context.push('${AppRoutes.adminHome}/insurance'),
              ),
              _OpsTile(
                title: 'Review moderation',
                subtitle: 'Publish or hide therapist reviews',
                icon: Icons.rate_review,
                onTap: () => context.push('${AppRoutes.adminHome}/reviews'),
              ),
              _OpsTile(
                title: 'Platform analytics',
                subtitle: 'Sessions, revenue, and activity metrics',
                icon: Icons.insights,
                onTap: () => context.push('${AppRoutes.adminHome}/analytics'),
              ),
              _OpsTile(
                title: 'Users',
                subtitle: 'Browse platform accounts by role',
                icon: Icons.people,
                onTap: () => context.push('${AppRoutes.adminHome}/users'),
              ),
              _OpsTile(
                title: 'Compliance dashboard',
                subtitle: 'Acknowledgments, notices, privacy requests',
                icon: Icons.verified_user,
                onTap: () => context.push('${AppRoutes.adminHome}/compliance'),
              ),
              _OpsTile(
                title: 'Audit logs',
                subtitle: 'HIPAA audit trail (read-only)',
                icon: Icons.history,
                onTap: () => context.push('${AppRoutes.adminHome}/audit'),
              ),
              _OpsTile(
                title: 'NY EI billing',
                subtitle: 'Claims, denials, and clearinghouse workflows',
                icon: Icons.receipt_long_outlined,
                onTap: () => context.push(AppRoutes.adminEiBilling),
              ),
              _OpsTile(
                title: 'Job opportunities moderation',
                subtitle: 'Pause, remove, and audit agency staffing posts',
                icon: Icons.work_outline,
                onTap: () => context.push(AppRoutes.adminMarketplaceAdmin),
              ),
              _OpsTile(
                title: 'Marketplace moderation',
                subtitle: 'Review anonymous listings and consent audit trail',
                icon: Icons.storefront_outlined,
                onTap: () => context.push('${AppRoutes.adminHome}/marketplace'),
              ),
              _OpsTile(
                title: 'Session notes',
                subtitle: 'Edit fully signed therapist session documentation',
                icon: Icons.assignment_outlined,
                onTap: () => context.push('${AppRoutes.adminHome}/session-notes'),
              ),
              const SizedBox(height: 8),
              Text(
                'Tip: pull down to refresh counts on this screen.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpsTile extends StatelessWidget {
  const _OpsTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.badge,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Badge(
          isLabelVisible: badge != null && badge! > 0,
          label: Text('$badge'),
          child: Icon(icon, size: 32),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
