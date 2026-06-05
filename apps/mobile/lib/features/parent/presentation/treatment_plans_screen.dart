import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../clinical/data/clinical_repository.dart';

final parentTreatmentPlansProvider =
    FutureProvider<List<TreatmentPlanModel>>((ref) {
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
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Text('No active treatment plans yet.'),
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
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final p = list[index];
                return Card(
                  child: ExpansionTile(
                    title: Text(p.title),
                    subtitle: Text(
                      '${p.childName} · ${p.therapyType}\n'
                      'Therapist: ${p.therapistName ?? '—'}',
                    ),
                    children: [
                      if (p.goals.isEmpty)
                        const ListTile(title: Text('No goals listed yet'))
                      else
                        ...p.goals.map(
                          (g) => ListTile(
                            leading: Icon(
                              g.status == 'done'
                                  ? Icons.check_circle_outline
                                  : Icons.flag_outlined,
                            ),
                            title: Text(g.label),
                            subtitle: g.status != null ? Text(g.status!) : null,
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
