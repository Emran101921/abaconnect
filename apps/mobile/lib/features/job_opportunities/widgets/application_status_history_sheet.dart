import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/job_opportunities_repository.dart';
import 'application_status_badge.dart';

Future<void> showApplicationStatusHistorySheet(
  BuildContext context, {
  required String title,
  required List<JobApplicationStatusHistoryModel> history,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final dateFormat = DateFormat.yMMMd().add_jm();
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (history.isEmpty)
              const Text('No status changes recorded yet.')
            else
              ...history.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ApplicationStatusBadge(status: entry.toStatus),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${entry.changedByName} · ${dateFormat.format(entry.createdAt.toLocal())}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (entry.note != null &&
                                entry.note!.trim().isNotEmpty)
                              Text(
                                entry.note!,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
