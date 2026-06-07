import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/models/dashboard_action_model.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/dashboard_action_inbox.dart';
import '../../messaging/messaging_providers.dart';
import '../../messaging/presentation/messages_screen.dart';
import '../../messaging/presentation/recent_messages_section.dart';
import '../../notifications/notification_providers.dart';
import '../data/parent_booking_repository.dart';
import 'session_history_screen.dart';

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
          ref.invalidate(parentDashboardProvider);
          ref.invalidate(parentAppointmentsProvider);
          ref.invalidate(parentPendingReviewsProvider);
          ref.invalidate(unreadNotificationsProvider);
          ref.invalidate(unreadMessageThreadsProvider);
          ref.invalidate(messageThreadsProvider);
          ref.invalidate(sessionHistoryProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Overview', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            dashboard.when(
              data: (d) {
                if (d.onboardingComplete) return const SizedBox.shrink();
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Getting started',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: d.onboardingStepsTotal > 0
                              ? d.onboardingStepsCompleted /
                                  d.onboardingStepsTotal
                              : 0,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${d.onboardingStepsCompleted} of ${d.onboardingStepsTotal} steps complete',
                        ),
                        const SizedBox(height: 12),
                        _OnboardingStep(
                          done: true,
                          label: 'Create account',
                        ),
                        _OnboardingStep(
                          done: d.hasChild,
                          label: 'Add child profile',
                          onTap: d.hasChild
                              ? null
                              : () => context.push(
                                    '${AppRoutes.parentHome}/children',
                                  ),
                        ),
                        _OnboardingStep(
                          done: d.hasScreening,
                          label: 'Complete screening',
                          onTap: d.hasScreening
                              ? null
                              : () => context.push(
                                    '${AppRoutes.parentHome}/screening',
                                  ),
                        ),
                        _OnboardingStep(
                          done: d.hasBookedTherapist,
                          label: 'Book a therapist',
                          onTap: d.hasBookedTherapist
                              ? null
                              : () => context.push(AppRoutes.matching),
                        ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
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
            dashboard.when(
              data: (d) {
                final actions = d.actionItems
                    .map((e) => DashboardActionModel.fromJson(e))
                    .toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DashboardActionInbox(items: actions),
                    if (d.lastSessionSummary != null ||
                        d.openClaimsCount > 0 ||
                        d.nextTelehealthAppointmentId != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Care & billing',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (d.lastSessionSummary != null)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.summarize_outlined),
                            title: const Text('Latest session summary'),
                            subtitle: Text(
                              d.lastSessionSummary!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push(
                              '${AppRoutes.parentHome}/progress-notes',
                            ),
                          ),
                        ),
                      if (d.openClaimsCount > 0)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.receipt_long_outlined),
                            title: Text('${d.openClaimsCount} open claim(s)'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push(AppRoutes.insurance),
                          ),
                        ),
                      if (d.nextTelehealthAppointmentId != null)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.videocam_outlined),
                            title: const Text('Telehealth visit coming up'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context
                                .push('${AppRoutes.parentHome}/appointments'),
                          ),
                        ),
                    ],
                    const SizedBox(height: 12),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
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
                  return Card(
                    child: ListTile(
                      title: const Text('No upcoming appointments'),
                      subtitle: const Text('Book a session to get started'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(AppRoutes.matching),
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
            const SizedBox(height: 16),
            Text('Recent visits', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Consumer(
              builder: (context, ref, _) {
                final history = ref.watch(sessionHistoryProvider);
                return history.when(
                  data: (sessions) {
                    final recent = sessions
                        .where((s) => s.status == 'COMPLETED')
                        .take(2)
                        .toList();
                    if (recent.isEmpty) {
                      return const Card(
                        child: ListTile(
                          title: Text('No visit summaries yet'),
                          subtitle: Text(
                            'Completed sessions with therapist notes appear here',
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        ...recent.map(
                          (s) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Icon(
                                s.hasProgressNote
                                    ? Icons.summarize_outlined
                                    : Icons.history,
                              ),
                              title: Text('${s.therapyType} · ${s.childName}'),
                              subtitle: Text(
                                s.progressNoteSummary ??
                                    'Summary pending from ${s.therapistName}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.push(
                                '${AppRoutes.parentHome}/session-history',
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => context.push(
                              '${AppRoutes.parentHome}/session-history',
                            ),
                            child: const Text('View all sessions'),
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const SizedBox.shrink(),
                );
              },
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
              title: 'Progress notes',
              subtitle: 'Session summaries from your therapist',
              icon: Icons.summarize_outlined,
              onTap: () => context.push('${AppRoutes.parentHome}/progress-notes'),
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

class _OnboardingStep extends StatelessWidget {
  const _OnboardingStep({
    required this.done,
    required this.label,
    this.onTap,
  });

  final bool done;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        done ? Icons.check_circle : Icons.radio_button_unchecked,
        color: done
            ? Colors.green.shade700
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(label),
      trailing: onTap != null ? const Icon(Icons.chevron_right) : null,
      onTap: onTap,
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
