import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/app_snackbar.dart';
import '../data/job_opportunities_repository.dart';

class HireOnboardingChecklist extends ConsumerWidget {
  const HireOnboardingChecklist({
    super.key,
    required this.onboarding,
    required this.therapistView,
  });

  final HireOnboardingModel onboarding;
  final bool therapistView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${onboarding.completedCount}/${onboarding.totalCount} complete',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        ...onboarding.steps.map(
          (step) => CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: step.complete,
            onChanged: _canToggle(step)
                ? (value) => _toggleStep(ref, context, step.key, value == true)
                : null,
            title: Text(step.label),
            subtitle: step.completedAt != null
                ? Text(
                    'Completed ${DateFormat.yMMMd().add_jm().format(step.completedAt!.toLocal())}',
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                : null,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ),
      ],
    );
  }

  bool _canToggle(HireOnboardingStepModel step) {
    if (step.complete) return false;
    if (therapistView) return step.therapistCanComplete;
    return !step.therapistCanComplete && step.key != 'FIRST_SESSION';
  }

  Future<void> _toggleStep(
    WidgetRef ref,
    BuildContext context,
    String stepKey,
    bool complete,
  ) async {
    try {
      await ref.read(jobOpportunitiesRepositoryProvider).updateHireOnboardingStep(
            agencyTherapistLinkId: onboarding.agencyTherapistLinkId,
            step: stepKey,
            complete: complete,
          );
      ref.invalidate(
        therapistView ? myHireOnboardingsProvider : agencyHireOnboardingsProvider,
      );
      if (context.mounted) {
        AppSnackBar.showSuccess(context, 'Onboarding step updated');
      }
    } catch (e) {
      if (context.mounted) AppSnackBar.showError(context, e);
    }
  }
}

Future<void> showHireOnboardingSheet(
  BuildContext context, {
  required HireOnboardingModel onboarding,
  required bool therapistView,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              therapistView
                  ? '${onboarding.agencyName} onboarding'
                  : '${onboarding.therapistName} onboarding',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            HireOnboardingChecklist(
              onboarding: onboarding,
              therapistView: therapistView,
            ),
          ],
        ),
      ),
    ),
  );
}
