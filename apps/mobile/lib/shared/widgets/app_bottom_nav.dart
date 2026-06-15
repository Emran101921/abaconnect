import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../features/notifications/notification_providers.dart';
import '../../features/parent/presentation/parent_home_screen.dart';
import '../providers/bottom_nav_badge_providers.dart';
import 'glassy_bottom_nav.dart';

/// Parent tabs — order matches futuristic bar left → right:
/// Screening · Security · **Home** · Children · Messages
enum ParentNavTab { screening, security, home, children, messages }

/// Therapist tabs — order matches futuristic bar left → right:
/// Sessions · Security · **Home** · Appointments · Messages
enum TherapistNavTab { sessions, security, home, appointments, messages }

/// Legacy item type kept for any external references.
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

/// @deprecated Use [GlassyBottomNav] directly. Kept for backward compatibility.
typedef AppGlassyBottomNav = GlassyBottomNav;

class ParentBottomNav extends ConsumerWidget {
  const ParentBottomNav({super.key, required this.current});

  final ParentNavTab current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeBadge = ref.watch(parentHomeNavBadgeProvider);
    final messagesBadge = ref.watch(parentMessagesNavBadgeProvider);

    return GlassyBottomNav(
      activeTab: current.index,
      onTabPress: (index) {
        final tab = ParentNavTab.values[index];
        if (tab == current && tab != ParentNavTab.home) return;
        switch (tab) {
          case ParentNavTab.screening:
            context.go(AppRoutes.parentScreening);
          case ParentNavTab.security:
            context.go(AppRoutes.security);
          case ParentNavTab.home:
            ref.invalidate(parentDashboardProvider);
            ref.invalidate(unreadNotificationsProvider);
            if (tab != current) {
              context.go(AppRoutes.parentHome);
            }
          case ParentNavTab.children:
            context.go(AppRoutes.parentChildren);
          case ParentNavTab.messages:
            context.go(AppRoutes.messages);
        }
      },
      tabs: [
        const GlassyNavTab(
          label: 'Screening',
          icon: Icons.fact_check_outlined,
          selectedIcon: Icons.fact_check_rounded,
        ),
        const GlassyNavTab(
          label: 'Security',
          icon: Icons.shield_outlined,
          selectedIcon: Icons.shield_rounded,
        ),
        GlassyNavTab(
          label: 'Home',
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
          isCenter: true,
          badgeCount: homeBadge,
        ),
        const GlassyNavTab(
          label: 'Children',
          icon: Icons.child_care_outlined,
          selectedIcon: Icons.child_care_rounded,
        ),
        GlassyNavTab(
          label: 'Messages',
          icon: Icons.chat_bubble_outline_rounded,
          selectedIcon: Icons.chat_bubble_rounded,
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

    return GlassyBottomNav(
      activeTab: current.index,
      onTabPress: (index) {
        final tab = TherapistNavTab.values[index];
        if (tab == current && tab != TherapistNavTab.home) return;
        switch (tab) {
          case TherapistNavTab.sessions:
            context.go(AppRoutes.therapistSessionNotes);
          case TherapistNavTab.security:
            context.go(AppRoutes.security);
          case TherapistNavTab.home:
            if (tab != current) {
              context.go(AppRoutes.therapistHome);
            }
          case TherapistNavTab.appointments:
            context.go(AppRoutes.therapistAppointments);
          case TherapistNavTab.messages:
            context.go(AppRoutes.messages);
        }
      },
      tabs: [
        GlassyNavTab(
          label: 'Sessions',
          icon: Icons.edit_note_outlined,
          selectedIcon: Icons.edit_note_rounded,
          badgeCount: sessionsBadge,
        ),
        const GlassyNavTab(
          label: 'Security',
          icon: Icons.shield_outlined,
          selectedIcon: Icons.shield_rounded,
        ),
        const GlassyNavTab(
          label: 'Home',
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
          isCenter: true,
        ),
        GlassyNavTab(
          label: 'Schedule',
          icon: Icons.calendar_month_outlined,
          selectedIcon: Icons.calendar_month_rounded,
          badgeCount: scheduleBadge,
        ),
        GlassyNavTab(
          label: 'Messages',
          icon: Icons.chat_bubble_outline_rounded,
          selectedIcon: Icons.chat_bubble_rounded,
          badgeCount: messagesBadge,
        ),
      ],
    );
  }
}
