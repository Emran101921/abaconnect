import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/layout/dashboard_card.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../../documents/presentation/documents_screen.dart';
import '../models/therapist_employment_document_requirements.dart';

class TherapistEmploymentDocumentsSection extends ConsumerStatefulWidget {
  const TherapistEmploymentDocumentsSection({super.key});

  @override
  ConsumerState<TherapistEmploymentDocumentsSection> createState() =>
      _TherapistEmploymentDocumentsSectionState();
}

class _TherapistEmploymentDocumentsSectionState
    extends ConsumerState<TherapistEmploymentDocumentsSection> {
  TherapistEmploymentType _employmentType = TherapistEmploymentType.w2;

  @override
  Widget build(BuildContext context) {
    final uploads = ref.watch(documentsProvider);
    final uploadCount = uploads.maybeWhen(
      data: (docs) => docs.length,
      orElse: () => null,
    );

    final groups = [
      TherapistDocumentRequirementGroup.allEmployees,
      if (_employmentType == TherapistEmploymentType.contractor1099)
        TherapistDocumentRequirementGroup.contractor1099Only,
      TherapistDocumentRequirementGroup.signatureRequired,
    ];

    return DashboardCard(
      title: 'Employment documents',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Agencies require these records before or during onboarding. '
            'Upload copies below and share with your hiring agency.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<TherapistEmploymentType>(
            segments: const [
              ButtonSegment(
                value: TherapistEmploymentType.w2,
                label: Text('W2 employee'),
                icon: Icon(Icons.badge_outlined),
              ),
              ButtonSegment(
                value: TherapistEmploymentType.contractor1099,
                label: Text('1099 contractor'),
                icon: Icon(Icons.work_outline),
              ),
            ],
            selected: {_employmentType},
            onSelectionChanged: (selection) {
              setState(() => _employmentType = selection.first);
            },
          ),
          if (uploadCount != null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(
                  Icons.folder_open_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    '$uploadCount file${uploadCount == 1 ? '' : 's'} in your document library',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          ...groups.map(
            (group) => _RequirementGroupCard(
              group: group,
              employmentType: _employmentType,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          GlossyButton(
            label: 'Upload documents',
            variant: GlossyButtonVariant.secondary,
            onPressed: () => context.push(AppRoutes.documents),
          ),
        ],
      ),
    );
  }
}

class _RequirementGroupCard extends StatelessWidget {
  const _RequirementGroupCard({
    required this.group,
    required this.employmentType,
  });

  final TherapistDocumentRequirementGroup group;
  final TherapistEmploymentType employmentType;

  @override
  Widget build(BuildContext context) {
    final items = requirementsInGroup(group, employmentType);
    if (items.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: group ==
                TherapistDocumentRequirementGroup.allEmployees,
            tilePadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            leading: Icon(
              _groupIcon(group),
              color: colorScheme.primary,
            ),
            title: Text(
              groupTitle(group),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '${items.length} item${items.length == 1 ? '' : 's'}',
              style: theme.textTheme.bodySmall,
            ),
            children: [
              Text(
                groupIntro(group),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.circle,
                          size: 6,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.label,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (item.hint != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                item.hint!,
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _groupIcon(TherapistDocumentRequirementGroup group) {
    switch (group) {
      case TherapistDocumentRequirementGroup.allEmployees:
        return Icons.assignment_outlined;
      case TherapistDocumentRequirementGroup.contractor1099Only:
        return Icons.business_center_outlined;
      case TherapistDocumentRequirementGroup.signatureRequired:
        return Icons.draw_outlined;
    }
  }
}
