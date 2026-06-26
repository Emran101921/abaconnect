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

class SessionHistoryScreen extends ConsumerStatefulWidget {
  const SessionHistoryScreen({super.key, this.sessionId});

  final String? sessionId;

  @override
  ConsumerState<SessionHistoryScreen> createState() =>
      _SessionHistoryScreenState();
}

class _SessionHistoryScreenState extends ConsumerState<SessionHistoryScreen> {
  final _expansionKeys = <String, GlobalKey>{};
  var _handledDeepLink = false;

  GlobalKey _keyFor(String sessionId) =>
      _expansionKeys.putIfAbsent(sessionId, GlobalKey.new);

  void _maybeScrollToSession(List<SessionHistoryModel> list) {
    final sessionId = widget.sessionId;
    if (_handledDeepLink || sessionId == null || sessionId.isEmpty) return;
    final exists = list.any((s) => s.id == sessionId);
    if (!exists) return;
    _handledDeepLink = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _keyFor(sessionId).currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          alignment: 0.1,
          duration: const Duration(milliseconds: 300),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(sessionHistoryProvider);
    final dateFmt = DateFormat.yMMMd().add_jm();
    final highlightSessionId = widget.sessionId;

    return AppScaffold(
      title: 'Session History',
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          _maybeScrollToSession(list);
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
                final highlight = highlightSessionId != null &&
                    highlightSessionId.isNotEmpty &&
                    s.id == highlightSessionId;
                return Card(
                  key: _keyFor(s.id),
                  color: highlight
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                  child: ExpansionTile(
                    initiallyExpanded: highlight,
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
                          child: Wrap(
                            spacing: 8,
                            children: [
                              TextButton.icon(
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
                              if (s.awaitingParentSignature)
                                FilledButton.icon(
                                  onPressed: () => context.push(
                                    AppRoutes.parentSessionSign(s.id),
                                  ),
                                  icon: const Icon(Icons.draw_outlined),
                                  label: const Text('Sign session note'),
                                ),
                              if (s.hasServiceLog)
                                TextButton.icon(
                                  onPressed: () async {
                                    try {
                                      final path = await ref
                                          .read(
                                            parentBookingRepositoryProvider,
                                          )
                                          .downloadServiceLogPdf(s.id);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text('Saved to $path'),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text('Download failed: $e'),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.picture_as_pdf_outlined),
                                  label: const Text('Service log PDF'),
                                ),
                            ],
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
