import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../data/parent_booking_repository.dart';

final sessionHistoryProvider = FutureProvider<List<SessionHistoryModel>>((ref) {
  return ref.watch(parentBookingRepositoryProvider).fetchSessionHistory();
});

class SessionHistoryScreen extends ConsumerWidget {
  const SessionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(sessionHistoryProvider);
    final dateFmt = DateFormat.yMMMd().add_jm();

    return AppScaffold(
      title: 'Session History',
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No completed sessions yet'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(sessionHistoryProvider);
              await ref.read(sessionHistoryProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final s = list[index];
                return Card(
                  child: ExpansionTile(
                    leading: Icon(
                      s.hasProgressNote
                          ? Icons.summarize_outlined
                          : Icons.event_note_outlined,
                      color: s.hasProgressNote
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    title: Text('${s.therapyType} · ${s.childName}'),
                    subtitle: Text(
                      '${s.therapistName}\n'
                      '${s.completedAt != null ? dateFmt.format(s.completedAt!) : 'In progress'}'
                      '${s.durationMinutes != null ? ' · ${s.durationMinutes} min' : ''}',
                    ),
                    trailing: _StatusChip(
                      status: s.status,
                      label: s.statusLabel,
                    ),
                    children: [
                      if (s.hasProgressNote &&
                          s.progressNoteSummary != null) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Visit summary',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(s.progressNoteSummary!),
                            ],
                          ),
                        ),
                        if (s.parentFeedback != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Your feedback',
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                                const SizedBox(height: 4),
                                Text(s.parentFeedback!),
                              ],
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(left: 8, bottom: 8),
                          child: TextButton.icon(
                            onPressed: () => context.push(
                              '${AppRoutes.parentHome}/progress-notes'
                              '?sessionId=${s.id}',
                            ),
                            icon: const Icon(Icons.feedback_outlined),
                            label: Text(
                              s.parentFeedback == null
                                  ? 'Leave feedback'
                                  : 'Edit feedback',
                            ),
                          ),
                        ),
                      ] else
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Text(
                            'Visit summary will appear once your therapist signs the progress note.',
                          ),
                        ),
                    ],
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.label});

  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'COMPLETED' => Colors.green,
      'IN_PROGRESS' => Colors.orange,
      'PENDING_DOCUMENTATION' => Colors.blueGrey,
      _ => null,
    };
    return Chip(
      label: Text(label),
      backgroundColor: color?.withValues(alpha: 0.12),
      labelStyle: TextStyle(
        color: color ?? Theme.of(context).colorScheme.onSurface,
        fontSize: 12,
      ),
    );
  }
}
