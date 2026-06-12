import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/models/dashboard_action_model.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_section_header.dart';
import '../../../shared/widgets/app_stat_card.dart';
import '../../../shared/widgets/app_glossy_button.dart';
import '../../../shared/widgets/app_wellness_action_menu.dart';
import '../../../shared/widgets/app_wellness_home_header.dart';
import '../../../shared/widgets/app_wellness_journey_card.dart';
import '../../../shared/widgets/dashboard_action_inbox.dart';
import '../../messaging/messaging_providers.dart';
import '../../messaging/presentation/messages_screen.dart';
import '../../notifications/notification_providers.dart';
import '../data/therapist_repository.dart';
import '../therapist_providers.dart';
import 'session_notes_screen.dart';
import 'therapist_weekly_progress_section.dart';

final therapistAppointmentsProvider =
    FutureProvider<List<TherapistAppointmentModel>>((ref) async {
      return ref.watch(therapistRepositoryProvider).fetchAppointments();
    });

class TherapistHomeScreen extends ConsumerWidget {
  const TherapistHomeScreen({super.key});

  Future<void> _startSession(
    BuildContext context,
    WidgetRef ref,
    TherapistAppointmentModel appointment,
  ) async {
    try {
      await ref.read(therapistRepositoryProvider).startSession(appointment.id);
      ref.invalidate(therapistSessionsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Session started for ${appointment.childName}'),
          action: SnackBarAction(
            label: 'SOAP',
            onPressed: () =>
                context.push('${AppRoutes.therapistHome}/session-notes'),
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not start: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(therapistDashboardProvider);
    final appointments = ref.watch(therapistAppointmentsProvider);
    final unread = ref.watch(unreadNotificationsProvider);
    final unreadCount = unread.maybeWhen(data: (c) => c, orElse: () => 0);
    final unreadMessages = ref.watch(unreadMessageThreadsProvider);
    final unreadMessageCount = unreadMessages.maybeWhen(
      data: (c) => c,
      orElse: () => 0,
    );
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    final greetingName =
        user?.fullName?.split(' ').first ?? user?.email.split('@').first ?? 'there';

    return AppScaffold(
      title: 'Therapist',
      bottomNavigationBar: TherapistBottomNav(
        current: TherapistNavTab.home,
      ),
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
          ref.invalidate(therapistDashboardProvider);
          ref.invalidate(therapistAppointmentsProvider);
          ref.invalidate(unreadNotificationsProvider);
          ref.invalidate(unreadMessageThreadsProvider);
          ref.invalidate(messageThreadsProvider);
          ref.invalidate(therapistDashboardProvider);
          ref.invalidate(therapistWeeklyProgressProvider);
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
                child: dashboard.when(
                  data: (d) {
                    final docProgress = d.pendingDocumentation > 0
                        ? 0.5
                        : (d.inProgressSessions > 0 ? 0.75 : 1.0);
                    return AppWellnessJourneyCard(
                      title: 'Clinical Day',
                      subtitle: d.pendingDocumentation > 0
                          ? '${d.pendingDocumentation} session note(s) due'
                          : 'You are caught up on documentation',
                      progress: docProgress,
                      icon: Icons.medical_services_outlined,
                      iconColor: Theme.of(context).colorScheme.primary,
                    );
                  },
                  loading: () => const AppWellnessJourneyCard(
                    title: 'Clinical Day',
                    subtitle: 'Loading…',
                    progress: 0,
                  ),
                  error: (_, _) => const AppWellnessJourneyCard(
                    title: 'Clinical Day',
                    subtitle: 'Your clinical day at a glance',
                    progress: 0,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AppWellnessActionMenu(
                  items: [
                    AppWellnessActionItem(
                      label: 'Session Notes',
                      icon: Icons.edit_note_outlined,
                      variant: AppGlossyButtonVariant.primary,
                      onTap: () => context.push(
                        '${AppRoutes.therapistHome}/session-notes',
                      ),
                    ),
                    AppWellnessActionItem(
                      label: 'Appointments',
                      icon: Icons.calendar_month_outlined,
                      variant: AppGlossyButtonVariant.secondary,
                      onTap: () => context.push(
                        '${AppRoutes.therapistHome}/appointments',
                      ),
                    ),
                    AppWellnessActionItem(
                      label: 'Messages',
                      icon: Icons.chat_bubble_outline_rounded,
                      variant: AppGlossyButtonVariant.tertiary,
                      onTap: () => context.push(AppRoutes.messages),
                    ),
                    AppWellnessActionItem(
                      label: 'My Profile',
                      icon: Icons.badge_outlined,
                      variant: AppGlossyButtonVariant.info,
                      onTap: () => context.push(
                        '${AppRoutes.therapistHome}/profile',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: AppSectionHeader(
                  title: 'Overview',
                  subtitle: 'Your clinical day at a glance',
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: dashboard.when(
                  data: (d) => Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      AppStatCard(
                        label: 'Pending requests',
                        value: '${d.pendingRequests}',
                        highlight: d.pendingRequests > 0,
                        icon: Icons.inbox_outlined,
                        onTap: () => context.push(
                          '${AppRoutes.therapistHome}/appointments',
                        ),
                      ),
                      AppStatCard(
                        label: 'Today',
                        value: '${d.appointmentsToday}',
                        icon: Icons.today_outlined,
                        accent: d.appointmentsToday > 0,
                        onTap: () => context.push(
                          '${AppRoutes.therapistHome}/appointments',
                        ),
                      ),
                      AppStatCard(
                        label: 'In progress',
                        value: '${d.inProgressSessions}',
                        highlight: d.inProgressSessions > 0,
                        icon: Icons.play_circle_outline,
                        onTap: () => context.push(
                          '${AppRoutes.therapistHome}/session-notes',
                        ),
                      ),
                      AppStatCard(
                        label: 'SOAP due',
                        value: '${d.pendingDocumentation}',
                        highlight: d.pendingDocumentation > 0,
                        icon: Icons.edit_note_outlined,
                        onTap: () => context.push(
                          '${AppRoutes.therapistHome}/session-notes',
                        ),
                      ),
                    ],
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Overview error: $e'),
                ),
              ),
              const SizedBox(height: 12),
              dashboard.when(
                data: (d) => DashboardActionInbox(
                  items: d.actionItems
                      .map((e) => DashboardActionModel.fromJson(e))
                      .toList(),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              const TherapistWeeklyProgressSection(),
              const SizedBox(height: 12),
              appointments.when(
                data: (list) {
                  final pending = list
                      .where((a) => a.status == 'REQUESTED')
                      .length;
                  if (pending > 0) {
                    return Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const Icon(Icons.pending_actions),
                        title: Text(
                          '$pending request${pending == 1 ? '' : 's'} pending',
                        ),
                        subtitle: const Text(
                          'Confirm or decline on Appointments',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(
                          '${AppRoutes.therapistHome}/appointments',
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              appointments.when(
                data: (list) {
                  if (list.isEmpty) {
                    return const Card(
                      child: ListTile(
                        title: Text('No appointments scheduled'),
                        subtitle: Text('Parents can book sessions with you'),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      ...list.take(3).map((a) {
                        final canStart =
                            a.status == 'CONFIRMED' || a.status == 'SCHEDULED';
                        final isRequested = a.status == 'REQUESTED';
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text('${a.childName} · ${a.therapyType}'),
                            subtitle: Text(
                              '${DateFormat.yMMMd().add_jm().format(a.scheduledStart)} · ${a.status}'
                              '${a.isTelehealth ? ' · Telehealth' : ''}',
                            ),
                            trailing: canStart
                                ? IconButton(
                                    icon: const Icon(Icons.play_arrow),
                                    tooltip: 'Start session',
                                    onPressed: () =>
                                        _startSession(context, ref, a),
                                  )
                                : isRequested
                                ? const Icon(Icons.help_outline)
                                : Chip(label: Text(a.status)),
                            onTap: () => context.push(
                              '${AppRoutes.therapistHome}/appointments',
                            ),
                          ),
                        );
                      }),
                      if (list.length > 3)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => context.push(
                              '${AppRoutes.therapistHome}/appointments',
                            ),
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
              const Text(
                'Clinical workflow, communication, and account tools.',
              ),
              const SizedBox(height: 16),
              Text('Clinical', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              _OpsTile(
                title: 'Appointments',
                subtitle: 'Confirm, decline, cancel, export calendar',
                icon: Icons.event,
                onTap: () =>
                    context.push('${AppRoutes.therapistHome}/appointments'),
              ),
              _OpsTile(
                title: 'Session Notes and Service logs',
                subtitle: 'NYC EIP form, SOAP documentation & parent-signed logs',
                icon: Icons.note_alt,
                onTap: () =>
                    context.push('${AppRoutes.therapistHome}/session-notes'),
              ),
              _OpsTile(
                title: 'Treatment plans',
                subtitle: 'Goals and care plans',
                icon: Icons.medical_information,
                onTap: () => context.push('${AppRoutes.therapistHome}/plans'),
              ),
              const SizedBox(height: 12),
              Text(
                'Communication',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              _OpsTile(
                title: unreadMessageCount > 0
                    ? 'Messages ($unreadMessageCount unread)'
                    : 'Messages',
                subtitle: unreadMessageCount > 0
                    ? 'New replies from parents'
                    : 'Chat with parents on your caseload',
                icon: Icons.message,
                onTap: () => context.push(AppRoutes.messages),
              ),
              _OpsTile(
                title: 'Telehealth',
                subtitle: 'Virtual session rooms',
                icon: Icons.video_call,
                onTap: () => context.push(AppRoutes.telehealth),
              ),
              _OpsTile(
                title: 'Documents',
                subtitle: 'Upload licenses and reports',
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
                subtitle: 'Tap alerts to open messages or appointments',
                icon: Icons.notifications,
                onTap: () => context.push(AppRoutes.notifications),
              ),
              _OpsTile(
                title: 'Service marketplace',
                subtitle: 'Browse anonymous requests by ZIP area',
                icon: Icons.storefront_outlined,
                onTap: () => context.push(AppRoutes.therapistMarketplace),
              ),
              _OpsTile(
                title: 'My profile',
                subtitle: 'License, bio, and verification',
                icon: Icons.person,
                onTap: () => context.push('${AppRoutes.therapistHome}/profile'),
              ),
              _OpsTile(
                title: 'Payouts',
                subtitle: 'Earnings and payout status',
                icon: Icons.payments,
                onTap: () => context.push('${AppRoutes.therapistHome}/payouts'),
              ),
              _OpsTile(
                title: 'Security',
                subtitle: 'Two-factor authentication',
                icon: Icons.security,
                onTap: () => context.push(AppRoutes.security),
              ),
              _OpsTile(
                title: 'Privacy & HIPAA',
                subtitle: 'Notice, policy, and your privacy rights',
                icon: Icons.privacy_tip_outlined,
                onTap: () => context.push(AppRoutes.settingsPrivacy),
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
