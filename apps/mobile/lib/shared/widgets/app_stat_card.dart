import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';

class AppStatCard extends StatelessWidget {
  const AppStatCard({
    super.key,
    required this.label,
    required this.value,
    this.periodDelta,
    this.highlight = false,
    this.accent = false,
    this.icon,
    this.onTap,
    this.width = 168,
  });

  final String label;
  final Object value;
  final String? periodDelta;
  final bool highlight;
  final bool accent;
  final IconData? icon;
  final VoidCallback? onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    Color? bg;
    var fg = colorScheme.onSurface;
    List<BoxShadow>? shadows = AppShadows.card(context);

    if (highlight) {
      bg = colorScheme.errorContainer;
      fg = colorScheme.onErrorContainer;
    } else if (accent) {
      bg = colorScheme.primary;
      fg = colorScheme.onPrimary;
      shadows = AppShadows.elevated(context);
    }

    final content = Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: accent
                    ? Colors.white.withValues(alpha: 0.2)
                    : colorScheme.primaryContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(
                icon,
                size: 20,
                color: accent ? fg : colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Text(
            '$value',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: fg,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: fg.withValues(alpha: 0.85),
              fontWeight: FontWeight.w500,
            ),
          ),
          if (periodDelta != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'vs prior: $periodDelta',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _deltaColor(context, periodDelta!),
              ),
            ),
          ],
        ],
      ),
    );

    return SizedBox(
      width: width,
      child: Container(
        decoration: BoxDecoration(
          color: bg ?? colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: accent
              ? null
              : Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.7),
                ),
          boxShadow: shadows,
        ),
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? content
            : Material(
                color: Colors.transparent,
                child: InkWell(onTap: onTap, child: content),
              ),
      ),
    );
  }
}

Color? _deltaColor(BuildContext context, String delta) {
  if (delta == '—') {
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }
  if (delta.startsWith('+')) return AppColors.success;
  if (delta.startsWith('-')) return AppColors.error;
  return Theme.of(context).colorScheme.onSurfaceVariant;
}
