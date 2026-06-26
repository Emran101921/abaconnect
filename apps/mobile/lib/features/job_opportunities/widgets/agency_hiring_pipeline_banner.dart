import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../data/job_opportunities_repository.dart';

/// Surfaces pending hiring actions on the agency dashboard.
class AgencyHiringPipelineBanner extends ConsumerWidget {
  const AgencyHiringPipelineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(agencyHiringPipelineSummaryProvider);

    return summary.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (pipeline) {
        if (pipeline.totalPendingActions <= 0) return const SizedBox.shrink();

        final parts = <String>[];
        if (pipeline.newApplicants > 0) {
          parts.add('${pipeline.newApplicants} new applicant(s)');
        }
        if (pipeline.credentialsSubmitted > 0) {
          parts.add('${pipeline.credentialsSubmitted} credential review');
        }
        if (pipeline.offersPending > 0) {
          parts.add('${pipeline.offersPending} offer(s) pending');
        }
        if (pipeline.readyToHire > 0) {
          parts.add('${pipeline.readyToHire} ready to hire');
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Card(
            color: Theme.of(context)
                .colorScheme
                .primaryContainer
                .withValues(alpha: 0.35),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                child: Text('${pipeline.totalPendingActions}'),
              ),
              title: const Text('Hiring pipeline needs attention'),
              subtitle: Text(parts.join(' · ')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.agencyOpportunities),
            ),
          ),
        );
      },
    );
  }
}
