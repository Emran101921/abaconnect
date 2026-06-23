import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/providers/consent_gate_provider.dart';
import '../../../shared/layout/onboarding_wizard_shell.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_status_badge.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../../platform/data/platform_repository.dart';

final consentsProvider = FutureProvider<List<ConsentItemModel>>((ref) {
  return ref.watch(platformRepositoryProvider).fetchConsents();
});

class ConsentScreen extends ConsumerWidget {
  const ConsentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consents = ref.watch(consentsProvider);
    final session = ref.watch(authStateProvider).valueOrNull;
    final onboardingRole =
        session != null && roleRequiresOnboarding(session.user.role);
    final consentPending = !ref.watch(hipaaConsentGrantedProvider);

    return AppScaffold(
      title: 'Privacy & consent',
      body: consents.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(
          child: Text('Unable to load consent status. Please try again.'),
        ),
        data: (list) {
          final formContent = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (onboardingRole && consentPending) ...[
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.privacy_tip_outlined,
                          color:
                              Theme.of(context).colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'You must accept the HIPAA privacy agreement before '
                            'using the app. After consent, you will set up '
                            'two-factor authentication.',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ] else ...[
                const Text(
                  'HIPAA consents required to use clinical features. '
                  'Grant the latest policy version below.',
                ),
                const SizedBox(height: 16),
              ],
              ...list.map(
                (c) => Card(
                  child: ListTile(
                    title: Text(c.consentType),
                    subtitle: Text('Version ${c.version}'),
                    trailing: AppStatusBadge.fromKind(
                      c.granted
                          ? AppStatusKind.approved
                          : AppStatusKind.pending,
                      label: c.granted ? 'Granted' : 'Required',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GlossyButton(
                title: 'Grant HIPAA privacy policy v1.0',
                variant: GlossyButtonVariant.greenTeal,
                onPressed: () async {
                  try {
                    await ref
                        .read(platformRepositoryProvider)
                        .grantConsent('HIPAA_PRIVACY', '1.0');
                    await ref
                        .read(authRepositoryProvider)
                        .setHipaaConsentGranted(true);
                    ref.read(hipaaConsentGrantedProvider.notifier).state =
                        true;
                    ref.invalidate(consentsProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Consent granted')),
                      );
                      if (onboardingRole && !ref.read(mfaEnabledProvider)) {
                        context.go(AppRoutes.security);
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(
                        const SnackBar(
                          content: Text('Could not save consent. Try again.'),
                        ),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 12),
              GlossyOutlinedButton(
                onPressed: () => context.push(AppRoutes.phiAccessReport),
                child: const Text('View PHI access report'),
              ),
            ],
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (onboardingRole && consentPending)
                OnboardingWizardShell(
                  title: 'Privacy & consent',
                  subtitle:
                      'Step 1 of 2 — review and accept required policies',
                  currentStep: 1,
                  totalSteps: 2,
                  stepLabels: const ['Consent', 'Security'],
                  child: formContent,
                )
              else
                formContent,
            ],
          );
        },
      ),
    );
  }
}
