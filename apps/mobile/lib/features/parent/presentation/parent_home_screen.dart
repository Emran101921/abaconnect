import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/models/dashboard_action_model.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_section_header.dart';
import '../../../shared/widgets/app_stat_card.dart';
import '../../../shared/widgets/app_wellness_action_menu.dart';
import '../../../shared/widgets/app_wellness_home_header.dart';
import '../../../shared/widgets/app_wellness_journey_card.dart';
import '../../../shared/widgets/app_glossy_button.dart';
import '../../../shared/widgets/app_theme_toggle.dart';
import '../../../shared/widgets/dashboard_action_inbox.dart';
import '../../messaging/messaging_providers.dart';
import '../../messaging/presentation/messages_screen.dart';
import '../../notifications/notification_providers.dart';
import '../data/parent_booking_repository.dart';
import 'parent_category_box.dart';
import 'parent_operations_category_screen.dart';

final parentDashboardProvider = FutureProvider<ParentDashboardModel>((
  ref,
) async {
  return ref.watch(parentBookingRepositoryProvider).fetchDashboard();
});

final parentAppointmentsProvider = FutureProvider<List<AppointmentModel>>((
  ref,
) async {
  return ref.watch(parentBookingRepositoryProvider).fetchAppointments();
});

final parentPendingReviewsProvider = FutureProvider<List<TherapistModel>>((
  ref,
) async {
  return ref
      .watch(parentBookingRepositoryProvider)
      .fetchPendingReviewTherapists();
});

final parentChildrenProvider = FutureProvider<List<ChildModel>>((ref) async {
  return ref.watch(parentBookingRepositoryProvider).fetchChildren();
});

final parentShowsPaymentsProvider = FutureProvider<bool>((ref) async {
  final children = await ref.watch(parentChildrenProvider.future);
  return ParentOperationsCategory.childrenShowPayments(children);
});

class ParentHomeScreen extends ConsumerWidget {
  const ParentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(parentDashboardProvider);
    final pendingReviews = ref.watch(parentPendingReviewsProvider);
    final unread = ref.watch(unreadNotificationsProvider);
    final unreadCount = unread.maybeWhen(data: (c) => c, orElse: () => 0);
    final unreadMessages = ref.watch(unreadMessageThreadsProvider);
    final unreadMessageCount = unreadMessages.maybeWhen(
      data: (c) => c,
      orElse: () => 0,
    );
    final showPayments = ref
        .watch(parentShowsPaymentsProvider)
        .maybeWhen(data: (v) => v, orElse: () => true);

    final user = ref.watch(authStateProvider).valueOrNull?.user;
    final greetingName =
        user?.fullName?.split(' ').first ??
        user?.email.split('@').first ??
        'there';

