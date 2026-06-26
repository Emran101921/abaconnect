import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_spacing.dart';
import '../data/job_opportunities_repository.dart';

/// Parsed job offer fields from agency status-history note.
class JobOfferDetails {
  const JobOfferDetails({
    this.compensation,
    this.startDate,
    this.message,
    this.changedByName,
    this.offeredAt,
  });

  final String? compensation;
  final String? startDate;
  final String? message;
  final String? changedByName;
  final DateTime? offeredAt;

  bool get hasStructuredFields =>
      (compensation != null && compensation!.isNotEmpty) ||
      (startDate != null && startDate!.isNotEmpty);

  bool get isEmpty =>
      !hasStructuredFields && (message == null || message!.trim().isEmpty);

  static JobOfferDetails? fromHistory(
    List<JobApplicationStatusHistoryModel> history,
  ) {
    for (final entry in history) {
      if (entry.toStatus == 'OFFER_SENT') {
        return fromNote(
          entry.note,
          changedByName: entry.changedByName,
          offeredAt: entry.createdAt,
        );
      }
    }
    return null;
  }

  static JobOfferDetails? fromNote(
    String? note, {
    String? changedByName,
    DateTime? offeredAt,
  }) {
    if (note == null || note.trim().isEmpty) return null;

    String? compensation;
    String? startDate;
    final messageParts = <String>[];

    for (final part in note.split('\n\n')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith('Compensation:')) {
        compensation = trimmed.substring('Compensation:'.length).trim();
      } else if (trimmed.startsWith('Start date:')) {
        startDate = trimmed.substring('Start date:'.length).trim();
      } else if (trimmed == 'Job offer extended') {
        continue;
      } else {
        messageParts.add(trimmed);
      }
    }

    return JobOfferDetails(
      compensation: compensation,
      startDate: startDate,
      message: messageParts.isEmpty ? null : messageParts.join('\n\n'),
      changedByName: changedByName,
      offeredAt: offeredAt,
    );
  }
}

/// Back-compat helper — returns raw note text for offer-sent history entry.
String? jobOfferDetailsFromHistory(
  List<JobApplicationStatusHistoryModel> history,
) {
  final details = JobOfferDetails.fromHistory(history);
  if (details == null || details.isEmpty) return null;
  final parts = <String>[
    if (details.compensation != null) 'Compensation: ${details.compensation}',
    if (details.startDate != null) 'Start date: ${details.startDate}',
    if (details.message != null) details.message!,
  ];
  return parts.isEmpty ? null : parts.join('\n\n');
}

class JobOfferSummaryCard extends StatelessWidget {
  const JobOfferSummaryCard({
    super.key,
    required this.history,
    this.dense = false,
    this.jobTitle,
    this.agencyName,
  });

  final List<JobApplicationStatusHistoryModel> history;
  final bool dense;
  final String? jobTitle;
  final String? agencyName;

  @override
  Widget build(BuildContext context) {
    final offer = JobOfferDetails.fromHistory(history);
    if (offer == null) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(dense ? AppSpacing.sm : AppSpacing.md),
          child: Text(
            'The agency sent you an offer. Open status history for details.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFormat = DateFormat.yMMMd().add_jm();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: dense ? AppSpacing.sm : AppSpacing.md,
              vertical: dense ? AppSpacing.sm : AppSpacing.md,
            ),
            color: colorScheme.primaryContainer.withValues(alpha: 0.45),
            child: Row(
              children: [
                Icon(
                  Icons.local_offer_outlined,
                  color: colorScheme.primary,
                  size: dense ? 20 : 24,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Job offer',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                        ),
                      ),
                      if (jobTitle != null && jobTitle!.isNotEmpty)
                        Text(
                          jobTitle!,
                          style: theme.textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (agencyName != null && agencyName!.isNotEmpty)
                        Text(
                          agencyName!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(dense ? AppSpacing.sm : AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (offer.compensation != null && offer.compensation!.isNotEmpty)
                  _OfferDetailRow(
                    icon: Icons.payments_outlined,
                    label: 'Compensation',
                    value: offer.compensation!,
                    dense: dense,
                  ),
                if (offer.startDate != null && offer.startDate!.isNotEmpty) ...[
                  if (offer.compensation != null) const SizedBox(height: AppSpacing.sm),
                  _OfferDetailRow(
                    icon: Icons.event_outlined,
                    label: 'Start date',
                    value: offer.startDate!,
                    dense: dense,
                  ),
                ],
                if (offer.message != null && offer.message!.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Message from agency',
                    style: theme.textTheme.labelLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    offer.message!,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
                if (!offer.hasStructuredFields &&
                    (offer.message == null || offer.message!.trim().isEmpty)) ...[
                  Text(
                    'Review the offer details with the agency before accepting.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
                if (offer.changedByName != null || offer.offeredAt != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    [
                      if (offer.changedByName != null)
                        'Sent by ${offer.changedByName}',
                      if (offer.offeredAt != null)
                        dateFormat.format(offer.offeredAt!.toLocal()),
                    ].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferDetailRow extends StatelessWidget {
  const _OfferDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.dense,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: dense ? 18 : 20,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelMedium),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
