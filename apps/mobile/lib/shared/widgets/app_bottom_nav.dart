import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_glossy_gradients.dart';
import '../../core/theme/app_spacing.dart';
import '../providers/bottom_nav_badge_providers.dart';

enum ParentNavTab { home, children, screening, messages }

enum TherapistNavTab { home, appointments, sessions, messages }

class AppGlassyNavItem {
  const AppGlassyNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.gradient,
    this.badgeCount,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final LinearGradient gradient;
  final int? badgeCount;
}

class AppGlassyBottomNav extends StatelessWidget {
  const AppGlassyBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.items,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<AppGlassyNavItem> items;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xFF1E1B4B).withValues(alpha: 0.72),
                          const Color(0xFF312E81).withValues(alpha: 0.55),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.88),
                          const Color(0xFFEEF2FF).withValues(alpha: 0.92),
                        ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: isDark ? 0.14 : 0.6),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppGlossyGradients.baseShadowColor(
                      AppGlossyGradients.primary,
                    ).withValues(alpha: 0.14),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: _GlassyNavButton(
                        item: items[i],
                        selected: selectedIndex == i,
                        isDark: isDark,
                        onTap: () => onSelected(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavIconWithBadge extends StatelessWidget {
  const _NavIconWithBadge({
    required this.icon,
    required this.color,
    this.badgeCount,
  });

  final IconData icon;
  final Color color;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, size: 22, color: color);
    if (badgeCount == null || badgeCount! <= 0) {
      return iconWidget;
    }

    return Badge(
      label: Text(
        badgeCount! > 9 ? '9+' : '$badgeCount',
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
      ),
      backgroundColor: const Color(0xFFEF4444),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      offset: const Offset(6, -8),
      child: iconWidget,
    );
  }
}

class _GlassyNavButton extends StatelessWidget {
  const _GlassyNavButton({
    required this.item,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final AppGlassyNavItem item;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shadowColor = AppGlossyGradients.baseShadowColor(item.gradient);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          gradient: selected ? item.gradient : null,
          color: selected
              ? null
              : (isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.white.withValues(alpha: 0.3)),
          border: selected
              ? Border.all(color: Colors.white.withValues(alpha: 0.4))
              : null,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: shadowColor.withValues(alpha: 0.32),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _NavIconWithBadge(
              icon: selected ? item.selectedIcon : item.icon,
              color: selected
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              badgeCount: item.badgeCount,
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: selected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ParentBottomNav extends ConsumerWidget {
  const ParentBottomNav({super.key, required this.current});

  final ParentNavTab current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeBadge = ref.watch(parentHomeNavBadgeProvider);
    final messagesBadge = ref.watch(parentMessagesNavBadgeProvider);

    return AppGlassyBottomNav(
      selectedIndex: current.index,
      onSelected: (index) {
        final tab = ParentNavTab.values[index];
        if (tab == current) return;
        switch (tab) {
          case ParentNavTab.home:
            context.go(AppRoutes.parentHome);
          case ParentNavTab.children:
            context.go(AppRoutes.parentChildren);
          case ParentNavTab.screening:
            context.go(AppRoutes.parentScreening);
          case ParentNavTab.messages:
            context.go(AppRoutes.messages);
        }
      },
      items: [
        AppGlassyNavItem(
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
          label: 'Home',
          gradient: AppGlossyGradients.primary,
          badgeCount: homeBadge,
        ),
        const AppGlassyNavItem(
          icon: Icons.child_care_outlined,
          selectedIcon: Icons.child_care_rounded,
          label: 'Children',
          gradient: AppGlossyGradients.secondary,
        ),
        const AppGlassyNavItem(
          icon: Icons.assignment_outlined,
          selectedIcon: Icons.assignment_rounded,
          label: 'Screening',
          gradient: AppGlossyGradients.tertiary,
        ),
        AppGlassyNavItem(
          icon: Icons.chat_bubble_outline_rounded,
          selectedIcon: Icons.chat_bubble_rounded,
          label: 'Messages',
          gradient: AppGlossyGradients.info,
          badgeCount: messagesBadge,
        ),
      ],
    );
  }
}

class TherapistBottomNav extends ConsumerWidget {
  const TherapistBottomNav({super.key, required this.current});

  final TherapistNavTab current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleBadge = ref.watch(therapistScheduleNavBadgeProvider);
    final sessionsBadge = ref.watch(therapistSessionsNavBadgeProvider);
    final messagesBadge = ref.watch(therapistMessagesNavBadgeProvider);

    return AppGlassyBottomNav(
      selectedIndex: current.index,
      onSelected: (index) {
        final tab = TherapistNavTab.values[index];
        if (tab == current) return;
        switch (tab) {
          case TherapistNavTab.home:
            context.go(AppRoutes.therapistHome);
          case TherapistNavTab.appointments:
            context.go(AppRoutes.therapistAppointments);
          case TherapistNavTab.sessions:
            context.go(AppRoutes.therapistSessionNotes);
          case TherapistNavTab.messages:
            context.go(AppRoutes.messages);
        }
      },
      items: [
        const AppGlassyNavItem(
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard_rounded,
          label: 'Home',
          gradient: AppGlossyGradients.primary,
        ),
        AppGlassyNavItem(
          icon: Icons.event_outlined,
          selectedIcon: Icons.event_rounded,
          label: 'Schedule',
          gradient: AppGlossyGradients.tertiary,
          badgeCount: scheduleBadge,
        ),
        AppGlassyNavItem(
          icon: Icons.note_alt_outlined,
          selectedIcon: Icons.note_alt_rounded,
          label: 'Sessions',
          gradient: AppGlossyGradients.warning,
          badgeCount: sessionsBadge,
        ),
        AppGlassyNavItem(
          icon: Icons.chat_bubble_outline_rounded,
          selectedIcon: Icons.chat_bubble_rounded,
          label: 'Messages',
          gradient: AppGlossyGradients.info,
          badgeCount: messagesBadge,
        ),
      ],
    );
  }
}
