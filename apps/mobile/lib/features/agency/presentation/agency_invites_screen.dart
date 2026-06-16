import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/glossy_button.dart';
import 'agency_providers.dart';

class AgencyInvitesScreen extends ConsumerWidget {
  const AgencyInvitesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidates = ref.watch(agencyInviteCandidatesProvider);

    return AppScaffold(
      title: 'Invite therapists',
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          GlossyFab.extended(
            icon: Icons.person_add_alt_1,
            label: 'Create staff',
            onPressed: () => context.push(AppRoutes.agencyAddStaff),
            tooltip: 'Create new staff account',
          ),
          const SizedBox(height: 12),
          GlossyFab.extended(
            icon: Icons.person_add,
            label: 'Invite existing',
            onPressed: () => showInviteTherapist(context, ref),
            tooltip: 'Invite existing therapist',
          ),
        ],
      ),
      body: candidates.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Text(
                'All verified therapists are already on your roster.',
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(agencyInviteCandidatesProvider);
              await ref.read(agencyInviteCandidatesProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Tap Invite or choose a therapist below to add them to your agency.',
                ),
                const SizedBox(height: 16),
                ...list.map(
                  (t) => Card(
                    child: ListTile(
                      title: Text(t.displayName),
                      subtitle: Text(t.licenseNumber ?? 'Licensed provider'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        try {
                          await ref
                              .read(agencyRepositoryProvider)
                              .inviteTherapist(t.id);
                          ref.invalidate(agencyTherapistsProvider);
                          ref.invalidate(agencyInviteCandidatesProvider);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${t.displayName} added to roster',
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Invite failed: $e')),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
