import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_glossy_gradients.dart';
import '../../core/theme/app_spacing.dart';
import 'app_breadcrumbs.dart';

/// Page title block with optional description and action row for dashboards.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    this.description,
    this.showBreadcrumbs = true,
    this.actions,
    this.badge,
  });

  final String title;
  final String? description;
  final bool showBreadcrumbs;
  final List<Widget>? actions;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= AppSpacing.breakpointWide;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      padding: EdgeInsets.all(isWide ? AppSpacing.lg : AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.surface,
            AppColors.primary.withValues(alpha: 0.04),
            AppColors.secondary.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showBreadcrumbs) const AppBreadcrumbs(),
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _titleBlock(context, colorScheme)),
                if (actions != null && actions!.isNotEmpty) ...[
                  const SizedBox(width: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: actions!,
                  ),
                ],
              ],
            )
          else ...[
            _titleBlock(context, colorScheme),
            if (actions != null && actions!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: actions!,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _titleBlock(BuildContext context, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
            ),
            if (badge != null) badge!,
          ],
        ),
        if (description != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            description!,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
          ),
        ],
      ],
    );
  }
}

/// Soft gradient backdrop for authenticated app pages.
class AppPageBackground extends StatelessWidget {
  const AppPageBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppGlossyGradients.pageBackground(context),
      ),
      child: child,
    );
  }
}
