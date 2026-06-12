import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_glossy_gradients.dart';
import '../../core/theme/app_spacing.dart';

class AppGlassyTabItem {
  const AppGlassyTabItem({
    required this.label,
    required this.icon,
    required this.gradient,
    this.count,
    this.alertCount,
  });

  final String label;
  final IconData icon;
  final LinearGradient gradient;
  final int? count;
  /// Red notification badge (e.g. sessions today).
  final int? alertCount;
}

/// Frosted segmented tab control with per-tab gradient accents.
class AppGlassyTabBar extends StatelessWidget {
  const AppGlassyTabBar({
    super.key,
    required this.controller,
    required this.tabs,
  });

  final TabController controller;
  final List<AppGlassyTabItem> tabs;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            return Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xFF1E1B4B).withValues(alpha: 0.65),
                          const Color(0xFF312E81).withValues(alpha: 0.45),
                        ]
                      : [
                          const Color(0xFFEEF2FF).withValues(alpha: 0.92),
                          const Color(0xFFFCE7F3).withValues(alpha: 0.88),
                        ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.55),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppGlossyGradients.baseShadowColor(
                      AppGlossyGradients.primary,
                    ).withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    Expanded(child: _TabSegment(
                      item: tabs[i],
                      selected: controller.index == i,
                      isDark: isDark,
                      onTap: () => controller.animateTo(i),
                    )),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TabSegment extends StatelessWidget {
  const _TabSegment({
    required this.item,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final AppGlassyTabItem item;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shadowColor = AppGlossyGradients.baseShadowColor(item.gradient);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          gradient: selected ? item.gradient : null,
          color: selected
              ? null
              : (isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.white.withValues(alpha: 0.35)),
          border: selected
              ? Border.all(color: Colors.white.withValues(alpha: 0.45))
              : null,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: shadowColor.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              item.icon,
              size: 18,
              color: selected
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                item.label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (item.alertCount != null && item.alertCount! > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.45),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '${item.alertCount}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ] else if (item.count != null && item.count! > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.25)
                      : item.gradient.colors.first.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${item.count}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected
                        ? Colors.white
                        : item.gradient.colors.last,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
