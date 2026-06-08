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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createPlan(context, ref),
        child: const Icon(Icons.add),
      ),
      body: plans.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No plans yet. Tap + to create.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final p = list[index];
              return Card(
                child: ExpansionTile(
                  title: Text(p.title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${p.childName} · ${p.therapyType}'),
                      if (p.goalsTotalCount > 0) ...[
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: p.goalsProgress,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        Text(
                          '${p.goalsDoneCount}/${p.goalsTotalCount} done',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editGoals(context, ref, p),
                  ),
                  children: [
                    if (p.goals.isEmpty)
                      const ListTile(title: Text('No goals yet'))
                    else
                      ...p.goals.map(
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
            },
          );
        },
      ),
    );
  }
}
