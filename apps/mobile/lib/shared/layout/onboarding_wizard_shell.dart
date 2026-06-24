import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../widgets/app_trust_notice.dart';
import 'step_progress.dart';

/// Wraps multi-step onboarding flows with progress and trust messaging.
class OnboardingWizardShell extends StatelessWidget {
  const OnboardingWizardShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.currentStep,
    required this.totalSteps,
    required this.child,
    this.stepLabels,
    this.showTrustNotice = true,
  });

  final String title;
  final String subtitle;
  final int currentStep;
  final int totalSteps;
  final Widget child;
  final List<String>? stepLabels;
  final bool showTrustNotice;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: AppSpacing.lg),
        StepProgress(
          currentStep: currentStep,
          totalSteps: totalSteps,
          labels: stepLabels,
        ),
        if (showTrustNotice) ...[
          const SizedBox(height: AppSpacing.md),
          const AppTrustNotice(dense: true),
        ],
        const SizedBox(height: AppSpacing.lg),
        child,
      ],
    );
  }
}
