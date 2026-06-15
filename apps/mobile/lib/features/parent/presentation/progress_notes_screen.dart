import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../../../shared/widgets/weekly_progress_chart.dart';
import '../../clinical/data/clinical_repository.dart';

final parentProgressNotesProvider =
    FutureProvider<List<ParentProgressNoteModel>>((ref) {
      return ref.watch(clinicalRepositoryProvider).fetchParentProgressNotes();
    });

class ProgressNotesScreen extends ConsumerStatefulWidget {
  const ProgressNotesScreen({super.key, this.sessionId});

  final String? sessionId;

  @override
  ConsumerState<ProgressNotesScreen> createState() =>
      _ProgressNotesScreenState();
}

class _ProgressNotesScreenState extends ConsumerState<ProgressNotesScreen> {
  bool _handledSessionId = false;

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
          GlossyButton(
            title: 'Save',
            size: GlossyButtonSize.small,
            fullWidth: false,
            variant: GlossyButtonVariant.greenTeal,
            onPressed: () => Navigator.pop(ctx, true),
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

  List<WeeklyProgressWeek> _weeklyReportCounts(
    List<ParentProgressNoteModel> notes,
  ) {
    final now = DateTime.now();
    DateTime startOfWeek(DateTime d) {
      final day = d.weekday;
      return DateTime(d.year, d.month, d.day - (day - 1));
    }

    final weeks = <WeeklyProgressWeek>[];
    for (var i = 5; i >= 0; i--) {
      final start = startOfWeek(now).subtract(Duration(days: i * 7));
      final end = start.add(const Duration(days: 7));
      final count = notes.where((n) {
        final signed = n.signedAt;
        if (signed == null) return false;
        return !signed.isBefore(start) && signed.isBefore(end);
      }).length;
      final label = '${_monthShort(start.month)} ${start.day}';
      weeks.add(WeeklyProgressWeek(weekLabel: label, reportCount: count));
    }
    return weeks;
  }

  String _monthShort(int month) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return names[month - 1];
  }

  void _maybeOpenSessionFeedback(List<ParentProgressNoteModel> list) {
    final sessionId = widget.sessionId;
    if (_handledSessionId || sessionId == null || sessionId.isEmpty) return;
    ParentProgressNoteModel? note;
    for (final n in list) {
      if (n.sessionId == sessionId) {
        note = n;
        break;
      }
    }
    if (note == null) return;
    final target = note;
    _handledSessionId = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _addFeedback(context, ref, target);
    });
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(parentProgressNotesProvider);
    final dateFmt = DateFormat.yMMMd();

    return AppScaffold(
      title: 'Progress notes',
      body: notes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          _maybeOpenSessionFeedback(list);
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(parentProgressNotesProvider);
              await ref.read(parentProgressNotesProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Weekly progress from your therapist',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your therapist submits a progress summary after each '
                          'session. Reports are rolled up weekly so you can see '
                          'how care is trending over time.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        WeeklyProgressChart(
                          weeks: _weeklyReportCounts(list),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (list.isEmpty)
                  const Card(
                    child: ListTile(
                      title: Text('No session summaries yet'),
                      subtitle: Text(
                        'Weekly bars will fill in after your therapist documents visits.',
                      ),
                    ),
                  )
                else
                  ...list.asMap().entries.map((entry) {
                    final index = entry.key;
                    final n = entry.value;
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index < list.length - 1 ? 12 : 0,
                      ),
                      child: _ProgressNoteCard(
                        note: n,
                        highlight: widget.sessionId == n.sessionId,
                        dateFmt: dateFmt,
                        onFeedback: () => _addFeedback(context, ref, n),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProgressNoteCard extends StatelessWidget {
  const _ProgressNoteCard({
    required this.note,
    required this.highlight,
    required this.dateFmt,
    required this.onFeedback,
  });

  final ParentProgressNoteModel note;
  final bool highlight;
  final DateFormat dateFmt;
  final VoidCallback onFeedback;

  String get _summaryPreview {
    final text = note.summary.trim();
    if (text.length <= 140) return text;
    return '${text.substring(0, 140).trimRight()}…';
  }

  @override
  Widget build(BuildContext context) {
    final longSummary = note.summary.trim().length > 140;

    return Card(
      color: highlight
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
      child: ExpansionTile(
        initiallyExpanded: highlight,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          note.childName,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('With ${note.therapistName}'),
            if (note.signedAt != null)
              Text(
                dateFmt.format(note.signedAt!),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (!longSummary) ...[
              const SizedBox(height: 6),
              Text(
                _summaryPreview,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (longSummary) ...[
                  Text(
                    'Session summary',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(note.summary),
                  const SizedBox(height: 12),
                ],
                if (note.parentFeedback != null) ...[
                  Text(
                    'Your feedback',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(note.parentFeedback!),
                  const SizedBox(height: 8),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onFeedback,
                    icon: const Icon(Icons.feedback_outlined),
                    label: Text(
                      note.parentFeedback == null
                          ? 'Leave feedback'
                          : 'Edit feedback',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
