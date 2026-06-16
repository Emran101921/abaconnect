import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/app_providers.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/models/user_role.dart';
import '../../features/notifications/notification_providers.dart';
import '../../features/parent/presentation/parent_dashboard_providers.dart';
import '../providers/bottom_nav_badge_providers.dart';
import 'app_brand_logo.dart';

enum AppShellRole { parent, therapist, admin, agency, serviceCoordinator }

class AppWebNavItem {
  const AppWebNavItem({
    required this.label,
    required this.icon,
    required this.route,
    this.selectedIcon,
    this.badgeCount,
    this.isSelected,
  });

  final String label;
  final IconData icon;
  final IconData? selectedIcon;
  final String route;
  final int? badgeCount;
  final bool Function(String location)? isSelected;
}

AppShellRole? inferAppShellRole({
  required String location,
  UserRole? userRole,
}) {
  if (location.startsWith(AppRoutes.parentHome)) return AppShellRole.parent;
  if (location.startsWith(AppRoutes.therapistHome)) {
    return AppShellRole.therapist;
  }
  if (location.startsWith(AppRoutes.adminHome)) return AppShellRole.admin;
  if (location.startsWith(AppRoutes.agencyHome)) return AppShellRole.agency;
  if (location.startsWith(AppRoutes.serviceCoordinatorHome)) {
    return AppShellRole.serviceCoordinator;
  }

  const parentShared = {
    AppRoutes.messages,
    AppRoutes.notifications,
    AppRoutes.security,
    AppRoutes.payments,
    AppRoutes.documents,
    AppRoutes.insurance,
    AppRoutes.consent,
    AppRoutes.telehealth,
    AppRoutes.matching,
  };
  const therapistShared = {
    AppRoutes.messages,
    AppRoutes.notifications,
    AppRoutes.security,
    AppRoutes.payments,
    AppRoutes.documents,
    AppRoutes.telehealth,
  };

  if (userRole == UserRole.parent && parentShared.contains(location)) {
    return AppShellRole.parent;
  }
  if (userRole == UserRole.therapist && therapistShared.contains(location)) {
    return AppShellRole.therapist;
  }
  if (userRole == UserRole.agency &&
      (location == AppRoutes.messages || location == AppRoutes.notifications)) {
    return AppShellRole.agency;
  }
  if (userRole == UserRole.serviceCoordinator &&
      (location == AppRoutes.messages ||
          location == AppRoutes.notifications ||
          location == AppRoutes.security ||
          location == AppRoutes.consent)) {
    return AppShellRole.serviceCoordinator;
  }
  if (userRole == UserRole.admin && location == AppRoutes.notifications) {
    return AppShellRole.admin;
  }
  return null;
}

bool _routeMatches(String location, String route) {
  if (route == AppRoutes.parentHome ||
      route == AppRoutes.therapistHome ||
      route == AppRoutes.adminHome ||
      route == AppRoutes.agencyHome ||
      route == AppRoutes.serviceCoordinatorHome) {
    return location == route;
  }
  return location == route || location.startsWith('$route/');
}

