import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/models/dashboard_action_model.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_dashboard_card.dart';
import '../../../shared/widgets/app_section_header.dart';
import '../../../shared/widgets/app_stat_card.dart';
import '../../../shared/widgets/app_welcome_banner.dart';
import '../../../shared/widgets/app_healthcare_illustration.dart';
import '../../../shared/widgets/app_theme_toggle.dart';
import '../../../shared/widgets/dashboard_action_inbox.dart';
import '../../messaging/messaging_providers.dart';
import '../../messaging/presentation/messages_screen.dart';
import '../../messaging/presentation/recent_messages_section.dart';
import '../../notifications/notification_providers.dart';
import '../data/parent_booking_repository.dart';
import 'parent_category_box.dart';
import 'parent_operations_category_screen.dart';
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

    final user = ref.watch(authStateProvider).valueOrNull?.user;
    final greetingName = user?.fullName?.split(' ').first ??
        user?.email.split('@').first ??
        'there';

    return AppScaffold(
      title: 'Parent',
      bottomNavigationBar: const ParentBottomNav(current: ParentNavTab.home),
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
          ref.invalidate(parentDashboardProvider);
          ref.invalidate(parentAppointmentsProvider);
          ref.invalidate(parentPendingReviewsProvider);
          ref.invalidate(unreadNotificationsProvider);
          ref.invalidate(unreadMessageThreadsProvider);
          ref.invalidate(messageThreadsProvider);
          ref.invalidate(sessionHistoryProvider);
        },
        child: AppContentContainer(
          padding: EdgeInsets.zero,
          child: ListView(
          children: [
            AppWelcomeBanner(
              greeting: 'Welcome back, $greetingName',
              subtitle: 'Your family care hub — screening, therapy, and progress in one place.',
              trailing: dashboard.maybeWhen(
                data: (d) => AppDashboardCard(
                  child: Row(
                    children: [
                      const AppHealthcareIllustration(
                        type: AppIllustrationType.progress,
                        size: 56,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${d.childrenCount} child${d.childrenCount == 1 ? '' : 'ren'} · ${d.upcomingAppointments} upcoming',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text(
                              d.hasScreening
                                  ? 'Screening complete — explore recommendations'
                                  : 'Complete screening to unlock therapy matches',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
            const AppSectionHeader(
              title: 'Overview',
              subtitle: 'Your family care at a glance',
            ),
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
                          label: 'Complete Early Intervention screening',
                          onTap: d.hasScreening
                              ? null
                              : () => context.push(
                                    d.hasChild
                                        ? '${AppRoutes.parentScreening}?autoStart=true'
                                        : '${AppRoutes.parentChildren}',
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
                  AppStatCard(
                    label: 'Children',
                    value: '${d.childrenCount}',
                    icon: Icons.child_care_outlined,
                    onTap: () => context.push('${AppRoutes.parentHome}/children'),
                  ),
                  AppStatCard(
                    label: 'Upcoming',
                    value: '${d.upcomingAppointments}',
                    icon: Icons.event_outlined,
                    onTap: () =>
                        context.push('${AppRoutes.parentHome}/appointments'),
                  ),
                  AppStatCard(
                    label: 'Today',
                    value: '${d.appointmentsToday}',
                    icon: Icons.today_outlined,
                    accent: d.appointmentsToday > 0,
                    onTap: () =>
                        context.push('${AppRoutes.parentHome}/appointments'),
                  ),
                  AppStatCard(
                    label: 'Reviews due',
                    value: '${d.pendingReviews}',
                    highlight: d.pendingReviews > 0,
                    icon: Icons.rate_review_outlined,
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
            const AppSectionHeader(
              title: 'Operations',
              subtitle: 'Tap a category to see all options',
            ),
            const SizedBox(height: 12),
            ...ParentOperationsCategory.all.map((category) {
              final itemCount = switch (category.id) {
                'scheduling' => 3,
                'care-team' => 7,
                'billing' => 3,
                'account' => 6,
                _ => 0,
              };
              final badge = switch (category.id) {
                'care-team' when unreadMessageCount > 0 =>
                  '$unreadMessageCount unread',
                'account' when unreadCount > 0 => '$unreadCount new',
                _ => null,
              };
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ParentCategoryBox(
                  title: category.title,
                  subtitle: category.subtitle,
                  icon: category.icon,
                  itemCount: itemCount,
                  badge: badge,
                  onTap: () => context.push(
                    '${AppRoutes.parentHome}/operations/${category.id}',
                  ),
                ),
              );
            }),
                ],
              ),
            ),
          ],
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

