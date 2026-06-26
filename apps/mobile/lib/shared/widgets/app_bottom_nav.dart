import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/app_providers.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/notifications/notification_providers.dart';
import '../../features/parent/presentation/parent_dashboard_providers.dart';
import '../../shared/models/user_role.dart';
import '../providers/bottom_nav_badge_providers.dart';
import 'glassy_bottom_nav.dart';

/// Unified mobile bottom navigation: Home · Schedule · Messages · Calls · Profile
enum CoreNavTab { home, schedule, messages, calls, profile }

@Deprecated('Use CoreNavTab')
typedef ParentNavTab = CoreNavTab;

@Deprecated('Use CoreNavTab')
typedef TherapistNavTab = CoreNavTab;

@Deprecated('Use RoleBottomNav')
typedef ParentBottomNav = RoleBottomNav;

@Deprecated('Use RoleBottomNav')
typedef TherapistBottomNav = RoleBottomNav;

class RoleBottomNav extends ConsumerWidget {
  const RoleBottomNav({super.key, required this.current});

  final CoreNavTab current;

  static String homeRoute(UserRole role) => role.homeRoute;

  static String scheduleRoute(UserRole role) {
    switch (role) {
      case UserRole.parent:
        return AppRoutes.parentAppointments;
      case UserRole.therapist:
        return AppRoutes.therapistAppointments;
      case UserRole.agency:
      case UserRole.departmentAdmin:
      case UserRole.payroll:
        return '${AppRoutes.agencyHome}/appointments';
      case UserRole.serviceCoordinator:
        return '${AppRoutes.serviceCoordinatorHome}/cases';
      case UserRole.admin:
      case UserRole.billing:
      case UserRole.complianceAuditor:
      case UserRole.support:
        return '${AppRoutes.adminHome}/analytics';
    }
  }

  static String profileRoute(UserRole role) {
    switch (role) {
      case UserRole.parent:
        return AppRoutes.parentProfile;
      case UserRole.therapist:
        return AppRoutes.therapistProfile;
      case UserRole.agency:
      case UserRole.departmentAdmin:
      case UserRole.payroll:
        return AppRoutes.agencyProfile;
      case UserRole.serviceCoordinator:
      case UserRole.admin:
      case UserRole.billing:
      case UserRole.complianceAuditor:
      case UserRole.support:
        return AppRoutes.security;
    }
  }

  void _go(BuildContext context, WidgetRef ref, CoreNavTab tab) {
    final role = ref.read(authStateProvider).valueOrNull?.user.role;
    if (role == null) return;
    if (tab == current && tab != CoreNavTab.home) return;

    switch (tab) {
      case CoreNavTab.home:
        if (tab == current) return;
        if (role == UserRole.parent) {
          ref.invalidate(parentDashboardProvider);
          ref.invalidate(unreadNotificationsProvider);
        }
        context.go(homeRoute(role));
      case CoreNavTab.schedule:
        context.go(scheduleRoute(role));
      case CoreNavTab.messages:
        context.go(AppRoutes.messages);
      case CoreNavTab.calls:
        context.go(AppRoutes.callHistory);
      case CoreNavTab.profile:
        context.go(profileRoute(role));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authStateProvider).valueOrNull?.user.role;
    if (role == null) return const SizedBox.shrink();

    final messagesBadge = switch (role) {
      UserRole.parent => ref.watch(parentMessagesNavBadgeProvider),
      UserRole.therapist => ref.watch(therapistMessagesNavBadgeProvider),
      _ => null,
    };
    final homeBadge = role == UserRole.parent
        ? ref.watch(parentHomeNavBadgeProvider)
        : null;
    final scheduleBadge = role == UserRole.therapist
        ? ref.watch(therapistScheduleNavBadgeProvider)
        : null;

    return GlassyBottomNav(
      activeTab: current.index,
      onTabPress: (index) => _go(context, ref, CoreNavTab.values[index]),
      tabs: [
        GlassyNavTab(
          label: 'Home',
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
          isCenter: true,
          badgeCount: homeBadge,
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
        const GlassyNavTab(
          label: 'Calls',
          icon: Icons.call_outlined,
          selectedIcon: Icons.call_rounded,
        ),
        const GlassyNavTab(
          label: 'Profile',
          icon: Icons.person_outline,
          selectedIcon: Icons.person_rounded,
        ),
      ],
    );
  }
}

/// Auto bottom nav on mobile for role shells that forgot to pass one.
class AutoRoleBottomNav extends ConsumerWidget {
  const AutoRoleBottomNav({super.key, required this.location});

  final String location;

  CoreNavTab? _tabForLocation(UserRole role) {
    if (location == RoleBottomNav.homeRoute(role) ||
        (location.startsWith('${RoleBottomNav.homeRoute(role)}/') &&
            !_isNestedRoute(location, role))) {
      return CoreNavTab.home;
    }
    if (location.startsWith(RoleBottomNav.scheduleRoute(role))) {
      return CoreNavTab.schedule;
    }
    if (location.startsWith(AppRoutes.messages)) return CoreNavTab.messages;
    if (location.startsWith(AppRoutes.callHistory) ||
        location.startsWith('/active-call') ||
        location.startsWith('/incoming-call')) {
      return CoreNavTab.calls;
    }
    if (location.startsWith(AppRoutes.notifications)) {
      return CoreNavTab.home;
    }
    if (location.startsWith(AppRoutes.payments) ||
        location.startsWith(AppRoutes.consent) ||
        location.startsWith(AppRoutes.insurance) ||
        location.startsWith(AppRoutes.documents) ||
        location.startsWith(AppRoutes.parentProfile) ||
        location.startsWith(AppRoutes.therapistProfile) ||
        location.startsWith(AppRoutes.agencyProfile)) {
      return CoreNavTab.profile;
    }
    if (location.startsWith(AppRoutes.telehealth)) {
      return CoreNavTab.schedule;
    }
    if (location.startsWith(RoleBottomNav.profileRoute(role)) ||
        location.startsWith(AppRoutes.security) ||
        location.startsWith(AppRoutes.agencyProfile) ||
        location.startsWith(AppRoutes.agencyChildren) ||
        location.startsWith(AppRoutes.parentChildren) ||
        location.startsWith(AppRoutes.parentScreening)) {
      return CoreNavTab.profile;
    }
    return null;
  }

  bool _isNestedRoute(String location, UserRole role) {
    const nested = [
      AppRoutes.parentAppointments,
      AppRoutes.parentProfile,
      AppRoutes.therapistAppointments,
      AppRoutes.therapistProfile,
      AppRoutes.therapistSessionNotes,
      AppRoutes.therapistCharts,
    ];
    return nested.any((r) => location.startsWith(r));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= AppSpacing.breakpointWide) return const SizedBox.shrink();

    final role = ref.watch(authStateProvider).valueOrNull?.user.role;
    if (role == null) return const SizedBox.shrink();

    final tab = _tabForLocation(role);
    if (tab == null) return const SizedBox.shrink();
    return RoleBottomNav(current: tab);
  }
}