List<AppWebNavItem> parentWebNavItems({
  required int? homeBadge,
  required int? messagesBadge,
  required String location,
}) {
  return [
    AppWebNavItem(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      route: AppRoutes.parentHome,
      badgeCount: homeBadge,
      isSelected: (loc) =>
          loc == AppRoutes.parentHome ||
          (loc.startsWith('${AppRoutes.parentHome}/') &&
              !loc.startsWith(AppRoutes.parentChildren) &&
              !loc.startsWith(AppRoutes.parentScreening) &&
              !loc.startsWith(AppRoutes.parentMarketplace) &&
              !loc.startsWith(AppRoutes.parentAppointments)),
    ),
    AppWebNavItem(
      label: 'Children',
      icon: Icons.child_care_outlined,
      selectedIcon: Icons.child_care_rounded,
      route: AppRoutes.parentChildren,
      isSelected: (loc) => loc.startsWith(AppRoutes.parentChildren),
    ),
    AppWebNavItem(
      label: 'Screening',
      icon: Icons.fact_check_outlined,
      selectedIcon: Icons.fact_check_rounded,
      route: AppRoutes.parentScreening,
      isSelected: (loc) => loc.startsWith(AppRoutes.parentScreening),
    ),
    AppWebNavItem(
      label: 'Marketplace',
      icon: Icons.storefront_outlined,
      selectedIcon: Icons.storefront_rounded,
      route: AppRoutes.parentMarketplace,
      isSelected: (loc) => loc.startsWith(AppRoutes.parentMarketplace),
    ),
    AppWebNavItem(
      label: 'Appointments',
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month_rounded,
      route: AppRoutes.parentAppointments,
      isSelected: (loc) => loc.startsWith(AppRoutes.parentAppointments),
    ),
    AppWebNavItem(
      label: 'Messages',
      icon: Icons.chat_bubble_outline_rounded,
      selectedIcon: Icons.chat_bubble_rounded,
      route: AppRoutes.messages,
      badgeCount: messagesBadge,
      isSelected: (loc) => loc.startsWith(AppRoutes.messages),
    ),
    AppWebNavItem(
      label: 'Documents',
      icon: Icons.folder_outlined,
      selectedIcon: Icons.folder_rounded,
      route: AppRoutes.documents,
      isSelected: (loc) => loc.startsWith(AppRoutes.documents),
    ),
    AppWebNavItem(
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
      route: AppRoutes.security,
      isSelected: (loc) =>
          loc.startsWith(AppRoutes.security) ||
          loc.startsWith(AppRoutes.settingsPrivacy),
    ),
  ];
}

List<AppWebNavItem> therapistWebNavItems({
  required int? scheduleBadge,
  required int? sessionsBadge,
  required int? messagesBadge,
}) {
  return [
    AppWebNavItem(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      route: AppRoutes.therapistHome,
      isSelected: (loc) =>
          loc == AppRoutes.therapistHome ||
          (loc.startsWith('${AppRoutes.therapistHome}/') &&
              !loc.startsWith(AppRoutes.therapistAppointments) &&
              !loc.startsWith(AppRoutes.therapistSessionNotes) &&
              !loc.startsWith(AppRoutes.therapistMarketplace)),
    ),
    AppWebNavItem(
      label: 'Marketplace',
      icon: Icons.storefront_outlined,
      selectedIcon: Icons.storefront_rounded,
      route: AppRoutes.therapistMarketplace,
      isSelected: (loc) => loc.startsWith(AppRoutes.therapistMarketplace),
    ),
    AppWebNavItem(
      label: 'Schedule',
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month_rounded,
      route: AppRoutes.therapistAppointments,
      badgeCount: scheduleBadge,
      isSelected: (loc) => loc.startsWith(AppRoutes.therapistAppointments),
    ),
    AppWebNavItem(
      label: 'Sessions',
      icon: Icons.edit_note_outlined,
      selectedIcon: Icons.edit_note_rounded,
      route: AppRoutes.therapistSessionNotes,
      badgeCount: sessionsBadge,
      isSelected: (loc) => loc.startsWith(AppRoutes.therapistSessionNotes),
    ),
    AppWebNavItem(
      label: 'Messages',
      icon: Icons.chat_bubble_outline_rounded,
      selectedIcon: Icons.chat_bubble_rounded,
      route: AppRoutes.messages,
      badgeCount: messagesBadge,
      isSelected: (loc) => loc.startsWith(AppRoutes.messages),
    ),
    AppWebNavItem(
      label: 'Profile',
      icon: Icons.person_outline,
      selectedIcon: Icons.person_rounded,
      route: AppRoutes.therapistProfile,
      isSelected: (loc) => loc.startsWith(AppRoutes.therapistProfile),
    ),
    AppWebNavItem(
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
      route: AppRoutes.security,
      isSelected: (loc) => loc.startsWith(AppRoutes.security),
    ),
  ];
}

