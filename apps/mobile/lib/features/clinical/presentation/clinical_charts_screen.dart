import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/child_medical_chart_card.dart';
import '../data/clinical_charts_repository.dart';

class ClinicalChartsScreen extends ConsumerWidget {
  const ClinicalChartsScreen({
    super.key,
    required this.audience,
    this.chartRouteBuilder,
  });

  final ClinicalChartsAudience audience;
  final String Function(String childId)? chartRouteBuilder;

  String get _title => switch (audience) {
        ClinicalChartsAudience.therapist => 'Medical charts',
        ClinicalChartsAudience.agency => 'Agency charts',
        ClinicalChartsAudience.serviceCoordinator => 'Case charts',
      };

  String get _subtitle =>
      'Each child has a separate clinical chart with demographics and visit activity.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charts = ref.watch(clinicalChartsProvider(audience));

    return AppScaffold(
      title: _title,
      subtitle: _subtitle,
      body: charts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load charts: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  switch (audience) {
                    ClinicalChartsAudience.therapist =>
                      'No children on your caseload yet.',
                    ClinicalChartsAudience.agency =>
                      'No child charts yet. Charts appear when children are on your agency caseload or assigned to service coordination.',
                    ClinicalChartsAudience.serviceCoordinator =>
                      'No assigned children yet.',
                  },
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(clinicalChartsProvider(audience));
              await ref.read(clinicalChartsProvider(audience).future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final chart = list[index];
                final route = chartRouteBuilder?.call(chart.childId);
                return ChildMedicalChartCard(
                  chart: chart,
                  onTap: route == null ? null : () => context.push(route),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
