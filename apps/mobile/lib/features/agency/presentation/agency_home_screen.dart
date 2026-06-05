import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/models/dashboard_action_model.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/dashboard_action_inbox.dart';
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

    return AppScaffold(
      title: 'Agency',
      actions: [
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
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Overview',
              style: Theme.of(context).textTheme.titleLarge,
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
                      _StatCard(
                        label: 'Therapists',
                        value: '${d.therapistCount}',
                        onTap: () =>
                            context.push('${AppRoutes.agencyHome}/roster'),
                      ),
                      _StatCard(
                        label: 'Active clients',
                        value: '${d.activeClients}',
                        onTap: () =>
                            context.push('${AppRoutes.agencyHome}/analytics'),
                      ),
                      _StatCard(
                        label: 'Sessions today',
                        value: '${d.appointmentsToday}',
                        onTap: () => context
                            .push('${AppRoutes.agencyHome}/appointments'),
                      ),
                      _StatCard(
                        label: 'Pending verify',
                        value: '${d.pendingTherapists}',
                        highlight: d.pendingTherapists > 0,
                        onTap: () =>
                            context.push('${AppRoutes.agencyHome}/roster'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Operations board',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _StatCard(
                        label: 'Missing EVV',
                        value: '${d.missingEvvCount}',
                        highlight: d.missingEvvCount > 0,
                        onTap: () =>
                            context.push('${AppRoutes.agencyHome}/appointments'),
                      ),
                      _StatCard(
                        label: 'Draft claims',
                        value: '${d.draftClaimsCount}',
                        highlight: d.draftClaimsCount > 0,
                        onTap: () =>
                            context.push('${AppRoutes.agencyHome}/analytics'),
                      ),
                      _StatCard(
                        label: 'Cancels today',
                        value: '${d.cancellationsToday}',
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
            const SizedBox(height: 8),
            Text(
              'Tip: pull down to refresh counts on this screen.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    this.highlight = false,
    this.onTap,
  });

  final String label;
  final String value;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 160,
      child: Card(
        color: highlight ? colorScheme.errorContainer : null,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(label),
              ],
            ),
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