List<AppWebNavItem> adminWebNavItems({required int unreadCount}) {
  return [
    AppWebNavItem(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard_rounded,
      route: AppRoutes.adminHome,
      isSelected: (loc) => loc == AppRoutes.adminHome,
    ),
    AppWebNavItem(
      label: 'Verifications',
      icon: Icons.verified_user_outlined,
      selectedIcon: Icons.verified_user,
      route: '${AppRoutes.adminHome}/verifications',
    ),
    AppWebNavItem(
      label: 'Complaints',
      icon: Icons.report_outlined,
      selectedIcon: Icons.report_rounded,
      route: '${AppRoutes.adminHome}/complaints',
    ),
    AppWebNavItem(
      label: 'Disputes',
      icon: Icons.gavel_outlined,
      selectedIcon: Icons.gavel_rounded,
      route: '${AppRoutes.adminHome}/disputes',
    ),
    AppWebNavItem(
      label: 'Users',
      icon: Icons.people_outline,
      selectedIcon: Icons.people_rounded,
      route: '${AppRoutes.adminHome}/users',
    ),
    AppWebNavItem(
      label: 'Analytics',
      icon: Icons.insights_outlined,
      selectedIcon: Icons.insights_rounded,
      route: '${AppRoutes.adminHome}/analytics',
    ),
    AppWebNavItem(
      label: 'Compliance',
      icon: Icons.policy_outlined,
      selectedIcon: Icons.policy_rounded,
      route: '${AppRoutes.adminHome}/compliance',
    ),
    AppWebNavItem(
      label: 'Marketplace',
      icon: Icons.storefront_outlined,
      selectedIcon: Icons.storefront_rounded,
      route: AppRoutes.adminMarketplace,
    ),
    AppWebNavItem(
      label: 'Notifications',
      icon: Icons.notifications_outlined,
      selectedIcon: Icons.notifications_rounded,
      route: AppRoutes.notifications,
      badgeCount: unreadCount,
    ),
  ];
}

List<AppWebNavItem> serviceCoordinatorWebNavItems({required int unreadCount}) {
  return [
    AppWebNavItem(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard_rounded,
      route: AppRoutes.serviceCoordinatorHome,
      isSelected: (loc) => loc == AppRoutes.serviceCoordinatorHome,
    ),
    AppWebNavItem(
      label: 'Cases',
      icon: Icons.folder_shared_outlined,
      selectedIcon: Icons.folder_shared_rounded,
      route: '${AppRoutes.serviceCoordinatorHome}/cases',
      isSelected: (loc) => loc.startsWith('${AppRoutes.serviceCoordinatorHome}/cases'),
    ),
    AppWebNavItem(
      label: 'Follow-ups',
      icon: Icons.event_note_outlined,
      selectedIcon: Icons.event_note_rounded,
      route: '${AppRoutes.serviceCoordinatorHome}/follow-ups',
      isSelected: (loc) =>
          loc.startsWith('${AppRoutes.serviceCoordinatorHome}/follow-ups'),
    ),
    AppWebNavItem(
      label: 'Messages',
      icon: Icons.message_outlined,
      selectedIcon: Icons.message_rounded,
      route: AppRoutes.messages,
    ),
    AppWebNavItem(
      label: 'Notifications',
      icon: Icons.notifications_outlined,
      selectedIcon: Icons.notifications_rounded,
      route: AppRoutes.notifications,
      badgeCount: unreadCount,
    ),
  ];
}

