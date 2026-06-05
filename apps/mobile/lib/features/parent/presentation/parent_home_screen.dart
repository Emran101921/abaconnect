import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../messaging/messaging_providers.dart';
import '../../messaging/presentation/messages_screen.dart';
import '../../messaging/presentation/recent_messages_section.dart';
import '../../notifications/notification_providers.dart';
import '../data/parent_booking_repository.dart';

final parentDashboardProvider =
    FutureProvider<ParentDashboardModel>((ref) async {
  return ref.watch(parentBookingRepositoryProvider).fetchDashboard();
});

final parentAppointmentsProvider =
    FutureProvider<List<AppointmentModel>>((ref) async {
  return ref.watch(parentBookingRepositoryProvider).fetchAppointments();
});

final parentPendingReviewsProvider =
    FutureProvider<List<TherapistModel>>((ref) async {
  return ref.watch(parentBookingRepositoryProvider).fetchPendingReviewTherapists();
});

class ParentHomeScreen extends ConsumerWidget {
  const ParentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(parentDashboardProvider);
    final appointments = ref.watch(parentAppointmentsProvider);
    final pendingReviews = ref.watch(parentPendingReviewsProvider);
    final unread = ref.watch(unreadNotificationsProvider);
    final unreadCount = unread.maybeWhen(data: (c) => c, orElse: () => 0);
    final unreadMessages = ref.watch(unreadMessageThreadsProvider);
    final unreadMessageCount =
        unreadMessages.maybeWhen(data: (c) => c, orElse: () => 0);

