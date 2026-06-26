import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../therapist/models/therapist_employment_document_requirements.dart';

/// Scrollable grouped list of agency employment document titles for upload.
class EmploymentDocumentTitlePicker extends StatelessWidget {
  const EmploymentDocumentTitlePicker({
    super.key,
    required this.selectedTitle,
    required this.onSelect,
    this.maxHeight = 320,
  });

  final String selectedTitle;
  final ValueChanged<TherapistDocumentRequirement> onSelect;
  final double maxHeight;

  static const _sections = [
    TherapistDocumentRequirementGroup.allEmployees,
    TherapistDocumentRequirementGroup.contractor1099Only,
    TherapistDocumentRequirementGroup.signatureRequired,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Select a document title',
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Tap a title below to fill the upload form.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Scrollbar(
            thumbVisibility: true,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final group in _sections) ...[
                  _SectionHeader(
                    title: _uploadSectionHeading(group),
                    intro: groupIntro(group),
                  ),
                  ...requirementsInGroup(
                    group,
                    TherapistEmploymentType.contractor1099,
                  ).map(
                    (req) => _TitleTile(
                      requirement: req,
                      selected: selectedTitle.trim() == req.label,
                      onTap: () => onSelect(req),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _uploadSectionHeading(TherapistDocumentRequirementGroup group) {
    switch (group) {
      case TherapistDocumentRequirementGroup.allEmployees:
        return '1099 & W2 EMPLOYEES';
      case TherapistDocumentRequirementGroup.contractor1099Only:
        return '1099 EMPLOYEES ONLY';
      case TherapistDocumentRequirementGroup.signatureRequired:
        return 'Documents that require signatures';
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.intro});

  final String title;
  final String intro;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            intro,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TitleTile extends StatelessWidget {
  const _TitleTile({
    required this.requirement,
    required this.selected,
    required this.onTap,
  });

  final TherapistDocumentRequirement requirement;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Icon(
                  selected ? Icons.radio_button_checked : Icons.circle_outlined,
                  size: 16,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  requirement.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
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

/// All upload titles in display order (for tests and validation).
List<String> get allEmploymentDocumentUploadTitles =>
    therapistEmploymentDocumentRequirements.map((r) => r.label).toList();
