import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

class AppAnimatedProgress extends StatelessWidget {
  const AppAnimatedProgress({
    super.key,
    required this.value,
    this.height = 8,
    this.label,
    this.showPercent = true,
  });

  final double value;
  final double height;
  final String? label;
  final bool showPercent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final clamped = value.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null || showPercent)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                if (label != null)
                  Expanded(
                    child: Text(
                      label!,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                if (showPercent)
                  Text(
                    '${(clamped * 100).round()}%',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(height),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: clamped),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            builder: (context, animatedValue, _) {
              return LinearProgressIndicator(
                value: animatedValue,
                minHeight: height,
                backgroundColor: colorScheme.outlineVariant,
                color: colorScheme.secondary,
              );
            },
          ),
        ),
      ],
    );
  }
}
