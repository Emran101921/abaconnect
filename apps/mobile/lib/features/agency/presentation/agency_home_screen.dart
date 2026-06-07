import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/models/dashboard_action_model.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_section_header.dart';
import '../../../shared/widgets/app_stat_card.dart';
import '../../../shared/widgets/app_welcome_banner.dart';
import '../../../shared/widgets/app_healthcare_illustration.dart';
import '../../../shared/widgets/app_theme_toggle.dart';
import '../../../shared/widgets/dashboard_action_inbox.dart';
import '../../messaging/messaging_providers.dart';
import '../../notifications/notification_providers.dart';
import 'agency_providers.dart';

class AgencyHomeScreen extends ConsumerWidget {
  const AgencyHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(agencyDashboardProvider);
    final upcoming = ref.watch(agencyUpcomingAppointmentsProvider);
    final unread = ref.watch(unreadNotificationsProvider);
    final unreadCount = unread.maybeWhen(data: (c) => c, orElse: () => 0);
    final unreadMessages = ref.watch(unreadMessageThreadsProvider);
    final unreadMessageCount =
        unreadMessages.maybeWhen(data: (c) => c, orElse: () => 0);

    return AppScaffold(
      title: 'Agency',
      actions: [
        const AppThemeToggle(compact: true),
        IconButton(
          icon: unreadCount > 0
              ? Badge(
                  label: Text('$unreadCount'),
                  child: const Icon(Icons.notifications),
                )
              : const Icon(Icons.notifications),
          onPressed: () => context.push(AppRoutes.notifications),
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () async {
            await ref.read(authStateProvider.notifier).logout();
            if (context.mounted) context.go(AppRoutes.login);
          },
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(agencyDashboardProvider);
          ref.invalidate(agencyTherapistsProvider);
          ref.invalidate(agencyAnalyticsProvider);
          ref.invalidate(agencyUpcomingAppointmentsProvider);
          ref.invalidate(unreadNotificationsProvider);
        },
        child: AppContentContainer(
          padding: EdgeInsets.zero,
          child: ListView(
          children: [
            const AppWelcomeBanner(
              greeting: 'Agency operations',
              subtitle: 'Roster, scheduling, analytics, and parent communication.',
              illustrationType: AppIllustrationType.scheduling,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: AppSectionHeader(
                title: 'Overview',
                subtitle: 'Agency operations at a glance',
              ),
            ),
            const SizedBox(height: 12),
            dashboard.when(
              data: (d) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      AppStatCard(
                        label: 'Therapists',
                        value: '${d.therapistCount}',
                        icon: Icons.groups_outlined,
                        onTap: () =>
                            context.push('${AppRoutes.agencyHome}/roster'),
                      ),
                      AppStatCard(
                        label: 'Active clients',
                        value: '${d.activeClients}',
                        icon: Icons.people_outline,
                        onTap: () =>
                            context.push('${AppRoutes.agencyHome}/analytics'),
                      ),
                      AppStatCard(
                        label: 'Sessions today',
                        value: '${d.appointmentsToday}',
                        icon: Icons.event_outlined,
                        accent: d.appointmentsToday > 0,
                        onTap: () => context
                            .push('${AppRoutes.agencyHome}/appointments'),
                      ),
                      AppStatCard(
                        label: 'Pending verify',
                        value: '${d.pendingTherapists}',
                        highlight: d.pendingTherapists > 0,
                        icon: Icons.verified_user_outlined,
                        onTap: () =>
                            context.push('${AppRoutes.agencyHome}/roster'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const AppSectionHeader(title: 'Operations board'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      AppStatCard(
                        label: 'Missing EVV',
                        value: '${d.missingEvvCount}',
                        highlight: d.missingEvvCount > 0,
                        icon: Icons.location_off_outlined,
                        onTap: () =>
                            context.push('${AppRoutes.agencyHome}/appointments'),
                      ),
                      AppStatCard(
                        label: 'Draft claims',
                        value: '${d.draftClaimsCount}',
                        highlight: d.draftClaimsCount > 0,
                        icon: Icons.receipt_long_outlined,
                        onTap: () =>
                            context.push('${AppRoutes.agencyHome}/analytics'),
                      ),
                      AppStatCard(
                        label: 'Cancels today',
                        value: '${d.cancellationsToday}',
                        icon: Icons.event_busy_outlined,
                        onTap: () =>
                            context.push('${AppRoutes.agencyHome}/appointments'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DashboardActionInbox(
                    items: d.actionItems
                        .map((e) => DashboardActionModel.fromJson(e))
                        .toList(),
                  ),
                ],
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Overview error: $e'),
            ),
            const SizedBox(height: 12),
            upcoming.when(
              data: (list) {
                if (list.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Upcoming sessions',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () =>
                              context.push('${AppRoutes.agencyHome}/appointments'),
                          child: const Text('All'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...list.take(3).map(
                      (a) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text('${a.childName} · ${a.therapyType}'),
                          subtitle: Text(
                            '${a.therapistName}\n'
                            '${DateFormat.yMMMd().add_jm().format(a.scheduledStart)} · ${a.locationType}',
                          ),
                          isThreeLine: true,
                          trailing: Chip(label: Text(a.status)),
                        ),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),
            Text(
              'Operations',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Manage your roster, invites, analytics, and today’s session load.',
            ),
            const SizedBox(height: 16),
            _OpsTile(
              title: 'Therapist roster',
              subtitle: 'View roster and remove therapists',
              icon: Icons.groups,
              onTap: () => context.push('${AppRoutes.agencyHome}/roster'),
            ),
            _OpsTile(
              title: 'Invite therapists',
              subtitle: 'Add verified therapists to your agency',
              icon: Icons.person_add,
              onTap: () => context.push('${AppRoutes.agencyHome}/invites'),
            ),
            _OpsTile(
              title: 'Platform analytics',
              subtitle: 'Sessions, revenue, and activity metrics',
              icon: Icons.insights,
              onTap: () => context.push('${AppRoutes.agencyHome}/analytics'),
            ),
            _OpsTile(
              title: 'Appointments overview',
              subtitle: 'Today’s scheduled sessions across the agency',
              icon: Icons.event,
              onTap: () => context.push('${AppRoutes.agencyHome}/appointments'),
            ),
            _OpsTile(
              title: unreadMessageCount > 0
                  ? 'Messages ($unreadMessageCount unread)'
                  : 'Messages',
              subtitle: unreadMessageCount > 0
                  ? 'Threads need a reply'
                  : 'Chat with parents and therapists',
              icon: Icons.message,
              onTap: () => context.push(AppRoutes.messages),
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
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
