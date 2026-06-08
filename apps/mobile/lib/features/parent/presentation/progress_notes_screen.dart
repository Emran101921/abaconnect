import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../clinical/data/clinical_repository.dart';

final parentProgressNotesProvider =
    FutureProvider<List<ParentProgressNoteModel>>((ref) {
      return ref.watch(clinicalRepositoryProvider).fetchParentProgressNotes();
    });

class ProgressNotesScreen extends ConsumerWidget {
  const ProgressNotesScreen({super.key});

  Future<void> _addFeedback(
    BuildContext context,
    WidgetRef ref,
    ParentProgressNoteModel note,
  ) async {
    final controller = TextEditingController(text: note.parentFeedback ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Session feedback'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'How did the session go at home?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(clinicalRepositoryProvider)
          .submitSessionFeedback(
            sessionId: note.sessionId,
            feedback: controller.text.trim(),
          );
      ref.invalidate(parentProgressNotesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Feedback saved')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(parentProgressNotesProvider);
    final dateFmt = DateFormat.yMMMd();

    return AppScaffold(
      title: 'Progress notes',
      body: notes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Text(
                'No progress summaries yet. They appear after sessions.',
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(parentProgressNotesProvider);
              await ref.read(parentProgressNotesProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final n = list[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          n.childName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text('With ${n.therapistName}'),
                        if (n.signedAt != null)
                          Text(
                            dateFmt.format(n.signedAt!),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        const SizedBox(height: 8),
                        Text(n.summary),
                        if (n.parentFeedback != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Your feedback',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          Text(n.parentFeedback!),
                        ],
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => _addFeedback(context, ref, n),
                          icon: const Icon(Icons.feedback_outlined),
                          label: Text(
                            n.parentFeedback == null
                                ? 'Leave feedback'
                                : 'Edit feedback',
                          ),
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
