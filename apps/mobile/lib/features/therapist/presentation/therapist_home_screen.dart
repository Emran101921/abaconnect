import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../notifications/notification_providers.dart';
import '../data/therapist_repository.dart';
import 'session_notes_screen.dart';

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
            onPressed: () => context.push('${AppRoutes.therapistHome}/session-notes'),
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointments = ref.watch(therapistAppointmentsProvider);
    final unread = ref.watch(unreadNotificationsProvider);
    final unreadCount = unread.maybeWhen(data: (c) => c, orElse: () => 0);

    return AppScaffold(
      title: 'Therapist',
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
          ref.invalidate(therapistAppointmentsProvider);
          ref.invalidate(unreadNotificationsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Overview', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            appointments.when(
              data: (list) {
                final pending =
                    list.where((a) => a.status == 'REQUESTED').length;
                if (pending > 0) {
                  return Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const Icon(Icons.pending_actions),
                      title: Text('$pending request${pending == 1 ? '' : 's'} pending'),
                      subtitle: const Text('Confirm or decline on Appointments'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          context.push('${AppRoutes.therapistHome}/appointments'),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
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
                      final canStart = a.status == 'CONFIRMED' ||
                          a.status == 'SCHEDULED';
                      final isRequested = a.status == 'REQUESTED';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text('${a.childName} · ${a.therapyType}'),
                          subtitle: Text(
                            '${DateFormat.yMMMd().add_jm().format(a.scheduledStart)} · ${a.status}',
                          ),
                          trailing: canStart
                              ? IconButton(
                                  icon: const Icon(Icons.play_arrow),
                                  tooltip: 'Start session',
                                  onPressed: () => _startSession(context, ref, a),
                                )
                              : isRequested
                                  ? const Icon(Icons.help_outline)
                                  : Chip(label: Text(a.status)),
                          onTap: () =>
                              context.push('${AppRoutes.therapistHome}/appointments'),
                        ),
                      );
                    }),
                    if (list.length > 3)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () =>
                              context.push('${AppRoutes.therapistHome}/appointments'),
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
            const Text('Clinical workflow, communication, and account tools.'),
            const SizedBox(height: 16),
            Text('Clinical', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _OpsTile(
              title: 'Appointments',
              subtitle: 'Confirm, decline, cancel, export calendar',
              icon: Icons.event,
              onTap: () => context.push('${AppRoutes.therapistHome}/appointments'),
            ),
            _OpsTile(
              title: 'Session notes',
              subtitle: 'SOAP documentation',
              icon: Icons.note_alt,
              onTap: () => context.push('${AppRoutes.therapistHome}/session-notes'),
            ),
            _OpsTile(
              title: 'Treatment plans',
              subtitle: 'Goals and care plans',
              icon: Icons.medical_information,
              onTap: () => context.push('${AppRoutes.therapistHome}/plans'),
            ),
            const SizedBox(height: 12),
            Text('Communication', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _OpsTile(
              title: 'Messages',
              subtitle: 'Chat with parents on your caseload',
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
          ],
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
