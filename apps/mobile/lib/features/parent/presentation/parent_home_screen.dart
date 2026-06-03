import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../data/parent_booking_repository.dart';

final parentAppointmentsProvider =
    FutureProvider<List<AppointmentModel>>((ref) async {
  return ref.watch(parentBookingRepositoryProvider).fetchAppointments();
});

class ParentHomeScreen extends ConsumerWidget {
  const ParentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointments = ref.watch(parentAppointmentsProvider);

    return AppScaffold(
      title: 'Parent Home',
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
                    title: Text('No appointments yet'),
                    subtitle: Text('Book a session to get started'),
                  ),
                );
              }
              return Column(
                children: list.take(3).map((a) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(a.therapyType),
                      subtitle: Text(
                        '${a.childName} with ${a.therapistName}\n'
                        '${DateFormat.yMMMd().add_jm().format(a.scheduledStart)}',
                      ),
                      trailing: Chip(label: Text(a.status)),
                    ),
                  );
                }).toList(),
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
            title: 'My Children',
            subtitle: 'Manage child profiles',
            icon: Icons.child_care,
            onTap: () => context.push('/parent/children'),
          ),
          _NavTile(
            title: 'Book Session',
            subtitle: 'Schedule therapy appointments',
            icon: Icons.calendar_month,
            onTap: () => context.push('/parent/booking'),
          ),
          _NavTile(
            title: 'Screening',
            subtitle: 'Complete intake assessments',
            icon: Icons.assignment,
            onTap: () => context.push('/parent/screening'),
          ),
          _NavTile(
            title: 'Reviews',
            subtitle: 'Rate your therapists',
            icon: Icons.star,
            onTap: () => context.push('/parent/reviews'),
          ),
          _NavTile(
            title: 'Messages',
            subtitle: 'Chat with your care team',
            icon: Icons.message,
            onTap: () => context.push('/messages'),
          ),
          _NavTile(
            title: 'Payments',
            subtitle: 'View invoices and billing',
            icon: Icons.payment,
            onTap: () => context.push('/payments'),
          ),
          _NavTile(
            title: 'Find Therapist',
            subtitle: 'Browse matched providers',
            icon: Icons.search,
            onTap: () => context.push('/matching'),
          ),
          _NavTile(
            title: 'Telehealth',
            subtitle: 'Join virtual sessions',
            icon: Icons.video_call,
            onTap: () => context.push('/telehealth'),
          ),
          _NavTile(
            title: 'Notifications',
            subtitle: 'Alerts and reminders',
            icon: Icons.notifications,
            onTap: () => context.push('/notifications'),
          ),
          _NavTile(
            title: 'Documents',
            subtitle: 'Insurance cards and reports',
            icon: Icons.folder,
            onTap: () => context.push('/documents'),
          ),
          _NavTile(
            title: 'Insurance',
            subtitle: 'Claims and coverage',
            icon: Icons.health_and_safety,
            onTap: () => context.push('/insurance'),
          ),
          _NavTile(
            title: 'Privacy',
            subtitle: 'HIPAA consent',
            icon: Icons.privacy_tip,
            onTap: () => context.push('/consent'),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
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
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
