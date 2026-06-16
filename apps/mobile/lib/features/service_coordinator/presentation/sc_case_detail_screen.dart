import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/glossy_button.dart';
import 'sc_providers.dart';

class ScCaseDetailScreen extends ConsumerWidget {
  const ScCaseDetailScreen({super.key, required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caseDetail = ref.watch(scCaseDetailProvider(childId));

    return AppScaffold(
      title: 'Case profile',
      body: caseDetail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(AppSnackBar.messageFromError(e))),
        data: (detail) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail.childName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text('Parent: ${detail.parentName}'),
                      if (detail.parentEmail != null)
                        Text('Email: ${detail.parentEmail}'),
                      if (detail.parentPhone != null)
                        Text('Phone: ${detail.parentPhone}'),
                      if (detail.guardianPhone != null)
                        Text('Guardian: ${detail.guardianPhone}'),
                      Text(
                        'DOB: ${DateFormat.yMMMd().format(detail.dateOfBirth)}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Actions', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              GlossyButton(
                title: 'Initial EI screening',
                icon: Icons.assignment_outlined,
                onPressed: () => context.push(
                  '${AppRoutes.serviceCoordinatorHome}/cases/$childId/initial-screening',
                ),
              ),
              const SizedBox(height: 8),
              GlossyButton(
                title: 'Ongoing follow-up',
                icon: Icons.update_outlined,
                variant: GlossyButtonVariant.secondary,
                onPressed: () => context.push(
                  '${AppRoutes.serviceCoordinatorHome}/cases/$childId/ongoing-screening',
                ),
              ),
              const SizedBox(height: 8),
              GlossyButton(
                title: 'Service coordination notes',
                icon: Icons.note_alt_outlined,
                variant: GlossyButtonVariant.neutral,
                onPressed: () => context.push(
                  '${AppRoutes.serviceCoordinatorHome}/cases/$childId/notes',
                ),
              ),
              const SizedBox(height: 8),
              GlossyButton(
                title: 'Flag urgent case',
                icon: Icons.flag_outlined,
                variant: GlossyButtonVariant.danger,
                onPressed: () async {
                  try {
                    await ref
                        .read(serviceCoordinatorRepositoryProvider)
                        .flagUrgent(childId, true);
                    ref.invalidate(scCaseDetailProvider(childId));
                    ref.invalidate(scDashboardProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Case flagged urgent')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      AppSnackBar.showError(context, e);
                    }
                  }
                },
              ),
              if (detail.notes.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Recent notes', style: Theme.of(context).textTheme.titleMedium),
                ...detail.notes.take(5).map(
                  (n) => ListTile(
                    title: Text(n['noteType'] as String? ?? 'Note'),
                    subtitle: Text(n['noteText'] as String? ?? ''),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
