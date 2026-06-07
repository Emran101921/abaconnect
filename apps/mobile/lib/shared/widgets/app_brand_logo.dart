import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

class AppBrandLogo extends StatelessWidget {
  const AppBrandLogo({
    super.key,
    this.size = AppBrandLogoSize.medium,
    this.showTagline = true,
    this.lightOnDark = false,
  });

  final AppBrandLogoSize size;
  final bool showTagline;
  final bool lightOnDark;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final titleColor = lightOnDark ? Colors.white : colorScheme.onSurface;
    final subtitleColor = lightOnDark
        ? Colors.white.withValues(alpha: 0.9)
        : colorScheme.onSurfaceVariant;

    final iconSize = switch (size) {
      AppBrandLogoSize.small => 28.0,
      AppBrandLogoSize.medium => 40.0,
      AppBrandLogoSize.large => 56.0,
    };

    final titleStyle = switch (size) {
      AppBrandLogoSize.small => Theme.of(context).textTheme.titleMedium,
      AppBrandLogoSize.medium => Theme.of(context).textTheme.headlineSmall,
      AppBrandLogoSize.large => Theme.of(context).textTheme.headlineMedium,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: iconSize + 12,
          height: iconSize + 12,
          decoration: BoxDecoration(
            gradient: lightOnDark
                ? LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.25),
                      Colors.white.withValues(alpha: 0.1),
                    ],
                  )
                : AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            boxShadow: lightOnDark
                ? null
                : [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Icon(
            Icons.favorite_rounded,
            color: lightOnDark ? Colors.white : Colors.white,
            size: iconSize * 0.5,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ABA Connect',
              style: titleStyle?.copyWith(
                fontWeight: FontWeight.w800,
                color: titleColor,
                letterSpacing: -0.5,
              ),
            ),
            if (showTagline)
              Text(
                'Early Intervention & therapy care',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: subtitleColor,
                    ),
              ),
          ],
        ),
      ],
    );
  }
}

enum AppBrandLogoSize { small, medium, large }
