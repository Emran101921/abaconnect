import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_data_table.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/app_status_badge.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../../service_coordinator/data/service_coordinator_repository.dart';
import '../../service_coordinator/presentation/sc_providers.dart';
import '../data/agency_repository.dart';
import 'agency_providers.dart';

AppStatusKind _rosterStatusKind({
  required bool pending,
  required bool verified,
}) {
  if (pending) return AppStatusKind.pending;
  if (verified) return AppStatusKind.active;
  return AppStatusKind.pending;
}

class AgencyRosterScreen extends ConsumerWidget {
  const AgencyRosterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: AppScaffold(
        title: 'Agency roster',
        subtitle: 'Providers and service coordinators',
        showPageBreadcrumbs: true,
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
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(agencyTherapistsProvider);
            await ref.read(agencyTherapistsProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppDataTable<AgencyTherapistModel>(
                rows: list,
                onRowTap: (t) => context.push(
                  '${AppRoutes.agencyHome}/providers/${t.id}',
                ),
                searchHint: 'Search providers…',
                searchPredicate: (t, q) {
                  final needle = q.toLowerCase();
                  return t.displayName.toLowerCase().contains(needle) ||
                      (t.email ?? '').toLowerCase().contains(needle) ||
                      (t.licenseNumber ?? '').toLowerCase().contains(needle);
                },
                columns: [
                  AppDataColumn(
                    label: 'Provider',
                    mobilePriority: true,
                    cellBuilder: (context, t) => Text(
                      t.displayName,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  AppDataColumn(
                    label: 'Status',
                    mobilePriority: true,
                    cellBuilder: (context, t) {
                      final pending = t.rosterStatus == 'PENDING';
                      return AppStatusBadge.fromKind(
                        _rosterStatusKind(
                          pending: pending,
                          verified: t.isVerified,
                        ),
                        label: pending
                            ? 'Pending approval'
                            : t.isVerified
                            ? 'Active'
                            : 'Pending verification',
                      );
                    },
                  ),
                  AppDataColumn(
                    label: 'License',
                    cellBuilder: (context, t) =>
                        Text(t.licenseNumber ?? '—'),
                  ),
                ],
                actionsBuilder: (context, t) {
                  if (t.rosterStatus != 'PENDING') {
                    return const SizedBox.shrink();
                  }
                  return GlossyButton(
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
                  );
                },
              ),
            ],
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
              AppDataTable<AgencyRosterMemberModel>(
                rows: list,
                showSearch: list.isNotEmpty,
                searchHint: 'Search coordinators…',
                searchPredicate: (m, q) {
                  final needle = q.toLowerCase();
                  return m.displayName.toLowerCase().contains(needle) ||
                      m.status.toLowerCase().contains(needle);
                },
                emptyMessage: 'No service coordinators on roster yet.',
                columns: [
                  AppDataColumn(
                    label: 'Name',
                    mobilePriority: true,
                    cellBuilder: (context, m) => Text(
                      m.displayName,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  AppDataColumn(
                    label: 'Status',
                    mobilePriority: true,
                    cellBuilder: (context, m) => AppStatusBadge.fromKind(
                      m.status == 'ACTIVE'
                          ? AppStatusKind.active
                          : AppStatusKind.pending,
                      label: m.status,
                    ),
                  ),
                  AppDataColumn(
                    label: 'Caseload',
                    cellBuilder: (context, m) => Text('${m.caseload}'),
                  ),
                ],
                onRowTap: (m) => context.push(
                  '${AppRoutes.agencyHome}/roster/${m.userId}',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
