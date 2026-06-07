import 'package:flutter/material.dart';

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

    if (highlight) {
      bg = colorScheme.errorContainer;
      fg = colorScheme.onErrorContainer;
    } else if (accent) {
      bg = colorScheme.primary;
      fg = colorScheme.onPrimary;
    }

    final content = Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: fg.withValues(alpha: 0.9)),
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
      child: Material(
        color: bg ?? colorScheme.surfaceContainerLow,
        elevation: accent ? 2 : 0,
        shadowColor: colorScheme.primary.withValues(alpha: 0.25),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          side: accent
              ? BorderSide.none
              : BorderSide(color: colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? content
            : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}

Color? _deltaColor(BuildContext context, String delta) {
  if (delta == '—') {
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }
  if (delta.startsWith('+')) return const Color(0xFF059669);
  if (delta.startsWith('-')) return const Color(0xFFDC2626);
  return Theme.of(context).colorScheme.onSurfaceVariant;
}
