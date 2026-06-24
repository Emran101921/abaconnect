import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../data/job_opportunities_repository.dart';
import '../widgets/job_opportunity_card.dart';
import '../widgets/phi_warning_banner.dart';

class AgencyOpportunitiesScreen extends ConsumerWidget {
  const AgencyOpportunitiesScreen({super.key});

  Future<void> _publish(
    BuildContext context,
    WidgetRef ref,
    String jobId,
  ) async {
    try {
      await ref
          .read(jobOpportunitiesRepositoryProvider)
          .publishJobOpportunity(jobId);
      ref.invalidate(agencyJobOpportunitiesProvider);
      if (context.mounted) {
        AppSnackBar.showSuccess(context, 'Job opportunity published');
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opportunities = ref.watch(agencyJobOpportunitiesProvider);

    return AppScaffold(
      title: 'Opportunities',
      subtitle: 'Public staffing posts (PHI-scanned before publish)',
      actions: [
        IconButton(
          tooltip: 'Service needs',
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => context.push(AppRoutes.agencyServiceNeeds),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(agencyJobOpportunitiesProvider),
        child: opportunities.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (rows) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const PhiWarningBanner(),
              const SizedBox(height: 16),
              if (rows.isEmpty)
                const Text('No job opportunities yet. Create one from a service need.')
              else
                ...rows.map(
                  (job) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: JobOpportunityCard(
                      opportunity: job,
                      onTap: () => context.push(
                        job.status == 'DRAFT' ||
                                job.status == 'PAUSED' ||
                                job.status == 'BLOCKED'
                            ? AppRoutes.agencyOpportunityDetail(job.id)
                            : '${AppRoutes.agencyOpportunities}/${job.id}/applicants',
                      ),
                      trailing: job.status == 'DRAFT' || job.status == 'PAUSED'
                          ? GlossyButton(
                              label: 'Publish',
                              onPressed: () => _publish(context, ref, job.id),
                              size: GlossyButtonSize.small,
                            )
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
