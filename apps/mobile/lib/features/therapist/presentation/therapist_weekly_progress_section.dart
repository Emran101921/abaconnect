import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/widgets/weekly_progress_chart.dart';
import '../../clinical/data/clinical_repository.dart';
import '../../../core/providers/app_providers.dart';

final therapistWeeklyProgressProvider =
    FutureProvider<TherapistWeeklyProgressModel>((ref) {
      return ref
          .watch(clinicalRepositoryProvider)
          .fetchTherapistWeeklyProgress();
    });

class TherapistWeeklyProgressSection extends ConsumerWidget {
  const TherapistWeeklyProgressSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(therapistWeeklyProgressProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: progress.when(
        loading: () => const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: LinearProgressIndicator(),
          ),
        ),
        error: (e, _) => Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Weekly progress unavailable: $e'),
          ),
        ),
        data: (data) => Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.insights_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Weekly child progress',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Each week, document session outcomes in SOAP notes and '
                  'progress summaries. Parents see these updates in their '
                  'portal, and goal completion trends appear in the chart below.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  'Progress reports per week',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                WeeklyProgressChart(
                  weeks: data.weeks
                      .map(
                        (w) => WeeklyProgressWeek(
                          weekLabel: w.weekLabel,
                          reportCount: w.reportCount,
                        ),
                      )
                      .toList(),
                ),
                if (data.children.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Goal completion by child',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  ChildGoalProgressList(
                    children: data.children
                        .map(
                          (c) => ChildProgressSummary(
                            childId: c.childId,
                            childName: c.childName,
                            goalCompletionPercent: c.goalCompletionPercent,
                            activePlanTitle: c.activePlanTitle,
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () =>
                        context.push('${AppRoutes.therapistHome}/session-notes'),
                    icon: const Icon(Icons.edit_note_outlined),
                    label: const Text('Add progress report'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