    return AppScaffold(
      title: 'Parent',
      actions: [
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
          ref.invalidate(parentDashboardProvider);
          ref.invalidate(parentAppointmentsProvider);
          ref.invalidate(parentPendingReviewsProvider);
          ref.invalidate(unreadNotificationsProvider);
          ref.invalidate(unreadMessageThreadsProvider);
          ref.invalidate(messageThreadsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Overview', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            dashboard.when(
              data: (d) => Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _StatCard(
                    label: 'Children',
                    value: '${d.childrenCount}',
                    onTap: () => context.push('${AppRoutes.parentHome}/children'),
                  ),
                  _StatCard(
                    label: 'Upcoming',
                    value: '${d.upcomingAppointments}',
                    onTap: () =>
                        context.push('${AppRoutes.parentHome}/appointments'),
                  ),
                  _StatCard(
                    label: 'Today',
                    value: '${d.appointmentsToday}',
                    onTap: () =>
                        context.push('${AppRoutes.parentHome}/appointments'),
                  ),
                  _StatCard(
                    label: 'Reviews due',
                    value: '${d.pendingReviews}',
                    highlight: d.pendingReviews > 0,
                    onTap: () => context.push('${AppRoutes.parentHome}/reviews'),
                  ),
                ],
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Overview error: $e'),
            ),
            const SizedBox(height: 12),
            const RecentMessagesSection(),
            const SizedBox(height: 12),
            pendingReviews.when(
              data: (therapists) {
                if (therapists.isEmpty) return const SizedBox.shrink();
                return Card(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(Icons.rate_review),
                    title: const Text('Rate your therapist'),
                    subtitle: Text(
                      '${therapists.length} completed session(s) awaiting feedback',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('${AppRoutes.parentHome}/reviews'),
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            appointments.when(
              data: (list) {
                if (list.isEmpty) {
                  return const Card(
                    child: ListTile(
                      title: Text('No upcoming appointments'),
                      subtitle: Text('Book a session to get started'),
                    ),
                  );
                }
                return Column(
                  children: [
                    ...list.take(3).map(
                      (a) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(a.therapyType),
                          subtitle: Text(
                            '${a.childName} with ${a.therapistName}\n'
                            '${DateFormat.yMMMd().add_jm().format(a.scheduledStart)}',
                          ),
                          trailing: Chip(label: Text(a.status)),
                          onTap: () => context.push('${AppRoutes.parentHome}/appointments'),
                        ),
                      ),
                    ),
                    if (list.length > 3)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () =>
                              context.push('${AppRoutes.parentHome}/appointments'),
                          child: Text('View all ${list.length}'),
                        ),
                      ),
                  ],
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Appointments: $e'),
            ),
            const SizedBox(height: 24),
            Text('Operations', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Scheduling, care team, billing, and account settings.'),
            const SizedBox(height: 16),
            Text(
              'Scheduling',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _OpsTile(
              title: 'Book session',
              subtitle: 'Schedule therapy appointments',
              icon: Icons.calendar_month,
              onTap: () => context.push('${AppRoutes.parentHome}/booking'),
            ),
            _OpsTile(
              title: 'My appointments',
              subtitle: 'Reschedule, cancel, export calendar',
              icon: Icons.event_note,
              onTap: () => context.push('${AppRoutes.parentHome}/appointments'),
            ),
            _OpsTile(
              title: 'Telehealth',
              subtitle: 'Join virtual sessions',
              icon: Icons.video_call,
              onTap: () => context.push(AppRoutes.telehealth),
            ),
            const SizedBox(height: 12),
            Text('Care team', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _OpsTile(
              title: unreadMessageCount > 0
                  ? 'Messages ($unreadMessageCount unread)'
                  : 'Messages',
              subtitle: unreadMessageCount > 0
                  ? 'New replies from your care team'
                  : 'Chat with therapists',
              icon: Icons.message,
              onTap: () => context.push(AppRoutes.messages),
            ),
            _OpsTile(
              title: 'Find therapist',
              subtitle: 'Browse matched providers',
              icon: Icons.search,
              onTap: () => context.push(AppRoutes.matching),
            ),
            _OpsTile(
              title: 'My children',
              subtitle: 'Profiles and date of birth',
              icon: Icons.child_care,
              onTap: () => context.push('${AppRoutes.parentHome}/children'),
            ),
            _OpsTile(
              title: 'Session history',
              subtitle: 'Past completed sessions',
              icon: Icons.history,
              onTap: () => context.push('${AppRoutes.parentHome}/session-history'),
            ),
            _OpsTile(
              title: 'Treatment plans',
              subtitle: 'Goals and care plans',
              icon: Icons.medical_information,
              onTap: () => context.push('${AppRoutes.parentHome}/treatment-plans'),
            ),
            _OpsTile(
              title: 'Screening',
              subtitle: 'Intake assessments',
              icon: Icons.assignment,
              onTap: () => context.push('${AppRoutes.parentHome}/screening'),
            ),
            const SizedBox(height: 12),
            Text('Billing', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _OpsTile(
              title: 'Payments',
              subtitle: 'Invoices and Stripe checkout',
              icon: Icons.payment,
              onTap: () => context.push(AppRoutes.payments),
            ),
            _OpsTile(
              title: 'Insurance',
              subtitle: 'Claims and coverage',
              icon: Icons.health_and_safety,
              onTap: () => context.push(AppRoutes.insurance),
            ),
            _OpsTile(
              title: 'Documents',
              subtitle: 'Upload insurance cards and reports',
              icon: Icons.folder,
              onTap: () => context.push(AppRoutes.documents),
            ),
            const SizedBox(height: 12),
            Text('Account', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _OpsTile(
              title: unreadCount > 0
                  ? 'Notifications ($unreadCount)'
                  : 'Notifications',
              subtitle: unreadCount > 0
                  ? 'Tap message alerts to open the conversation'
                  : 'Alerts and reminders',
              icon: Icons.notifications,
              onTap: () => context.push(AppRoutes.notifications),
            ),
            _OpsTile(
              title: 'My profile',
              subtitle: 'Address and emergency contact',
              icon: Icons.person,
              onTap: () => context.push('${AppRoutes.parentHome}/profile'),
            ),
            _OpsTile(
              title: 'Reviews',
              subtitle: 'Rate your therapists',
              icon: Icons.star,
              onTap: () => context.push('${AppRoutes.parentHome}/reviews'),
            ),
            _OpsTile(
              title: 'Security',
              subtitle: 'Two-factor authentication',
              icon: Icons.security,
              onTap: () => context.push(AppRoutes.security),
            ),
            _OpsTile(
              title: 'Privacy',
              subtitle: 'HIPAA consent',
              icon: Icons.privacy_tip,
              onTap: () => context.push(AppRoutes.consent),
            ),
            _OpsTile(
              title: 'File complaint',
              subtitle: 'Report a concern',
              icon: Icons.report,
              onTap: () => context.push('${AppRoutes.parentHome}/complaints'),
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
