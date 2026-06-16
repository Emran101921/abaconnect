import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../service_coordinator/data/service_coordinator_repository.dart';
import '../../service_coordinator/presentation/sc_providers.dart';

class AgencyCasesScreen extends ConsumerWidget {
  const AgencyCasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cases = ref.watch(agencyCasesProvider);

    return AppScaffold(
      title: 'Agency cases',
      body: cases.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No children in tenant yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final c = list[index];
              return Card(
                child: ListTile(
                  title: Text(c.childName),
                  subtitle: Text(
                    c.assignedCoordinatorName != null
                        ? 'SC: ${c.assignedCoordinatorName}'
                        : 'No coordinator assigned',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(
                    '${AppRoutes.agencyHome}/cases/${c.childId}/assign-service-coordinator',
                    extra: c,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class AgencyAssignServiceCoordinatorScreen extends ConsumerWidget {
  const AgencyAssignServiceCoordinatorScreen({
    super.key,
    required this.childId,
    this.childName,
    this.assignmentId,
  });

  final String childId;
  final String? childName;
  final String? assignmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coordinators = ref.watch(agencyRosterMembersProvider);

    return AppScaffold(
      title: 'Assign coordinator',
      body: coordinators.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (members) {
          final active = members
              .where((m) => m.status == 'ACTIVE' && m.isActive)
              .toList();
          if (active.isEmpty) {
            return const Center(
              child: Text('Add an active service coordinator first.'),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (childName != null)
                Text(
                  childName!,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              if (assignmentId != null) ...[
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () async {
                    try {
                      await ref
                          .read(serviceCoordinatorRepositoryProvider)
                          .removeChildAssignment(assignmentId!);
                      ref.invalidate(agencyCasesProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Assignment removed')),
                        );
                        context.pop();
                      }
                    } catch (e) {
                      if (context.mounted) AppSnackBar.showError(context, e);
                    }
                  },
                  child: const Text('Remove current assignment'),
                ),
              ],
              const SizedBox(height: 16),
              ...active.map(
                (m) => Card(
                  child: ListTile(
                    title: Text(m.displayName),
                    subtitle: Text('Caseload: ${m.caseload}'),
                    trailing: const Icon(Icons.person_add_alt_1_outlined),
                    onTap: () async {
                      try {
                        await ref
                            .read(serviceCoordinatorRepositoryProvider)
                            .assignChildToCoordinator(
                              childId: childId,
                              coordinatorUserId: m.userId,
                            );
                        ref.invalidate(agencyCasesProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Assigned to ${m.displayName}'),
                            ),
                          );
                          context.pop();
                        }
                      } catch (e) {
                        if (context.mounted) AppSnackBar.showError(context, e);
                      }
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
