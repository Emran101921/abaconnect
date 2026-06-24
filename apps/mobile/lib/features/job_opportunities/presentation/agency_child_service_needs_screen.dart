import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../../service_coordinator/data/service_coordinator_repository.dart';
import '../../service_coordinator/presentation/sc_providers.dart';
import '../../../shared/models/child_medical_chart_model.dart';
import '../../clinical/data/clinical_charts_repository.dart';
import '../data/job_opportunities_repository.dart';
import '../widgets/phi_warning_banner.dart';

class AgencyChildServiceNeedsScreen extends ConsumerStatefulWidget {
  const AgencyChildServiceNeedsScreen({super.key});

  @override
  ConsumerState<AgencyChildServiceNeedsScreen> createState() =>
      _AgencyChildServiceNeedsScreenState();
}

class _AgencyChildServiceNeedsScreenState
    extends ConsumerState<AgencyChildServiceNeedsScreen> {
  final _notesController = TextEditingController();
  String _serviceType = 'OT';
  String? _selectedChildId;
  String? _generatingNeedId;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _createNeed() async {
    if (_selectedChildId == null) {
      AppSnackBar.showError(context, 'Select a child from caseload');
      return;
    }
    try {
      await ref.read(jobOpportunitiesRepositoryProvider).createChildServiceNeed(
            childId: _selectedChildId!,
            serviceType: _serviceType,
            internalNotes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          );
      ref.invalidate(agencyChildServiceNeedsProvider);
      if (mounted) AppSnackBar.showSuccess(context, 'Service need created');
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, e);
    }
  }

  Future<void> _generatePosting(String needId) async {
    setState(() => _generatingNeedId = needId);
    try {
      final job = await ref
          .read(jobOpportunitiesRepositoryProvider)
          .generateJobOpportunity(needId);
      ref.invalidate(agencyChildServiceNeedsProvider);
      ref.invalidate(agencyJobOpportunitiesProvider);
      if (mounted) {
        AppSnackBar.showSuccess(context, 'Draft posting created');
        context.push(AppRoutes.agencyOpportunityDetail(job.id));
      }
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, e);
    } finally {
      if (mounted) setState(() => _generatingNeedId = null);
    }
  }

  Map<String, String> _caseloadChildren(
    List<AgencyCaseModel> cases,
    List<ChildMedicalChartModel> charts,
  ) {
    final children = <String, String>{};
    for (final row in cases) {
      children[row.childId] = row.childName;
    }
    for (final chart in charts) {
      children[chart.childId] = chart.displayName;
    }
    return children;
  }

  @override
  Widget build(BuildContext context) {
    final needs = ref.watch(agencyChildServiceNeedsProvider);
    final cases = ref.watch(agencyCasesProvider);
    final charts = ref.watch(
      clinicalChartsProvider(ClinicalChartsAudience.agency),
    );

    final caseloadChildren = cases.maybeWhen(
      data: (rows) => charts.maybeWhen(
        data: (chartRows) => _caseloadChildren(rows, chartRows),
        orElse: () => _caseloadChildren(rows, const []),
      ),
      orElse: () => charts.maybeWhen(
        data: (chartRows) => {
          for (final chart in chartRows) chart.childId: chart.displayName,
        },
        orElse: () => const <String, String>{},
      ),
    );

    return AppScaffold(
      title: 'Child Service Needs',
      subtitle: 'Internal PHI — agency caseload only',
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(agencyChildServiceNeedsProvider);
          ref.invalidate(agencyCasesProvider);
          ref.invalidate(clinicalChartsProvider(ClinicalChartsAudience.agency));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const PhiWarningBanner(),
            const SizedBox(height: 16),
            if (caseloadChildren.isEmpty)
              const Text('Add a child to your agency caseload before creating a service need.')
            else
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Caseload child'),
                value: _selectedChildId,
                items: caseloadChildren.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedChildId = v),
              ),
            if (cases.isLoading || charts.isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              ),
            if (cases.hasError)
              Text('Could not load cases: ${cases.error}'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _serviceType,
              decoration: const InputDecoration(labelText: 'Service type'),
              items: const [
                'ABA',
                'OT',
                'PT',
                'SPEECH',
                'SPECIAL_INSTRUCTION',
                'SOCIAL_WORK',
                'PSYCHOLOGY',
                'NURSING',
                'EVALUATION',
                'SERVICE_COORDINATION',
                'OTHER',
              ]
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _serviceType = v ?? 'OT'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Internal notes (PHI — never published)',
              ),
            ),
            const SizedBox(height: 12),
            GlossyButton(label: 'Create service need', onPressed: _createNeed),
            const SizedBox(height: 24),
            Text('Existing needs', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            needs.when(
              data: (rows) => rows.isEmpty
                  ? const Text('No service needs yet.')
                  : Column(
                      children: rows
                          .map(
                            (need) => Card(
                              child: ListTile(
                                title: Text(
                                  '${need.serviceType} · ${need.childDisplayName}',
                                ),
                                subtitle: Text(need.status),
                                trailing: need.jobOpportunityId == null
                                    ? TextButton(
                                        onPressed: _generatingNeedId == need.id
                                            ? null
                                            : () => _generatePosting(need.id),
                                        child: _generatingNeedId == need.id
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Text('Create posting'),
                                      )
                                    : TextButton(
                                        onPressed: () => context.push(
                                          AppRoutes.agencyOpportunityDetail(
                                            need.jobOpportunityId!,
                                          ),
                                        ),
                                        child: Text(
                                          need.jobOpportunityStatus ?? 'View',
                                        ),
                                      ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('$e'),
            ),
          ],
        ),
      ),
    );
  }
}