    return AppScaffold(
      title: 'Parent',
      bottomNavigationBar: ParentBottomNav(current: ParentNavTab.home),
      actions: [
        const AppThemeToggle(compact: true),
        IconButton(
          icon: const Icon(Icons.history),
          tooltip: 'Recent visits',
          onPressed: () =>
              context.push('${AppRoutes.parentHome}/session-history'),
        ),
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
          ref.invalidate(parentPendingReviewsProvider);
          ref.invalidate(parentChildrenProvider);
          ref.invalidate(parentShowsPaymentsProvider);
          ref.invalidate(unreadNotificationsProvider);
          ref.invalidate(unreadMessageThreadsProvider);
          ref.invalidate(messageThreadsProvider);
        },
        child: AppContentContainer(
          padding: EdgeInsets.zero,
          child: ListView(
            children: [
              AppWellnessHomeHeader(
                greeting: 'Welcome back, $greetingName 👋',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    dashboard.when(
                      data: (d) {
                        final progress = d.onboardingStepsTotal > 0
                            ? d.onboardingStepsCompleted /
                                d.onboardingStepsTotal
                            : (d.onboardingComplete ? 1.0 : 0.0);
                        final subtitle = d.hasScreening
                            ? 'Take the next step in your care journey'
                            : 'Complete screening to unlock therapy matches';
                        return AppWellnessJourneyCard(
                          title: 'Your Wellness Journey',
                          subtitle: subtitle,
                          progress: progress,
                          icon: Icons.monitor_heart_outlined,
                        );
                      },
                      loading: () => const AppWellnessJourneyCard(
                        title: 'Your Wellness Journey',
                        subtitle: 'Loading your progress…',
                        progress: 0,
                      ),
                      error: (_, _) => const AppWellnessJourneyCard(
                        title: 'Your Wellness Journey',
                        subtitle: 'Take the next step in your care journey',
                        progress: 0,
                      ),
                    ),
                    const SizedBox(height: 20),
                    AppWellnessActionMenu(
                      items: [
                        AppWellnessActionItem(
                          label: 'Start Screening',
                          icon: Icons.fact_check_outlined,
                          variant: AppGlossyButtonVariant.primary,
                          onTap: () => context.push(
                            dashboard.maybeWhen(
                              data: (d) => d.hasChild
                                  ? '${AppRoutes.parentScreening}?autoStart=true'
                                  : AppRoutes.parentChildren,
                              orElse: () => AppRoutes.parentScreening,
                            ),
                          ),
                        ),
                        AppWellnessActionItem(
                          label: 'Book Session',
                          icon: Icons.calendar_month_outlined,
                          variant: AppGlossyButtonVariant.secondary,
                          onTap: () => context.push(AppRoutes.matching),
                        ),
                        AppWellnessActionItem(
                          label: 'Messages',
                          icon: Icons.chat_bubble_outline_rounded,
                          variant: AppGlossyButtonVariant.tertiary,
                          onTap: () => context.push(AppRoutes.messages),
                        ),
                        AppWellnessActionItem(
                          label: 'Upload Documents',
                          icon: Icons.upload_file_outlined,
                          variant: AppGlossyButtonVariant.info,
                          onTap: () => context.push(AppRoutes.documents),
                        ),
                        AppWellnessActionItem(
                          label: 'Track Progress',
                          icon: Icons.trending_up_rounded,
                          variant: AppGlossyButtonVariant.warning,
                          onTap: () => context.push(
                            '${AppRoutes.parentHome}/progress-notes',
                          ),
                        ),
                        if (pendingReviews.maybeWhen(
                          data: (t) => t.isNotEmpty,
                          orElse: () => false,
                        ))
                          AppWellnessActionItem(
                            label: 'Confirm Session',
                            icon: Icons.check_circle_outline_rounded,
                            variant: AppGlossyButtonVariant.success,
                            onTap: () {
                              final therapists = pendingReviews.valueOrNull;
                              if (therapists != null && therapists.isNotEmpty) {
                                context.push(
                                  '${AppRoutes.parentHome}/reviews'
                                  '?therapistId=${therapists.first.id}&submit=true',
                                );
                              }
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const AppSectionHeader(
                      title: 'Overview',
                      subtitle: 'Your family care at a glance',
                    ),
                    const SizedBox(height: 12),
                    dashboard.when(
                      data: (d) {
                        if (d.onboardingComplete) {
                          return const SizedBox.shrink();
                        }
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
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
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
                                  label:
                                      'Complete Early Intervention screening',
                                  onTap: d.hasScreening
                                      ? null
                                      : () => context.push(
                                          d.hasChild
                                              ? '${AppRoutes.parentScreening}?autoStart=true'
                                              : AppRoutes.parentChildren,
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
                      error: (_, _) => const SizedBox.shrink(),
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
                            onTap: () => context.push(
                              '${AppRoutes.parentHome}/children',
                            ),
                          ),
                          AppStatCard(
                            label: d.appointmentsToday > 0
                                ? 'Schedule · ${d.appointmentsToday} today'
                                : 'Schedule',
                            value: '${d.upcomingAppointments}',
                            icon: Icons.calendar_month_outlined,
                            highlight: d.appointmentsToday > 0,
                            accent: d.appointmentsToday > 0,
                            onTap: () => context.push(
                              '${AppRoutes.parentHome}/appointments',
                            ),
                          ),
                          AppStatCard(
                            label: 'Reviews due',
                            value: '${d.pendingReviews}',
                            highlight: d.pendingReviews > 0,
                            icon: Icons.rate_review_outlined,
                            onTap: () =>
                                context.push('${AppRoutes.parentHome}/reviews'),
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
                            .where((a) => a.actionType != 'CLAIM')
                            .toList();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DashboardActionInbox(items: actions),
                            if (d.lastSessionSummary != null ||
                                d.nextTelehealthAppointmentId != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Care updates',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              if (d.lastSessionSummary != null)
                                Card(
                                  child: ListTile(
                                    leading: const Icon(
                                      Icons.summarize_outlined,
                                    ),
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
                              if (d.nextTelehealthAppointmentId != null)
                                Card(
                                  child: ListTile(
                                    leading: const Icon(
                                      Icons.videocam_outlined,
                                    ),
                                    title: const Text(
                                      'Telehealth visit coming up',
                                    ),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => context.push(
                                      '${AppRoutes.parentHome}/appointments',
                                    ),
                                  ),
                                ),
                            ],
                            const SizedBox(height: 12),
                          ],
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                    pendingReviews.when(
                      data: (therapists) {
                        if (therapists.isEmpty) return const SizedBox.shrink();
                        return Card(
                          color: Theme.of(
                            context,
                          ).colorScheme.secondaryContainer,
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: const Icon(Icons.rate_review),
                            title: const Text('Rate your therapist'),
                            subtitle: Text(
                              '${therapists.length} completed session(s) awaiting feedback',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push(
                              '${AppRoutes.parentHome}/reviews'
                              '?therapistId=${therapists.first.id}&submit=true',
                            ),
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                    Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const Icon(Icons.storefront_outlined),
                        title: const Text('Anonymous service requests'),
                        subtitle: const Text(
                          'Post or manage marketplace requests after screening',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(AppRoutes.parentMarketplace),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const AppSectionHeader(
                      title: 'Operations',
                      subtitle: 'Tap a category to see all options',
                    ),
                    const SizedBox(height: 12),
                    ...ParentOperationsCategory.visibleFor(
                      showPayments: showPayments,
                    ).map((category) {
                      final itemCount = switch (category.id) {
                        'scheduling' => 3,
                        'care-team' => 7,
                        'payments' => 2,
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
  const _OnboardingStep({required this.done, required this.label, this.onTap});

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
