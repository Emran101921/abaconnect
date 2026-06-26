import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../agency/data/agency_repository.dart';
import '../../agency/presentation/agency_providers.dart';

Future<AgencyTherapistModel?> showInviteTherapistSheet(
  BuildContext context,
  WidgetRef ref, {
  required String title,
}) {
  return showModalBottomSheet<AgencyTherapistModel>(
    context: context,
    showDragHandle: true,
    builder: (context) => _InviteTherapistSheet(title: title),
  );
}

class _InviteTherapistSheet extends ConsumerWidget {
  const _InviteTherapistSheet({required this.title});

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roster = ref.watch(agencyTherapistsProvider);
    final candidates = ref.watch(agencyInviteCandidatesProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Roster therapists and verified providers in your tenant',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Flexible(
              child: roster.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('$e'),
                data: (rosterRows) {
                  return candidates.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (e, _) => Text('$e'),
                    data: (candidateRows) {
                      final seen = <String>{};
                      final merged = <AgencyTherapistModel>[];
                      for (final row in [...rosterRows, ...candidateRows]) {
                        if (seen.add(row.id)) merged.add(row);
                      }
                      if (merged.isEmpty) {
                        return const Text(
                          'No therapists available to invite yet.',
                        );
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: merged.length,
                        itemBuilder: (context, index) {
                          final therapist = merged[index];
                          final onRoster = rosterRows.any(
                            (row) => row.id == therapist.id,
                          );
                          return ListTile(
                            title: Text(therapist.displayName),
                            subtitle: Text(
                              [
                                if (onRoster) 'On roster',
                                if (!onRoster) 'Verified in tenant',
                                therapist.email ?? therapist.licenseNumber,
                              ].whereType<String>().join(' · '),
                            ),
                            onTap: () => Navigator.pop(context, therapist),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
