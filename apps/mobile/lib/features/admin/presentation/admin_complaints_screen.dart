import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/glossy_button.dart';
import 'admin_providers.dart';

class AdminComplaintsScreen extends ConsumerWidget {
  const AdminComplaintsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final complaints = ref.watch(adminComplaintsProvider);

    return AppScaffold(
      title: 'Complaints',
      body: complaints.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No open complaints'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(adminComplaintsProvider);
              ref.invalidate(adminDashboardProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final c = list[index];
                return Card(
                  child: ListTile(
                    title: Text(c.subject),
                    subtitle: Text(
                      '${c.status} · ${c.category}\n'
                      '${c.reporterName ?? 'Unknown'}\n${c.description}',
                    ),
                    isThreeLine: true,
                    trailing: GlossyButton(
                      title: 'Resolve',
                      size: GlossyButtonSize.small,
                      fullWidth: false,
                      variant: GlossyButtonVariant.greenTeal,
                      onPressed: () async {
                        final resolution = await showDialog<String>(
                          context: context,
                          builder: (ctx) {
                            final ctrl = TextEditingController(
                              text: 'Resolved by admin',
                            );
                            return AlertDialog(
                              title: const Text('Resolve complaint'),
                              content: TextField(
                                controller: ctrl,
                                decoration: const InputDecoration(
                                  labelText: 'Resolution notes',
                                ),
                                maxLines: 3,
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Cancel'),
                                ),
                                GlossyButton(
                                  title: 'Resolve',
                                  size: GlossyButtonSize.small,
                                  fullWidth: false,
                                  variant: GlossyButtonVariant.greenTeal,
                                  onPressed: () =>
                                      Navigator.pop(ctx, ctrl.text.trim()),
                                ),
                              ],
                            );
                          },
                        );
                        if (resolution == null || resolution.isEmpty) return;
                        try {
                          await ref
                              .read(adminRepositoryProvider)
                              .resolveComplaint(c.id, resolution);
                          ref.invalidate(adminComplaintsProvider);
                          ref.invalidate(adminDashboardProvider);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Complaint resolved'),
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
