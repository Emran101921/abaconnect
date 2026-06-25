import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_data_table.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/app_status_badge.dart';
import '../data/admin_repository.dart';
import 'admin_providers.dart';

class AdminUsersScreen extends ConsumerWidget {
  const AdminUsersScreen({super.key, this.initialSearchQuery});

  final String? initialSearchQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(adminUsersProvider);

    return AppScaffold(
      title: 'Users',
      subtitle: 'Platform accounts by role',
      showPageBreadcrumbs: true,
      body: users.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            AppSkeleton(height: 44),
            SizedBox(height: 12),
            AppSkeletonCard(lines: 4),
            AppSkeletonCard(lines: 4),
          ],
        ),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(adminUsersProvider);
              await ref.read(adminUsersProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AppDataTable<AdminUserModel>(
                  rows: list,
                  searchHint: 'Search users…',
                  initialSearchQuery: initialSearchQuery,
                  searchPredicate: (u, q) {
                    final needle = q.toLowerCase();
                    return u.fullName.toLowerCase().contains(needle) ||
                        u.email.toLowerCase().contains(needle) ||
                        u.role.toLowerCase().contains(needle);
                  },
                  columns: [
                    AppDataColumn(
                      label: 'Name',
                      mobilePriority: true,
                      cellBuilder: (context, u) => Text(
                        u.fullName,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    AppDataColumn(
                      label: 'Email',
                      mobilePriority: true,
                      cellBuilder: (context, u) => Text(u.email),
                    ),
                    AppDataColumn(
                      label: 'Role',
                      cellBuilder: (context, u) => Text(u.role),
                    ),
                    AppDataColumn(
                      label: 'Status',
                      cellBuilder: (context, u) => AppStatusBadge.fromKind(
                        u.isActive
                            ? AppStatusKind.active
                            : AppStatusKind.cancelled,
                        label: u.isActive ? 'Active' : 'Inactive',
                      ),
                    ),
                  ],
                  actionsBuilder: (context, u) {
                    if (u.role == 'PLATFORM_ADMIN') {
                      return const Icon(Icons.shield, color: Colors.blue);
                    }
                    return Switch(
                      value: u.isActive,
                      onChanged: (active) async {
                        try {
                          await ref
                              .read(adminRepositoryProvider)
                              .setUserActive(
                                userId: u.id,
                                isActive: active,
                              );
                          ref.invalidate(adminUsersProvider);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  active
                                      ? 'User activated'
                                      : 'User deactivated',
                                ),
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
                    );
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
