import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/layout/onboarding_wizard_shell.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../data/therapist_repository.dart';

final providerOnboardingProvider =
    FutureProvider<ProviderOnboardingChecklistModel>((ref) {
      return ref.watch(therapistRepositoryProvider).fetchOnboardingChecklist();
    });

class ProviderOnboardingScreen extends ConsumerWidget {
  const ProviderOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checklist = ref.watch(providerOnboardingProvider);

    return AppScaffold(
      title: 'Provider onboarding',
      body: checklist.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (c) {
          if (c.phiAccessApproved) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_user, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'Your provider access is approved.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Browse anonymous service requests in your coverage area, '
                      'or return to your caseload dashboard.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 20),
                    GlossyButton(
                      title: 'Browse marketplace',
                      icon: Icons.storefront_outlined,
                      variant: GlossyButtonVariant.tealBlue,
                      onPressed: () => context.go(AppRoutes.therapistMarketplace),
                    ),
                    const SizedBox(height: 8),
                    GlossyOutlinedButton(
                      onPressed: () => context.go(AppRoutes.therapistHome),
                      child: const Text('Go to dashboard'),
                    ),
                  ],
                ),
              ),
            );
          }

          final canSubmit = c.licenseComplete &&
              c.npiComplete &&
              c.hipaaTrainingComplete &&
              c.confidentialityAgreementComplete &&
              c.onboardingStatus != 'IN_REVIEW';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              OnboardingWizardShell(
                title: 'Provider onboarding',
                subtitle: 'Complete credentials and compliance before PHI access.',
                currentStep: _completedSteps(c),
                totalSteps: 5,
                stepLabels: const [
                  'Identity',
                  'License',
                  'NPI',
                  'HIPAA',
                  'Review',
                ],
                child: const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),
              Text(
                'Complete onboarding before accessing client PHI',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Status: ${c.onboardingStatus}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              _CheckTile(
                done: c.identityComplete,
                label: 'Identity information',
              ),
              _CheckTile(
                done: c.licenseComplete,
                label: 'License on file',
                action: c.licenseComplete
                    ? null
                    : () => context.push(
                        '${AppRoutes.therapistHome}/profile',
                      ),
                actionLabel: 'Edit profile',
              ),
              _CheckTile(
                done: c.npiComplete,
                label: 'NPI number',
                action: c.npiComplete
                    ? null
                    : () => context.push(
                        '${AppRoutes.therapistHome}/profile',
                      ),
                actionLabel: 'Add NPI',
              ),
              _CheckTile(
                done: c.hipaaTrainingComplete,
                label: 'HIPAA training attestation',
                action: c.hipaaTrainingComplete
                    ? null
                    : () => _attest(ref, context, 'hipaa'),
                actionLabel: 'Attest',
              ),
              _CheckTile(
                done: c.confidentialityAgreementComplete,
                label: 'Confidentiality agreement',
                action: c.confidentialityAgreementComplete
                    ? null
                    : () => _attest(ref, context, 'confidentiality'),
                actionLabel: 'Sign',
              ),
              _CheckTile(
                done: c.agencyApprovalComplete,
                label: 'Agency / admin approval',
              ),
              const SizedBox(height: 24),
              if (c.onboardingStatus == 'IN_REVIEW')
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Your application is under review. You will be notified '
                      'when an administrator approves PHI access.',
                    ),
                  ),
                )
              else if (canSubmit)
                GlossyButton(
                  title: 'Submit for review',
                  variant: GlossyButtonVariant.bluePurple,
                  onPressed: () => _submit(ref, context),
                )
              else
                GlossyOutlinedButton(
                  onPressed: () => context.push(
                    '${AppRoutes.therapistHome}/profile',
                  ),
                  child: const Text('Complete profile'),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _attest(
    WidgetRef ref,
    BuildContext context,
    String type,
  ) async {
    final repo = ref.read(therapistRepositoryProvider);
    try {
      if (type == 'hipaa') {
        await repo.attestHipaaTraining();
      } else {
        await repo.attestConfidentialityAgreement();
      }
      ref.invalidate(providerOnboardingProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _submit(WidgetRef ref, BuildContext context) async {
    try {
      await ref.read(therapistRepositoryProvider).submitProviderOnboarding();
      ref.invalidate(providerOnboardingProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Submitted for admin review')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }
}

int _completedSteps(ProviderOnboardingChecklistModel c) {
  var n = 0;
  if (c.identityComplete) n++;
  if (c.licenseComplete) n++;
  if (c.npiComplete) n++;
  if (c.hipaaTrainingComplete && c.confidentialityAgreementComplete) n++;
  if (c.phiAccessApproved || c.onboardingStatus == 'IN_REVIEW') n++;
  return n.clamp(1, 5);
}

class _CheckTile extends StatelessWidget {
  const _CheckTile({
    required this.done,
    required this.label,
    this.action,
    this.actionLabel,
  });

  final bool done;
  final String label;
  final VoidCallback? action;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          done ? Icons.check_circle : Icons.radio_button_unchecked,
          color: done ? Colors.green.shade700 : null,
        ),
        title: Text(label),
        trailing: action == null
            ? null
            : TextButton(onPressed: action, child: Text(actionLabel ?? 'Go')),
      ),
    );
  }
}
