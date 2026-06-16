import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../../service_coordinator/presentation/sc_providers.dart';
import 'agency_providers.dart';

class AgencyRosterScreen extends ConsumerWidget {
  const AgencyRosterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: AppScaffold(
        title: 'Agency roster',
        actions: [
          IconButton(
            icon: const Icon(Icons.storefront_outlined),
            tooltip: 'Browse marketplace',
            onPressed: () => context.push(AppRoutes.agencyMarketplace),
          ),
        ],
        body: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Providers'),
                Tab(text: 'Service coordinators'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _TherapistRosterTab(),
                  _ServiceCoordinatorRosterTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TherapistRosterTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final therapists = ref.watch(agencyTherapistsProvider);

    return therapists.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(AppSnackBar.messageFromError(e))),
      data: (list) {
        if (list.isEmpty) {
          return const Center(child: Text('No therapists on your roster yet.'));
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
              final pending = t.rosterStatus == 'PENDING';
              return Card(
                child: ListTile(
                  title: Text(t.displayName),
                  subtitle: Text(
                    pending
                        ? 'Pending approval · ${t.onboardingStatus ?? 'PENDING'}'
                        : t.isVerified
                        ? 'Active · ${t.licenseNumber ?? 'Licensed'}'
                        : 'Pending verification',
                  ),
                  trailing: pending
                      ? GlossyButton(
                          title: 'Approve',
                          size: GlossyButtonSize.small,
                          fullWidth: false,
                          onPressed: () async {
                            try {
                              await ref
                                  .read(agencyRepositoryProvider)
                                  .approveAgencyStaff(t.id);
                              ref.invalidate(agencyTherapistsProvider);
                            } catch (e) {
                              if (context.mounted) {
                                AppSnackBar.showError(context, e);
                              }
                            }
                          },
                        )
                      : null,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ServiceCoordinatorRosterTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(agencyRosterMembersProvider);

    return members.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(AppSnackBar.messageFromError(e))),
      data: (list) {
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(agencyRosterMembersProvider);
            await ref.read(agencyRosterMembersProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GlossyButton(
                title: 'Add service coordinator',
                icon: Icons.person_add_alt_1_outlined,
                onPressed: () => context.push(
                  '${AppRoutes.agencyHome}/roster/add-service-coordinator',
                ),
              ),
              const SizedBox(height: 16),
              if (list.isEmpty)
                const Text('No service coordinators on roster yet.')
              else
                ...list.map(
                  (m) => Card(
                    child: ListTile(
                      title: Text(m.displayName),
                      subtitle: Text(
                        '${m.status} · Caseload ${m.caseload}'
                        '${m.lastLoginAt != null ? ' · Last login ${m.lastLoginAt}' : ''}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(
                        '${AppRoutes.agencyHome}/roster/${m.userId}',
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
