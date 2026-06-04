import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import 'admin_providers.dart';

class AdminVerificationsScreen extends ConsumerWidget {
  const AdminVerificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingTherapistsProvider);

    return AppScaffold(
      title: 'Verify therapists',
      body: pending.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No pending verifications'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(pendingTherapistsProvider);
              ref.invalidate(adminDashboardProvider);
              await ref.read(pendingTherapistsProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final t = list[index];
                return Card(
                  child: ListTile(
                    title: Text(t.displayName),
                    subtitle: Text(
                      '${t.email}\n'
                      'License: ${t.licenseNumber ?? '—'} (${t.licenseState ?? '—'})',
                    ),
                    isThreeLine: true,
                    trailing: FilledButton(
                      onPressed: () async {
                        try {
                          await ref
                              .read(adminRepositoryProvider)
                              .verifyTherapist(t.id);
                          ref.invalidate(pendingTherapistsProvider);
                          ref.invalidate(adminDashboardProvider);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Verified ${t.displayName}')),
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
                      child: const Text('Verify'),
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
