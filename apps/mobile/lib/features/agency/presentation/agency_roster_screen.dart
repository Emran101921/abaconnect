import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/glossy_button.dart';
import 'agency_providers.dart';

class AgencyRosterScreen extends ConsumerWidget {
  const AgencyRosterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final therapists = ref.watch(agencyTherapistsProvider);

    return AppScaffold(
      title: 'Therapist roster',
      actions: [
        IconButton(
          icon: const Icon(Icons.storefront_outlined),
          tooltip: 'Browse marketplace',
          onPressed: () => context.push(AppRoutes.agencyMarketplace),
        ),
      ],
      body: therapists.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Could not load roster',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  AppSnackBar.messageFromError(e),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                GlossyButton(
                  title: 'Retry',
                  icon: Icons.refresh_rounded,
                  variant: GlossyButtonVariant.neutral,
                  onPressed: () => ref.invalidate(agencyTherapistsProvider),
                ),
              ],
            ),
          ),
        ),
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
              itemCount: list.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Card(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    child: ListTile(
                      leading: const Icon(Icons.storefront_outlined),
                      title: const Text('Agency marketplace'),
                      subtitle: const Text(
                        'Browse anonymous parent requests your roster can serve',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(AppRoutes.agencyMarketplace),
                    ),
                  );
                }
                final t = list[index - 1];
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
                              GlossyButton(
                                title: 'Remove',
                                size: GlossyButtonSize.small,
                                fullWidth: false,
                                variant: GlossyButtonVariant.redDarkRed,
                                onPressed: () => Navigator.pop(ctx, true),
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
