import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

class AppRiskBadge extends StatelessWidget {
  const AppRiskBadge({super.key, required this.level});

  final String level;

  @override
  Widget build(BuildContext context) {
    final normalized = level.toUpperCase();
    final (color, bg) = switch (normalized) {
      'HIGH' => (AppColors.riskHigh, AppColors.riskHigh.withValues(alpha: 0.12)),
      'MODERATE' => (
          AppColors.riskModerate,
          AppColors.riskModerate.withValues(alpha: 0.12)
        ),
      'LOW' => (AppColors.riskLow, AppColors.riskLow.withValues(alpha: 0.12)),
      _ => (
          Theme.of(context).colorScheme.onSurfaceVariant,
          Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        normalized,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
      ),
    );
  }
}
