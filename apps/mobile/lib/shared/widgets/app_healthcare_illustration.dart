import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

enum AppIllustrationType {
  family,
  screening,
  therapy,
  messaging,
  scheduling,
  progress,
}

/// Lightweight vector-style illustration using gradients and icons.
class AppHealthcareIllustration extends StatelessWidget {
  const AppHealthcareIllustration({
    super.key,
    this.type = AppIllustrationType.family,
    this.size = 120,
  });

  final AppIllustrationType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (icon, colors) = switch (type) {
      AppIllustrationType.family => (
        Icons.family_restroom_rounded,
        [AppColors.primary, AppColors.secondary],
      ),
      AppIllustrationType.screening => (
        Icons.assignment_turned_in_outlined,
        [AppColors.secondary, AppColors.accent],
      ),
      AppIllustrationType.therapy => (
        Icons.psychology_outlined,
        [AppColors.primary, const Color(0xFF7C3AED)],
      ),
      AppIllustrationType.messaging => (
        Icons.forum_outlined,
        [AppColors.secondary, AppColors.primaryLight],
      ),
      AppIllustrationType.scheduling => (
        Icons.event_available_outlined,
        [AppColors.accent, AppColors.secondary],
      ),
      AppIllustrationType.progress => (
        Icons.trending_up_rounded,
        [AppColors.success, AppColors.accent],
      ),
    };

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  colors[0].withValues(alpha: 0.15),
                  colors[1].withValues(alpha: 0.08),
                ],
              ),
            ),
          ),
          Container(
            width: size * 0.72,
            height: size * 0.72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors[0].withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, size: size * 0.34, color: Colors.white),
          ),
          Positioned(
            right: size * 0.08,
            top: size * 0.12,
            child: Container(
              width: size * 0.18,
              height: size * 0.18,
              decoration: BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AppIllustrationRow extends StatelessWidget {
  const AppIllustrationRow({
    super.key,
    required this.type,
    required this.title,
    this.subtitle,
  });

  final AppIllustrationType type;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppHealthcareIllustration(type: type, size: 72),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
