import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import 'agency_providers.dart';

class AgencyRosterScreen extends ConsumerWidget {
  const AgencyRosterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final therapists = ref.watch(agencyTherapistsProvider);

    return AppScaffold(
      title: 'Therapist roster',
      body: therapists.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Roster error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Text('No therapists on your roster yet.'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(agencyTherapistsProvider);
              await ref.read(agencyTherapistsProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final t = list[index];
                return Card(
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
                              const SnackBar(
                                content: Text('Removed from roster'),
                              ),
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
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'remove',
                          child: Text('Remove from roster'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
