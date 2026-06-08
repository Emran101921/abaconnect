import 'package:flutter/material.dart';

import '../../core/theme/app_brand_assets.dart';
import '../../core/theme/app_spacing.dart';

class AppBrandLogo extends StatelessWidget {
  const AppBrandLogo({
    super.key,
    this.size = AppBrandLogoSize.medium,
    this.showTagline = false,
    this.lightOnDark = false,
  });

  final AppBrandLogoSize size;
  final bool showTagline;
  final bool lightOnDark;

  double get _width => switch (size) {
    AppBrandLogoSize.small => 140,
    AppBrandLogoSize.medium => 200,
    AppBrandLogoSize.large => 280,
  };

  @override
  Widget build(BuildContext context) {
    final logo = Image.asset(
      AppBrandAssets.logo,
      width: _width,
      fit: BoxFit.contain,
      semanticLabel: 'BloomOra',
    );

    if (!lightOnDark) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          logo,
          if (showTagline) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              AppBrandAssets.tagline,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                letterSpacing: 0.6,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: logo,
    );
  }
}

enum AppBrandLogoSize { small, medium, large }
