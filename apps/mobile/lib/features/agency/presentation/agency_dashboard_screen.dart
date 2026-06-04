import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../platform/data/platform_repository.dart';
import '../data/agency_repository.dart';

final agencyDashboardProvider = FutureProvider<AgencyDashboardModel>((ref) {
  return ref.watch(agencyRepositoryProvider).fetchDashboard();
});

final agencyTherapistsProvider = FutureProvider<List<AgencyTherapistModel>>((ref) {
  return ref.watch(agencyRepositoryProvider).fetchTherapists();
});

final agencyInviteCandidatesProvider =
    FutureProvider<List<AgencyTherapistModel>>((ref) {
  return ref.watch(agencyRepositoryProvider).fetchAvailableToInvite();
});

final agencyAnalyticsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(platformRepositoryProvider).fetchTenantAnalytics();
});

Future<void> _showInviteTherapist(BuildContext context, WidgetRef ref) async {
  final candidates = await ref.read(agencyInviteCandidatesProvider.future);
  if (!context.mounted) return;
  if (candidates.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All therapists are already on your roster')),
    );
    return;
  }
  final selected = await showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Invite therapist'),
      children: candidates
          .map(
            (t) => SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, t.id),
              child: Text(t.displayName),
            ),
          )
          .toList(),
    ),
  );
  if (selected == null) return;
  try {
    await ref.read(agencyRepositoryProvider).inviteTherapist(selected);
    ref.invalidate(agencyTherapistsProvider);
    ref.invalidate(agencyInviteCandidatesProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Therapist added to agency')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invite failed: $e')),
      );
    }
  }
}

class AgencyDashboardScreen extends ConsumerWidget {
  const AgencyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(agencyDashboardProvider);
    final analytics = ref.watch(agencyAnalyticsProvider);

    return AppScaffold(
      title: 'Agency Dashboard',
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications),
          onPressed: () => context.push('/notifications'),
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () => context.go('/login'),
        ),
      ],
      body: dashboard.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (stats) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(agencyDashboardProvider);
            ref.invalidate(agencyTherapistsProvider);
            ref.invalidate(agencyAnalyticsProvider);
            await ref.read(agencyDashboardProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              analytics.when(
                data: (metrics) {
                  if (metrics.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Analytics',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: metrics.map((m) {
                          return Chip(
                            label: Text(
                              '${m['key']}: ${m['value']}',
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                  _StatCard(
                    title: 'Therapists',
                    value: '${stats.therapistCount}',
                  ),
                  _StatCard(
                    title: 'Active Clients',
                    value: '${stats.activeClients}',
                  ),
                  _StatCard(
                    title: 'Sessions Today',
                    value: '${stats.appointmentsToday}',
                  ),
                  _StatCard(
                    title: 'Pending Verify',
                    value: '${stats.pendingTherapists}',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _showInviteTherapist(context, ref),
                icon: const Icon(Icons.person_add),
                label: const Text('Invite therapist to agency'),
              ),
              const SizedBox(height: 24),
              Text(
                'Roster',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const _TherapistRoster(),
            ],
          ),
        ),
      ),
    );
  }
}

class _TherapistRoster extends ConsumerWidget {
  const _TherapistRoster();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final therapists = ref.watch(agencyTherapistsProvider);
    return therapists.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Roster error: $e'),
      data: (list) => Column(
        children: list
            .map(
              (t) => Card(
                child: ListTile(
                  title: Text(t.displayName),
                  subtitle: Text(
                    t.isVerified
                        ? 'Verified · ${t.licenseNumber ?? 'Licensed'}'
                        : 'Pending verification',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v != 'remove') return;
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Remove from roster?'),
                          content: Text(
                            'Remove ${t.displayName} from your agency roster?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Remove'),
                            ),
                          ],
                        ),
                      );
                      if (ok != true || !context.mounted) return;
                      try {
                        await ref
                            .read(agencyRepositoryProvider)
                            .removeTherapist(t.id);
                        ref.invalidate(agencyTherapistsProvider);
                        ref.invalidate(agencyInviteCandidatesProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Removed from roster')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed: $e')),
                          );
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'remove',
                        child: Text('Remove from roster'),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
