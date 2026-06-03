import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../clinical/data/clinical_repository.dart';
import '../data/therapist_repository.dart';
final therapistPlansProvider =
    FutureProvider<List<TreatmentPlanModel>>((ref) {
  return ref.watch(clinicalRepositoryProvider).fetchTherapistPlans();
});

class TherapistPlansScreen extends ConsumerWidget {
  const TherapistPlansScreen({super.key});

  Future<void> _createPlan(BuildContext context, WidgetRef ref) async {
    final appointments =
        await ref.read(therapistRepositoryProvider).fetchAppointments();
    if (appointments.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No appointments with children')),
        );
      }
      return;
    }
    final a = appointments.first;
    final title = TextEditingController(text: 'Treatment plan — ${a.childName}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New treatment plan'),
        content: TextField(
          controller: title,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(clinicalRepositoryProvider).createPlan(
            childId: a.childId,
            therapyType: a.therapyType,
            title: title.text.trim(),
          );
      ref.invalidate(therapistPlansProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plan created')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'),
        );
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
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final p = list[index];
              return Card(
                child: ListTile(
                  title: Text(p.title),
                  subtitle: Text('${p.childName} · ${p.therapyType}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
