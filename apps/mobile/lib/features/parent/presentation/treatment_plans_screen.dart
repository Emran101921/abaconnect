import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../../clinical/data/clinical_repository.dart';

final parentTreatmentPlansProvider = FutureProvider<List<TreatmentPlanModel>>((
  ref,
) {
  return ref.watch(clinicalRepositoryProvider).fetchParentPlans();
});

class TreatmentPlansScreen extends ConsumerWidget {
  const TreatmentPlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plans = ref.watch(parentTreatmentPlansProvider);

    return AppScaffold(
      title: 'Treatment Plans',
      body: plans.when(
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
                  'Could not load treatment plans',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text('$e', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                GlossyButton(
                  title: 'Retry',
                  icon: Icons.refresh_rounded,
                  variant: GlossyButtonVariant.neutral,
                  onPressed: () =>
                      ref.invalidate(parentTreatmentPlansProvider),
                ),
              ],
            ),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(parentTreatmentPlansProvider);
                await ref.read(parentTreatmentPlansProvider.future);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Icon(Icons.flag_outlined, size: 48),
                  SizedBox(height: 16),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'No active treatment plans yet.\n'
                        'Your therapist will publish goals here as care progresses.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(parentTreatmentPlansProvider);
              await ref.read(parentTreatmentPlansProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final p = list[index];
                final progressPct = (p.goalsProgress * 100).round();
                return Card(
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    title: Text(
                      p.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Chip(
                              label: Text(p.childName),
                              visualDensity: VisualDensity.compact,
                            ),
                            Chip(
                              label: Text(p.therapyType),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('Therapist: ${p.therapistName ?? '—'}'),
                        if (p.goalsTotalCount > 0) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: p.goalsProgress,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$progressPct%',
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${p.goalsDoneCount} of ${p.goalsTotalCount} goals completed',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                    children: [
                      if (p.goals.isEmpty)
                        const ListTile(title: Text('No goals listed yet'))
                      else
                        ...p.goals.map(
                          (g) => ListTile(
                            leading: Icon(
                              _goalIcon(g.status),
                              color: _goalColor(context, g.status),
                            ),
                            title: Text(g.label),
                            trailing: _GoalStatusChip(goal: g),
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

IconData _goalIcon(String? status) {
  return switch (status) {
    'done' => Icons.check_circle_outline,
    'in_progress' => Icons.trending_up,
    _ => Icons.flag_outlined,
  };
}

Color? _goalColor(BuildContext context, String? status) {
  return switch (status) {
    'done' => Colors.green,
    'in_progress' => Theme.of(context).colorScheme.primary,
    'active' => Theme.of(context).colorScheme.tertiary,
    _ => null,
  };
}

class _GoalStatusChip extends StatelessWidget {
  const _GoalStatusChip({required this.goal});

  final TreatmentPlanGoalModel goal;

  @override
  Widget build(BuildContext context) {
    final color = _goalColor(context, goal.status);
    return Chip(
      label: Text(goal.statusLabel),
      backgroundColor: color?.withValues(alpha: 0.12),
      labelStyle: TextStyle(
        color: color ?? Theme.of(context).colorScheme.onSurface,
        fontSize: 12,
      ),
    );
  }
}
