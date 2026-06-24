import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../widgets/app_brand_logo.dart';
import '../widgets/app_healthcare_illustration.dart';
import '../widgets/app_theme_toggle.dart';
import '../widgets/app_trust_notice.dart';

/// Shared auth marketing shell for login, register, and onboarding entry.
class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.child,
    this.title = 'Care coordination\nfor every family',
    this.subtitle =
        'Screening, therapy matching, sessions, billing, and clinical '
        'documentation — one secure platform for families and providers.',
    this.illustration = AppIllustrationType.family,
    this.featureChips = const [
      'Early Intervention',
      'HIPAA-aware',
      'Family-first',
    ],
    this.showTrustNotice = true,
  });

  final Widget child;
  final String title;
  final String subtitle;
  final AppIllustrationType illustration;
  final List<String> featureChips;
  final bool showTrustNotice;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= AppSpacing.breakpointWide;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: wide ? _wide(context) : _narrow(context),
    );
  }

  Widget _wide(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _hero(context)),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: child,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _narrow(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              alignment: Alignment.center,
              children: const [
                Align(
                  alignment: Alignment.centerRight,
                  child: AppThemeToggle(compact: true),
                ),
                Center(child: AppBrandLogo(size: AppBrandLogoSize.large)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: AppHealthcareIllustration(
                type: illustration,
                size: 72,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            child,
          ],
        ),
      ),
    );
  }

  Widget _hero(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.authHeroGradient),
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              AppBrandLogo(size: AppBrandLogoSize.large, lightOnDark: true),
              Spacer(),
              AppThemeToggle(compact: true),
            ],
          ),
          const Spacer(),
          AppHealthcareIllustration(type: illustration, size: 132),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.92),
                  height: 1.55,
                ),
          ),
          const Spacer(),
          if (showTrustNotice) ...[
            const AppTrustNotice(dense: true),
            const SizedBox(height: AppSpacing.md),
          ],
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final chip in featureChips) _FeatureChip(label: chip),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }
}