List<AppWebNavItem> agencyWebNavItems({required int unreadCount}) {
  return [
    AppWebNavItem(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard_rounded,
      route: AppRoutes.agencyHome,
      isSelected: (loc) => loc == AppRoutes.agencyHome,
    ),
    AppWebNavItem(
      label: 'Roster',
      icon: Icons.groups_outlined,
      selectedIcon: Icons.groups_rounded,
      route: '${AppRoutes.agencyHome}/roster',
    ),
    AppWebNavItem(
      label: 'Appointments',
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month_rounded,
      route: '${AppRoutes.agencyHome}/appointments',
    ),
    AppWebNavItem(
      label: 'Analytics',
      icon: Icons.insights_outlined,
      selectedIcon: Icons.insights_rounded,
      route: '${AppRoutes.agencyHome}/analytics',
    ),
    AppWebNavItem(
      label: 'Marketplace',
      icon: Icons.storefront_outlined,
      selectedIcon: Icons.storefront_rounded,
      route: AppRoutes.agencyMarketplace,
    ),
    AppWebNavItem(
      label: 'Messages',
      icon: Icons.chat_bubble_outline_rounded,
      selectedIcon: Icons.chat_bubble_rounded,
      route: AppRoutes.messages,
    ),
    AppWebNavItem(
      label: 'Notifications',
      icon: Icons.notifications_outlined,
      selectedIcon: Icons.notifications_rounded,
      route: AppRoutes.notifications,
      badgeCount: unreadCount,
    ),
  ];
}

class AppWebSidebar extends ConsumerWidget {
  const AppWebSidebar({
    super.key,
    required this.role,
    required this.location,
  });

  final AppShellRole role;
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final items = _itemsForRole(ref);
    final user = ref.watch(authStateProvider).valueOrNull?.user;

    return Material(
      color: colorScheme.surface.withValues(alpha: 0.88),
      child: SizedBox(
        width: AppSpacing.sidebarWidth,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colorScheme.surface,
                colorScheme.primaryContainer.withValues(alpha: 0.08),
              ],
            ),
            border: Border(
              right: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.55),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(4, 0),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: const AppBrandLogo(size: AppBrandLogoSize.small),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  children: [
                    for (final item in items)
                      _SidebarTile(
                        item: item,
                        selected: item.isSelected?.call(location) ??
                            _routeMatches(location, item.route),
                        onTap: () => _onNavTap(context, ref, item),
                      ),
                  ],
                ),
              ),
              if (user != null)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        backgroundColor:
                            colorScheme.primary.withValues(alpha: 0.12),
                        child: Icon(
                          Icons.person_outline,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        user.fullName ?? user.email.split('@').first,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      subtitle: Text(
                        user.role.displayName,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<AppWebNavItem> _itemsForRole(WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsProvider);
    final unreadCount = unread.maybeWhen(data: (c) => c, orElse: () => 0);

    switch (role) {
      case AppShellRole.parent:
        return parentWebNavItems(
          homeBadge: ref.watch(parentHomeNavBadgeProvider),
          messagesBadge: ref.watch(parentMessagesNavBadgeProvider),
          location: location,
        );
      case AppShellRole.therapist:
        return therapistWebNavItems(
          scheduleBadge: ref.watch(therapistScheduleNavBadgeProvider),
          sessionsBadge: ref.watch(therapistSessionsNavBadgeProvider),
          messagesBadge: ref.watch(therapistMessagesNavBadgeProvider),
        );
      case AppShellRole.admin:
        return adminWebNavItems(unreadCount: unreadCount);
      case AppShellRole.agency:
        return agencyWebNavItems(unreadCount: unreadCount);
      case AppShellRole.serviceCoordinator:
        return serviceCoordinatorWebNavItems(unreadCount: unreadCount);
    }
  }

  void _onNavTap(BuildContext context, WidgetRef ref, AppWebNavItem item) {
    if (role == AppShellRole.parent && item.route == AppRoutes.parentHome) {
      ref.invalidate(parentDashboardProvider);
      ref.invalidate(unreadNotificationsProvider);
    }
    context.go(item.route);
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppWebNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final icon = selected ? (item.selectedIcon ?? item.icon) : item.icon;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: selected
            ? colorScheme.primaryContainer.withValues(alpha: 0.55)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            child: Row(
              children: [
                Badge(
                  isLabelVisible:
                      item.badgeCount != null && item.badgeCount! > 0,
                  label: Text('${item.badgeCount}'),
                  child: Icon(
                    icon,
                    size: 22,
                    color: selected
                        ? AppColors.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    item.label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: selected
                              ? colorScheme.onSurface
                              : colorScheme.onSurfaceVariant,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w500,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
