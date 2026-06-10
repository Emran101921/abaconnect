import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/providers/consent_gate_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../data/privacy_repository.dart';

final privacyNoticeSummaryProvider =
    FutureProvider<PrivacyNoticeSummaryModel>((ref) {
      return ref.watch(privacyRepositoryProvider).fetchNoticeSummary();
    });

class HipaaPrivacyNoticeScreen extends ConsumerStatefulWidget {
  const HipaaPrivacyNoticeScreen({super.key, this.onboardingMode = true});

  /// When true, Continue advances onboarding (MFA setup). When false, pops back.
  final bool onboardingMode;

  @override
  ConsumerState<HipaaPrivacyNoticeScreen> createState() =>
      _HipaaPrivacyNoticeScreenState();
}

class _HipaaPrivacyNoticeScreenState
    extends ConsumerState<HipaaPrivacyNoticeScreen> {
  bool _checked = false;
  bool _submitting = false;

  Future<void> _continue() async {
    if (!_checked || _submitting) return;
    setState(() => _submitting = true);
    try {
      await ref.read(privacyRepositoryProvider).acknowledgeNotice();
      await ref.read(authRepositoryProvider).setHipaaConsentGranted(true);
      ref.read(hipaaConsentGrantedProvider.notifier).state = true;
      ref.invalidate(privacyNoticeSummaryProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Acknowledgment saved. Thank you.'),
        ),
      );
      if (widget.onboardingMode) {
        final session = ref.read(authStateProvider).valueOrNull;
        if (session != null &&
            roleRequiresOnboarding(session.user.role) &&
            !ref.read(mfaEnabledProvider)) {
          context.go(AppRoutes.security);
        } else {
          context.go(session?.user.role.homeRoute ?? AppRoutes.parentHome);
        }
      } else {
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save acknowledgment. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(privacyNoticeSummaryProvider);
    final theme = Theme.of(context);

    return AppScaffold(
      title: 'HIPAA Privacy Notice',
      body: summary.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(
          child: Text('Unable to load privacy notice. Please try again.'),
        ),
        data: (notice) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              notice.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              semanticsLabel: 'HIPAA Privacy Notice',
            ),
            const SizedBox(height: 8),
            Text(
              'Notice Version: ${notice.versionNumber}',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 16),
            Text(
              notice.shortAcknowledgmentText,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
            const SizedBox(height: 20),
            Semantics(
              button: true,
              label: 'View Notice of Privacy Practices',
              child: OutlinedButton.icon(
                onPressed: () =>
                    context.push(AppRoutes.privacyNoticeOfPractices),
                icon: const Icon(Icons.article_outlined),
                label: const Text('View Notice of Privacy Practices'),
              ),
            ),
            const SizedBox(height: 12),
            Semantics(
              button: true,
              label: 'View Privacy Policy',
              child: OutlinedButton.icon(
                onPressed: () => context.push(AppRoutes.privacyPolicy),
                icon: const Icon(Icons.policy_outlined),
                label: const Text('View Privacy Policy'),
              ),
            ),
            const SizedBox(height: 24),
            CheckboxListTile(
              value: _checked,
              onChanged: (v) => setState(() => _checked = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                notice.checkboxText,
                style: theme.textTheme.bodyMedium,
              ),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            Semantics(
              button: true,
              enabled: _checked && !_submitting,
              label: 'Continue after acknowledging privacy notice',
              child: FilledButton(
                onPressed: _checked && !_submitting ? _continue : null,
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
