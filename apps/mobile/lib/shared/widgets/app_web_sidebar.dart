import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/app_providers.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/models/user_role.dart';
import '../../features/agency_platform/agency_platform_constants.dart';
import '../../features/agency_platform/presentation/agency_platform_providers.dart';
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
    this.moduleKey,
  });

  final String label;
  final IconData icon;
  final IconData? selectedIcon;
  final String route;
  final int? badgeCount;
  final bool Function(String location)? isSelected;
  final String? moduleKey;
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
    AppRoutes.callHistory,
    AppRoutes.parentProfile,
  };
  const therapistShared = {
    AppRoutes.messages,
    AppRoutes.notifications,
    AppRoutes.security,
    AppRoutes.payments,
    AppRoutes.documents,
    AppRoutes.telehealth,
    AppRoutes.callHistory,
    AppRoutes.therapistProfile,
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
      label: 'Schedule',
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
      label: 'Calls',
      icon: Icons.call_outlined,
      selectedIcon: Icons.call_rounded,
      route: AppRoutes.callHistory,
      isSelected: (loc) => loc.startsWith(AppRoutes.callHistory),
    ),
    AppWebNavItem(
      label: 'Profile',
      icon: Icons.person_outline,
      selectedIcon: Icons.person_rounded,
      route: AppRoutes.parentProfile,
      isSelected: (loc) =>
          loc.startsWith(AppRoutes.parentProfile) ||
          loc.startsWith(AppRoutes.parentChildren) ||
          loc.startsWith(AppRoutes.parentScreening),
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
              !loc.startsWith(AppRoutes.therapistCharts) &&
              !loc.startsWith(AppRoutes.therapistMarketplace) &&
              !loc.startsWith(AppRoutes.therapistJobOpportunities)),
    ),
    AppWebNavItem(
      label: 'Parent referrals',
      icon: Icons.storefront_outlined,
      selectedIcon: Icons.storefront_rounded,
      route: AppRoutes.therapistMarketplace,
      isSelected: (loc) => loc.startsWith(AppRoutes.therapistMarketplace),
    ),
    AppWebNavItem(
      label: 'Job opportunities',
      icon: Icons.work_outline,
      selectedIcon: Icons.work_rounded,
      route: AppRoutes.therapistJobOpportunities,
      isSelected: (loc) =>
          loc.startsWith(AppRoutes.therapistJobOpportunities),
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
      label: 'Charts',
      icon: Icons.medical_information_outlined,
      selectedIcon: Icons.medical_information_rounded,
      route: AppRoutes.therapistCharts,
      isSelected: (loc) => loc.startsWith(AppRoutes.therapistCharts),
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
      label: 'Calls',
      icon: Icons.call_outlined,
      selectedIcon: Icons.call_rounded,
      route: AppRoutes.callHistory,
      isSelected: (loc) => loc.startsWith(AppRoutes.callHistory),
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

List<AppWebNavItem> billingStaffWebNavItems({required int unreadCount}) {
  return [
    AppWebNavItem(
      label: 'NY EI billing',
      icon: Icons.medical_services_outlined,
      selectedIcon: Icons.medical_services_rounded,
      route: AppRoutes.adminEiBilling,
      isSelected: (loc) => loc.startsWith(AppRoutes.adminEiBilling),
    ),
    AppWebNavItem(
      label: 'Messages',
      icon: Icons.chat_bubble_outline_rounded,
      selectedIcon: Icons.chat_bubble_rounded,
      route: AppRoutes.messages,
      isSelected: (loc) => loc.startsWith(AppRoutes.messages),
    ),
    AppWebNavItem(
      label: 'Notifications',
      icon: Icons.notifications_outlined,
      selectedIcon: Icons.notifications_rounded,
      route: AppRoutes.notifications,
      badgeCount: unreadCount,
      isSelected: (loc) => loc.startsWith(AppRoutes.notifications),
    ),
    AppWebNavItem(
      label: 'Security',
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
      label: 'Users',
      icon: Icons.people_outline,
      selectedIcon: Icons.people_rounded,
      route: '${AppRoutes.adminHome}/users',
      isSelected: (loc) => loc.startsWith('${AppRoutes.adminHome}/users'),
    ),
    AppWebNavItem(
      label: 'Verifications',
      icon: Icons.verified_user_outlined,
      selectedIcon: Icons.verified_user,
      route: '${AppRoutes.adminHome}/verifications',
      isSelected: (loc) =>
          loc.startsWith('${AppRoutes.adminHome}/verifications'),
    ),
    AppWebNavItem(
      label: 'Scheduling',
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month_rounded,
      route: '${AppRoutes.adminHome}/analytics',
      isSelected: (loc) => loc.contains('/analytics'),
    ),
    AppWebNavItem(
      label: 'Messages',
      icon: Icons.chat_bubble_outline_rounded,
      selectedIcon: Icons.chat_bubble_rounded,
      route: AppRoutes.messages,
      isSelected: (loc) => loc.startsWith(AppRoutes.messages),
    ),
    AppWebNavItem(
      label: 'Secure calls',
      icon: Icons.call_outlined,
      selectedIcon: Icons.call_rounded,
      route: AppRoutes.callHistory,
      isSelected: (loc) => loc.startsWith(AppRoutes.callHistory),
    ),
    AppWebNavItem(
      label: 'Billing & claims',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long_rounded,
      route: '${AppRoutes.adminHome}/insurance',
      isSelected: (loc) =>
          loc.startsWith('${AppRoutes.adminHome}/insurance') ||
          loc.startsWith('${AppRoutes.adminHome}/payouts'),
    ),
    AppWebNavItem(
      label: 'NY EI billing',
      icon: Icons.medical_services_outlined,
      selectedIcon: Icons.medical_services_rounded,
      route: AppRoutes.adminEiBilling,
      isSelected: (loc) => loc.startsWith(AppRoutes.adminEiBilling),
    ),
    AppWebNavItem(
      label: 'Parent marketplace',
      icon: Icons.storefront_outlined,
      selectedIcon: Icons.storefront_rounded,
      route: AppRoutes.adminMarketplace,
      isSelected: (loc) =>
          loc == AppRoutes.adminMarketplace ||
          (loc.startsWith('${AppRoutes.adminHome}/marketplace') &&
              !loc.startsWith(AppRoutes.adminMarketplaceAdmin)),
    ),
    AppWebNavItem(
      label: 'Job marketplace admin',
      icon: Icons.work_outline,
      selectedIcon: Icons.work_rounded,
      route: AppRoutes.adminMarketplaceAdmin,
      isSelected: (loc) => loc.startsWith(AppRoutes.adminMarketplaceAdmin),
    ),
    AppWebNavItem(
      label: 'Documents',
      icon: Icons.folder_outlined,
      selectedIcon: Icons.folder_rounded,
      route: AppRoutes.documents,
      isSelected: (loc) => loc.startsWith(AppRoutes.documents),
    ),
    AppWebNavItem(
      label: 'Reports',
      icon: Icons.insights_outlined,
      selectedIcon: Icons.insights_rounded,
      route: '${AppRoutes.adminHome}/analytics',
      isSelected: (loc) => loc.startsWith('${AppRoutes.adminHome}/analytics'),
    ),
    AppWebNavItem(
      label: 'Audit logs',
      icon: Icons.history_outlined,
      selectedIcon: Icons.history_rounded,
      route: '${AppRoutes.adminHome}/audit',
      isSelected: (loc) => loc.startsWith('${AppRoutes.adminHome}/audit'),
    ),
    AppWebNavItem(
      label: 'Complaints',
      icon: Icons.report_outlined,
      selectedIcon: Icons.report_rounded,
      route: '${AppRoutes.adminHome}/complaints',
      isSelected: (loc) => loc.startsWith('${AppRoutes.adminHome}/complaints'),
    ),
    AppWebNavItem(
      label: 'Disputes',
      icon: Icons.gavel_outlined,
      selectedIcon: Icons.gavel_rounded,
      route: '${AppRoutes.adminHome}/disputes',
      isSelected: (loc) => loc.startsWith('${AppRoutes.adminHome}/disputes'),
    ),
    AppWebNavItem(
      label: 'Compliance',
      icon: Icons.policy_outlined,
      selectedIcon: Icons.policy_rounded,
      route: '${AppRoutes.adminHome}/compliance',
      isSelected: (loc) => loc.startsWith('${AppRoutes.adminHome}/compliance'),
    ),
    AppWebNavItem(
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
      route: AppRoutes.security,
      isSelected: (loc) => loc.startsWith(AppRoutes.security),
    ),
    AppWebNavItem(
      label: 'Notifications',
      icon: Icons.notifications_outlined,
      selectedIcon: Icons.notifications_rounded,
      route: AppRoutes.notifications,
      badgeCount: unreadCount,
      isSelected: (loc) => loc.startsWith(AppRoutes.notifications),
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
      label: 'Charts',
      icon: Icons.medical_information_outlined,
      selectedIcon: Icons.medical_information_rounded,
      route: '${AppRoutes.serviceCoordinatorHome}/charts',
      isSelected: (loc) =>
          loc.startsWith('${AppRoutes.serviceCoordinatorHome}/charts'),
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
      label: 'Calls',
      icon: Icons.call_outlined,
      selectedIcon: Icons.call_rounded,
      route: AppRoutes.callHistory,
      isSelected: (loc) => loc.startsWith(AppRoutes.callHistory),
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
      moduleKey: AgencyPlatformModules.dashboard,
      isSelected: (loc) => loc == AppRoutes.agencyHome,
    ),
    AppWebNavItem(
      label: 'Clients',
      icon: Icons.folder_shared_outlined,
      selectedIcon: Icons.folder_shared_rounded,
      route: '${AppRoutes.agencyHome}/charts',
      moduleKey: AgencyPlatformModules.clients,
      isSelected: (loc) =>
          loc.startsWith('${AppRoutes.agencyHome}/charts') ||
          loc.startsWith('${AppRoutes.agencyHome}/cases') ||
          loc.startsWith(AppRoutes.agencyChildren),
    ),
    AppWebNavItem(
      label: 'Providers',
      icon: Icons.groups_outlined,
      selectedIcon: Icons.groups_rounded,
      route: '${AppRoutes.agencyHome}/roster',
      moduleKey: AgencyPlatformModules.providers,
      isSelected: (loc) =>
          loc.startsWith('${AppRoutes.agencyHome}/roster') ||
          loc.startsWith('${AppRoutes.agencyHome}/providers'),
    ),
    AppWebNavItem(
      label: 'Cases',
      icon: Icons.assignment_outlined,
      selectedIcon: Icons.assignment_rounded,
      route: '${AppRoutes.agencyHome}/cases',
      moduleKey: AgencyPlatformModules.serviceCoordination,
      isSelected: (loc) => loc.startsWith('${AppRoutes.agencyHome}/cases'),
    ),
    AppWebNavItem(
      label: 'Scheduling',
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month_rounded,
      route: '${AppRoutes.agencyHome}/appointments',
      moduleKey: AgencyPlatformModules.scheduling,
    ),
    AppWebNavItem(
      label: 'Documents',
      icon: Icons.description_outlined,
      selectedIcon: Icons.description_rounded,
      route: AppRoutes.documents,
      moduleKey: AgencyPlatformModules.documents,
      isSelected: (loc) => loc.startsWith(AppRoutes.documents),
    ),
    AppWebNavItem(
      label: 'Billing',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long_rounded,
      route: AppRoutes.agencyEiBilling,
      moduleKey: AgencyPlatformModules.billing,
      isSelected: (loc) => loc.startsWith(AppRoutes.agencyEiBilling),
    ),
    AppWebNavItem(
      label: 'Session notes',
      icon: Icons.note_alt_outlined,
      selectedIcon: Icons.note_alt_rounded,
      route: '${AppRoutes.agencyHome}/session-notes',
      moduleKey: AgencyPlatformModules.sessionNotes,
      isSelected: (loc) => loc.contains('/session-notes'),
    ),
    AppWebNavItem(
      label: 'Referrals',
      icon: Icons.campaign_outlined,
      selectedIcon: Icons.campaign_rounded,
      route: AppRoutes.agencyReferrals,
      moduleKey: AgencyPlatformModules.referrals,
      isSelected: (loc) => loc.startsWith(AppRoutes.agencyReferrals),
    ),
    AppWebNavItem(
      label: 'Integrations',
      icon: Icons.hub_outlined,
      selectedIcon: Icons.hub_rounded,
      route: AppRoutes.agencyIntegrations,
      moduleKey: AgencyPlatformModules.integrations,
      isSelected: (loc) => loc.startsWith(AppRoutes.agencyIntegrations),
    ),
    AppWebNavItem(
      label: 'Reports',
      icon: Icons.insights_outlined,
      selectedIcon: Icons.insights_rounded,
      route: AppRoutes.agencyReports,
      moduleKey: AgencyPlatformModules.reports,
      isSelected: (loc) => loc.startsWith(AppRoutes.agencyReports),
    ),
    AppWebNavItem(
      label: 'Payroll',
      icon: Icons.payments_outlined,
      selectedIcon: Icons.payments_rounded,
      route: AppRoutes.agencyPayroll,
      moduleKey: AgencyPlatformModules.payroll,
      isSelected: (loc) => loc.startsWith(AppRoutes.agencyPayroll),
    ),
    AppWebNavItem(
      label: 'Admin settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
      route: AppRoutes.agencyAdminSettings,
      moduleKey: AgencyPlatformModules.adminSettings,
      isSelected: (loc) => loc.startsWith(AppRoutes.agencyAdminSettings),
    ),
    AppWebNavItem(
      label: 'Audit logs',
      icon: Icons.history_outlined,
      selectedIcon: Icons.history_rounded,
      route: AppRoutes.agencyAuditLogs,
      moduleKey: AgencyPlatformModules.auditLogs,
      isSelected: (loc) => loc.startsWith(AppRoutes.agencyAuditLogs),
    ),
    AppWebNavItem(
      label: 'Parent referrals',
      icon: Icons.storefront_outlined,
      selectedIcon: Icons.storefront_rounded,
      route: AppRoutes.agencyMarketplace,
      moduleKey: AgencyPlatformModules.referrals,
    ),
    AppWebNavItem(
      label: 'Service needs',
      icon: Icons.medical_services_outlined,
      selectedIcon: Icons.medical_services_rounded,
      route: AppRoutes.agencyServiceNeeds,
      moduleKey: AgencyPlatformModules.clients,
      isSelected: (loc) => loc.startsWith(AppRoutes.agencyServiceNeeds),
    ),
    AppWebNavItem(
      label: 'Job opportunities',
      icon: Icons.work_outline,
      selectedIcon: Icons.work_rounded,
      route: AppRoutes.agencyOpportunities,
      isSelected: (loc) => loc.startsWith(AppRoutes.agencyOpportunities),
    ),
    AppWebNavItem(
      label: 'Profile',
      icon: Icons.person_outline,
      selectedIcon: Icons.person_rounded,
      route: AppRoutes.agencyProfile,
      isSelected: (loc) =>
          loc.startsWith(AppRoutes.agencyProfile) ||
          loc.startsWith(AppRoutes.agencyChildren),
    ),
    AppWebNavItem(
      label: 'Messages',
      icon: Icons.chat_bubble_outline_rounded,
      selectedIcon: Icons.chat_bubble_rounded,
      route: AppRoutes.messages,
    ),
    AppWebNavItem(
      label: 'Calls',
      icon: Icons.call_outlined,
      selectedIcon: Icons.call_rounded,
      route: AppRoutes.callHistory,
      isSelected: (loc) => loc.startsWith(AppRoutes.callHistory),
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
      color: colorScheme.surface,
      child: SizedBox(
        width: AppSpacing.sidebarWidth,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              right: BorderSide(
                color: AppColors.border,
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
    final userRole = ref.watch(authStateProvider).valueOrNull?.user.role;

    if (userRole == UserRole.billing) {
      return billingStaffWebNavItems(unreadCount: unreadCount);
    }

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
        final enabled = ref.watch(agencyEnabledModulesProvider);
        return agencyWebNavItems(unreadCount: unreadCount).where((item) {
          final key = item.moduleKey;
          if (key == null) return true;
          return enabled.contains(key);
        }).toList();
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
