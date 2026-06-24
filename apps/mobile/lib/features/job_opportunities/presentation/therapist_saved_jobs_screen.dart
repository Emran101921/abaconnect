import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../../../shared/widgets/role_tab_scaffold.dart';
import '../data/job_opportunities_repository.dart';
import '../widgets/job_opportunity_card.dart';

class TherapistSavedJobsScreen extends ConsumerWidget {
  const TherapistSavedJobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedJobs = ref.watch(therapistSavedJobsProvider);

    return TherapistTabScaffold(
      title: 'Saved jobs',
      subtitle: 'Opportunities you bookmarked for later',
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(therapistSavedJobsProvider),
        child: savedJobs.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 120),
              Center(child: Text('$e')),
            ],
          ),
          data: (rows) {
            if (rows.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 48),
                  Icon(
                    Icons.bookmark_border,
                    size: 48,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No saved jobs yet',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Save opportunities while browsing to review them here.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: GlossyButton(
                      label: 'Browse opportunities',
                      onPressed: () =>
                          context.push(AppRoutes.therapistJobOpportunities),
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final job = rows[index];
                return JobOpportunityCard(
                  opportunity: job,
                  onTap: () => context.push(
                    '${AppRoutes.therapistJobOpportunities}/${job.id}',
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
