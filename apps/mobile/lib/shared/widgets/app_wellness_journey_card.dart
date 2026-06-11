import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import 'app_circular_progress.dart';

/// Soft card with circular progress — wellness journey summary.
class AppWellnessJourneyCard extends StatelessWidget {
  const AppWellnessJourneyCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.progress,
    this.icon = Icons.favorite_outline_rounded,
    this.iconColor,
  });

  final String title;
  final String subtitle;
  final double progress;
  final IconData icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = iconColor ?? scheme.primary;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.9),
            blurRadius: 0,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Icon(icon, color: accent, size: 26),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppCircularProgress(
            value: progress,
            size: 56,
            strokeWidth: 6,
            color: accent,
            label: '${(progress.clamp(0, 1) * 100).round()}%',
          ),
        ],
      ),
    );
  }
}
