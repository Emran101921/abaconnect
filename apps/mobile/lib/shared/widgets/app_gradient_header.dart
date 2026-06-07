import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_spacing.dart';

class AppGradientHeader extends StatelessWidget {
  const AppGradientHeader({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.gradient = AppColors.warmGradient,
    this.borderRadius = const BorderRadius.vertical(
      bottom: Radius.circular(AppSpacing.radiusXl),
    ),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient gradient;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: borderRadius,
        boxShadow: AppShadows.elevated(context),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
