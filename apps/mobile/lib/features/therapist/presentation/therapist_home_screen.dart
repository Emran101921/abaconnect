import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../data/therapist_repository.dart';
import 'session_notes_screen.dart';
import '../../../shared/widgets/app_scaffold.dart';

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
            onPressed: () => context.push('/therapist/session-notes'),
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

    return AppScaffold(
      title: 'Therapist Home',
      actions: [
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () async {
            await ref.read(authStateProvider.notifier).logout();
            if (context.mounted) context.go('/login');
          },
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Upcoming appointments',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          appointments.when(
            data: (list) {
              if (list.isEmpty) {
                return const Card(
                  child: ListTile(
                    title: Text('No appointments scheduled'),
                  ),
                );
              }
              return Column(
                children: [
                  ...list.take(3).map((a) {
                    final canStart = a.status == 'CONFIRMED' ||
                        a.status == 'SCHEDULED' ||
                        a.status == 'REQUESTED';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text('${a.childName} · ${a.therapyType}'),
                        subtitle: Text(
                          DateFormat.yMMMd().add_jm().format(a.scheduledStart),
                        ),
                        trailing: canStart
                            ? IconButton(
                                icon: const Icon(Icons.play_arrow),
                                tooltip: 'Start session',
                                onPressed: () => _startSession(context, ref, a),
                              )
                            : Chip(label: Text(a.status)),
                      ),
                    );
                  }),
                  if (list.length > 3)
                    TextButton(
                      onPressed: () =>
                          context.push('/therapist/appointments'),
                      child: Text('View all ${list.length} appointments'),
                    ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Card(
              child: ListTile(
                title: const Text('Could not load appointments'),
                subtitle: Text('$e'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _NavTile(
            title: 'Appointments',
            icon: Icons.event,
            onTap: () => context.push('/therapist/appointments'),
          ),
          _NavTile(
            title: 'My Profile',
            icon: Icons.person,
            onTap: () => context.push('/therapist/profile'),
          ),
          _NavTile(
            title: 'Session Notes',
            icon: Icons.note_alt,
            onTap: () => context.push('/therapist/session-notes'),
          ),
          _NavTile(
            title: 'Treatment Plans',
            icon: Icons.medical_information,
            onTap: () => context.push('/therapist/plans'),
          ),
          _NavTile(
            title: 'Notifications',
            icon: Icons.notifications,
            onTap: () => context.push('/notifications'),
          ),
          _NavTile(
            title: 'Messages',
            icon: Icons.message,
            onTap: () => context.push('/messages'),
          ),
          _NavTile(
            title: 'Telehealth',
            icon: Icons.video_call,
            onTap: () => context.push('/telehealth'),
          ),
          _NavTile(
            title: 'Payouts',
            icon: Icons.payments,
            onTap: () => context.push('/therapist/payouts'),
          ),
          _NavTile(
            title: 'Security',
            icon: Icons.security,
            onTap: () => context.push('/security'),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
