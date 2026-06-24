import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../../service_coordinator/data/service_coordinator_repository.dart';
import '../../service_coordinator/presentation/sc_providers.dart';

class AgencyRosterMemberScreen extends ConsumerWidget {
  const AgencyRosterMemberScreen({super.key, required this.rosterMemberUserId});

  final String rosterMemberUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(agencyRosterMembersProvider);

    return AppScaffold(
      title: 'Roster member',
      body: members.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          AgencyRosterMemberModel? member;
          for (final e in list) {
            if (e.userId == rosterMemberUserId) {
              member = e;
              break;
            }
          }
          if (member == null) {
            return const Center(child: Text('Member not found'));
          }
          final m = member;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.displayName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text('Email: ${m.email}'),
                Text('Status: ${m.status}'),
                Text('Caseload: ${m.caseload}'),
                Text('Languages: ${m.languages.join(', ')}'),
                if (m.notes != null) Text('Notes: ${m.notes}'),
                const SizedBox(height: 24),
                if (m.status == 'ACTIVE')
                  GlossyButton(
                    title: 'Deactivate',
                    variant: GlossyButtonVariant.danger,
                    onPressed: () async {
                      try {
                        await ref
                            .read(serviceCoordinatorRepositoryProvider)
                            .updateServiceCoordinatorStatus(
                              coordinatorUserId: m.userId,
                              status: 'INACTIVE',
                            );
                        ref.invalidate(agencyRosterMembersProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Coordinator deactivated')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) AppSnackBar.showError(context, e);
                      }
                    },
                  ),
                if (m.status != 'ACTIVE')
                  GlossyButton(
                    title: 'Activate',
                    onPressed: () async {
                      try {
                        await ref
                            .read(serviceCoordinatorRepositoryProvider)
                            .updateServiceCoordinatorStatus(
                              coordinatorUserId: m.userId,
                              status: 'ACTIVE',
                            );
                        ref.invalidate(agencyRosterMembersProvider);
                      } catch (e) {
                        if (context.mounted) AppSnackBar.showError(context, e);
                      }
                    },
                  ),
                const SizedBox(height: 8),
                GlossyButton(
                  title: 'Remove from roster',
                  variant: GlossyButtonVariant.neutral,
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Remove from roster?'),
                        content: const Text(
                          'This suspends access and removes case assignments.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Remove'),
                          ),
                        ],
                      ),
                    );
                    if (confirm != true) return;
                    try {
                      await ref
                          .read(serviceCoordinatorRepositoryProvider)
                          .removeServiceCoordinator(m.userId);
                      ref.invalidate(agencyRosterMembersProvider);
                      if (context.mounted) Navigator.of(context).pop();
                    } catch (e) {
                      if (context.mounted) AppSnackBar.showError(context, e);
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
