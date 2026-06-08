import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../clinical/data/clinical_repository.dart';

final therapistPlansProvider = FutureProvider<List<TreatmentPlanModel>>((ref) {
  return ref.watch(clinicalRepositoryProvider).fetchTherapistPlans();
});

class TherapistPlansScreen extends ConsumerWidget {
  const TherapistPlansScreen({super.key});

  Future<void> _createPlan(BuildContext context, WidgetRef ref) async {
    final appointments = await ref
        .read(therapistRepositoryProvider)
        .fetchAppointments();
    if (appointments.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No appointments with children')),
        );
      }
      return;
    }
    final a = appointments.first;
    if (!context.mounted) return;
    final title = TextEditingController(
      text: 'Treatment plan — ${a.childName}',
    );
    final goalLabel = TextEditingController();
    final goals = <TreatmentPlanGoalModel>[];

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('New treatment plan'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: goalLabel,
                  decoration: const InputDecoration(labelText: 'Add goal'),
                ),
                TextButton(
                  onPressed: () {
                    final label = goalLabel.text.trim();
                    if (label.isEmpty) return;
                    setState(() {
                      goals.add(
                        TreatmentPlanGoalModel(
                          id: 'g${goals.length + 1}',
                          label: label,
                          status: 'active',
                        ),
                      );
                      goalLabel.clear();
                    });
                  },
                  child: const Text('Add goal'),
                ),
                ...goals.map(
                  (g) => ListTile(dense: true, title: Text(g.label)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(clinicalRepositoryProvider)
          .createPlan(
            childId: a.childId,
            therapyType: a.therapyType,
            title: title.text.trim(),
            goals: goals,
          );
      ref.invalidate(therapistPlansProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Plan created')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _editGoals(
    BuildContext context,
    WidgetRef ref,
    TreatmentPlanModel plan,
  ) async {
    final goals = [...plan.goals];
    final goalLabel = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Goals — ${plan.title}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: goalLabel,
                  decoration: const InputDecoration(labelText: 'New goal'),
                ),
                TextButton(
                  onPressed: () {
                    final label = goalLabel.text.trim();
                    if (label.isEmpty) return;
                    setState(() {
                      goals.add(
                        TreatmentPlanGoalModel(
                          id: 'g${DateTime.now().millisecondsSinceEpoch}',
                          label: label,
                          status: 'active',
                        ),
                      );
                      goalLabel.clear();
                    });
                  },
                  child: const Text('Add'),
                ),
                ...goals.asMap().entries.map(
                  (e) => ListTile(
                    dense: true,
                    title: Text(e.value.label),
                    subtitle: Text(e.value.statusLabel),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.swap_horiz),
                          tooltip: 'Cycle status',
                          onPressed: () => setState(() {
                            goals[e.key] = e.value.cycleStatus();
                          }),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () =>
                              setState(() => goals.removeAt(e.key)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(clinicalRepositoryProvider)
          .updatePlan(planId: plan.id, goals: goals);
      ref.invalidate(therapistPlansProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Goals updated')));
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
    final plans = ref.watch(therapistPlansProvider);

    return AppScaffold(
      title: 'Treatment Plans',
      body: plans.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Update treatment goals each week when you report session '
                    'progress. Goal completion feeds the weekly progress chart '
                    'on your dashboard and the parent progress view.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (list.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No plans yet. Tap + to create.'),
                  ),
                )
              else
                ...list.asMap().entries.map((entry) {
                  final index = entry.key;
                  final p = entry.value;
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index < list.length - 1 ? 8 : 0,
                    ),
                    child: _PlanCard(
                      plan: p,
                      onEditGoals: () => _editGoals(context, ref, p),
                    ),
                  );
                }),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createPlan(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.onEditGoals});

  final TreatmentPlanModel plan;
  final VoidCallback onEditGoals;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: Text(plan.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${plan.childName} · ${plan.therapyType}'),
            if (plan.goalsTotalCount > 0) ...[
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: plan.goalsProgress,
                borderRadius: BorderRadius.circular(4),
              ),
              Text(
                '${plan.goalsDoneCount}/${plan.goalsTotalCount} done',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: onEditGoals,
        ),
        children: [
          if (plan.goals.isEmpty)
            const ListTile(title: Text('No goals yet'))
          else
            ...plan.goals.map(
              (g) => ListTile(
                leading: Icon(
                  g.status == 'done'
                      ? Icons.check_circle_outline
                      : Icons.flag_outlined,
                ),
                title: Text(g.label),
                trailing: Chip(label: Text(g.statusLabel)),
              ),
            ),
        ],
      ),
    );
  }
}
