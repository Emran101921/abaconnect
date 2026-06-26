import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/layout/dashboard_card.dart';
import '../../../shared/widgets/app_status_badge.dart';
import '../data/job_opportunities_repository.dart';
import 'phi_warning_banner.dart';

class JobOpportunityCard extends StatelessWidget {
  const JobOpportunityCard({
    super.key,
    required this.opportunity,
    this.onTap,
    this.trailing,
  });

  final JobOpportunityModel opportunity;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      opportunity.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${opportunity.serviceTypeLabel} · ${opportunity.locationAreaLabel}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              AppStatusBadge(label: opportunity.status.replaceAll('_', ' ')),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
            ],
          ),
          if (opportunity.payRateDisplay != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(opportunity.payRateDisplay!),
          ],
          if (opportunity.applicationCount != null &&
              opportunity.applicationCount! > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${opportunity.applicationCount} applicant(s)'
              '${opportunity.pendingActionCount != null && opportunity.pendingActionCount! > 0 ? ' · ${opportunity.pendingActionCount} need action' : ''}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: opportunity.pendingActionCount != null &&
                            opportunity.pendingActionCount! > 0
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
            ),
          ] else if (opportunity.pendingActionCount != null &&
              opportunity.pendingActionCount! > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${opportunity.pendingActionCount} applicant(s) need action',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
          if (opportunity.publicDescription != null &&
              opportunity.publicDescription!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              opportunity.publicDescription!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          const PhiWarningBanner(compact: true),
        ],
      ),
    );
  }
}
