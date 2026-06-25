import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_data_table.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../data/job_opportunities_repository.dart';
import '../widgets/application_status_badge.dart';

class AgencyApplicantsScreen extends ConsumerWidget {
  const AgencyApplicantsScreen({super.key, required this.jobOpportunityId});

  final String jobOpportunityId;

  Future<void> _updateStatus(
    WidgetRef ref,
    BuildContext context,
    String applicationId,
    String status,
  ) async {
    try {
      await ref.read(jobOpportunitiesRepositoryProvider).updateApplicationStatus(
            applicationId: applicationId,
            status: status,
          );
      ref.invalidate(agencyJobApplicationsProvider(jobOpportunityId));
      if (context.mounted) {
        AppSnackBar.showSuccess(context, 'Status updated');
      }
    } catch (e) {
      if (context.mounted) AppSnackBar.showError(context, e);
    }
  }

  Future<void> _hireAndRoster(
    WidgetRef ref,
    BuildContext context,
    String applicationId,
  ) async {
    try {
      await ref
          .read(jobOpportunitiesRepositoryProvider)
          .markHiredAndAddToRoster(applicationId);
      ref.invalidate(agencyJobApplicationsProvider(jobOpportunityId));
      if (context.mounted) {
        AppSnackBar.showSuccess(context, 'Therapist hired and added to roster');
      }
    } catch (e) {
      if (context.mounted) AppSnackBar.showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applications =
        ref.watch(agencyJobApplicationsProvider(jobOpportunityId));

    return AppScaffold(
      title: 'Applicants',
      subtitle: 'Review therapist applications',
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.invalidate(agencyJobApplicationsProvider(jobOpportunityId)),
        child: applications.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (rows) {
            if (rows.isEmpty) {
              return const Center(child: Text('No applications yet.'));
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AppDataTable<JobApplicationModel>(
                  rows: rows,
                  searchHint: 'Search applicants…',
                  searchPredicate: (app, q) {
                    final needle = q.toLowerCase();
                    return app.therapistName.toLowerCase().contains(needle) ||
                        app.status.toLowerCase().contains(needle) ||
                        (app.therapistEmail ?? '')
                            .toLowerCase()
                            .contains(needle) ||
                        (app.message ?? '').toLowerCase().contains(needle);
                  },
                  columns: [
                    AppDataColumn(
                      label: 'Therapist',
                      mobilePriority: true,
                      cellBuilder: (context, app) => Text(app.therapistName),
                    ),
                    AppDataColumn(
                      label: 'Status',
                      mobilePriority: true,
                      cellBuilder: (context, app) =>
                          ApplicationStatusBadge(status: app.status),
                    ),
                    AppDataColumn(
                      label: 'Applied',
                      cellBuilder: (context, app) => Text(
                        app.createdAt.toLocal().toString().split('.').first,
                      ),
                    ),
                  ],
                  actionsBuilder: (context, app) {
                    return Wrap(
                      spacing: 8,
                      children: [
                        if (app.status == 'NEW_APPLICANT')
                          TextButton(
                            onPressed: () => _updateStatus(
                              ref,
                              context,
                              app.id,
                              'UNDER_REVIEW',
                            ),
                            child: const Text('Review'),
                          ),
                        if (app.status == 'UNDER_REVIEW')
                          TextButton(
                            onPressed: () => _updateStatus(
                              ref,
                              context,
                              app.id,
                              'INTERVIEW_REQUESTED',
                            ),
                            child: const Text('Interview'),
                          ),
                        if (app.status == 'OFFER_SENT' ||
                            app.status == 'APPROVED')
                          GlossyButton(
                            label: 'Hire + roster',
                            size: GlossyButtonSize.small,
                            onPressed: () =>
                                _hireAndRoster(ref, context, app.id),
                          ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
