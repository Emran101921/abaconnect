import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import 'admin_providers.dart';

class AdminUsersScreen extends ConsumerWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(adminUsersProvider);

    return AppScaffold(
      title: 'Users',
      body: users.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No users'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(adminUsersProvider);
              await ref.read(adminUsersProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final u = list[index];
                final isAdmin = u.role == 'PLATFORM_ADMIN';
                return Card(
                  child: ListTile(
                    title: Text(u.fullName),
                    subtitle: Text(
                      '${u.email}\nRole: ${u.role} · '
                      '${u.isActive ? 'Active' : 'Inactive'}',
                    ),
                    isThreeLine: true,
                    trailing: isAdmin
                        ? const Icon(Icons.shield, color: Colors.blue)
                        : Switch(
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
