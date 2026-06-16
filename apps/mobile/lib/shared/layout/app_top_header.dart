import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/app_providers.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/notifications/notification_providers.dart';
import '../../shared/models/user_role.dart';
import '../widgets/app_theme_toggle.dart';
import 'action_button.dart';
import 'user_role_badge.dart';
import '../widgets/glossy_button.dart';
import '../widgets/app_web_sidebar.dart';

/// Top header for desktop/tablet — search, notifications, profile, quick actions.
class AppTopHeader extends ConsumerWidget {
  const AppTopHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.showBackButton,
    this.shellRole,
    this.showSearch = true,
    this.showQuickAction = true,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final bool? showBackButton;
  final AppShellRole? shellRole;
  final bool showSearch;
  final bool showQuickAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final canPop = Navigator.of(context).canPop();
    final showBack = showBackButton ?? canPop;
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    final unread = ref.watch(unreadNotificationsProvider);
    final unreadCount = unread.maybeWhen(data: (c) => c, orElse: () => 0);

    return Material(
      color: colorScheme.surface.withValues(alpha: 0.92),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
        ),
        child: SizedBox(
          height: AppSpacing.webHeaderHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                if (showBack) ...[
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                    ],
                  ),
                ),
                if (showSearch) ...[
                  SizedBox(
                    width: 220,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search…',
                        isDense: true,
                        prefixIcon: const Icon(Icons.search, size: 20),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.45),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                      ),
                      onSubmitted: (q) {
                        if (q.trim().isEmpty) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Search for "$q" is coming soon.'),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                if (showQuickAction && shellRole != null)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ActionButton(
                      label: _quickActionLabel(shellRole!),
                      icon: _quickActionIcon(shellRole!),
                      onPressed: () => _quickAction(context, shellRole!),
                      size: GlossyButtonSize.medium,
                      fullWidth: false,
                    ),
                  ),
                if (actions != null) ...actions!,
                const AppThemeToggle(compact: true),
                IconButton(
                  tooltip: 'Notifications',
                  onPressed: () => context.push(AppRoutes.notifications),
                  icon: unreadCount > 0
                      ? Badge(
                          label: Text('$unreadCount'),
                          child: const Icon(Icons.notifications_outlined),
                        )
                      : const Icon(Icons.notifications_outlined),
                ),
                if (user != null)
                  PopupMenuButton<String>(
                    tooltip: 'Account menu',
                    offset: const Offset(0, 44),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor:
                                colorScheme.primary.withValues(alpha: 0.12),
                            child: Icon(
                              Icons.person_outline,
                              size: 18,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          const Icon(Icons.expand_more, size: 18),
                        ],
                      ),
                    ),
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        enabled: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.fullName ?? user.email,
                              style: Theme.of(ctx).textTheme.labelLarge,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            UserRoleBadge(role: user.role, compact: true),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'profile',
                        child: ListTile(
                          leading: Icon(Icons.person_outline),
                          title: Text('Profile & settings'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'security',
                        child: ListTile(
                          leading: Icon(Icons.shield_outlined),
                          title: Text('Security'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'privacy',
                        child: ListTile(
                          leading: Icon(Icons.privacy_tip_outlined),
                          title: Text('Privacy center'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'logout',
                        child: ListTile(
                          leading: Icon(Icons.logout),
                          title: Text('Sign out'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                    onSelected: (value) async {
                      switch (value) {
                        case 'profile':
                          _openProfile(context, user.role);
                        case 'security':
                          context.push(AppRoutes.security);
                        case 'privacy':
                          context.push(AppRoutes.settingsPrivacy);
                        case 'logout':
                          await ref.read(authStateProvider.notifier).logout();
                          if (context.mounted) context.go(AppRoutes.login);
                      }
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _quickActionLabel(AppShellRole role) {
    switch (role) {
      case AppShellRole.parent:
        return 'Start screening';
      case AppShellRole.therapist:
        return 'View marketplace';
      case AppShellRole.agency:
        return 'View referrals';
      case AppShellRole.admin:
        return 'Open analytics';
      case AppShellRole.serviceCoordinator:
        return 'View follow-ups';
    }
  }

  IconData _quickActionIcon(AppShellRole role) {
    switch (role) {
      case AppShellRole.parent:
        return Icons.fact_check_outlined;
      case AppShellRole.therapist:
        return Icons.storefront_outlined;
      case AppShellRole.agency:
        return Icons.map_outlined;
      case AppShellRole.admin:
        return Icons.insights_outlined;
      case AppShellRole.serviceCoordinator:
        return Icons.event_note_outlined;
    }
  }

  void _quickAction(BuildContext context, AppShellRole role) {
    switch (role) {
      case AppShellRole.parent:
        context.push('${AppRoutes.parentScreening}?autoStart=true');
      case AppShellRole.therapist:
        context.push(AppRoutes.therapistMarketplace);
      case AppShellRole.agency:
        context.push(AppRoutes.agencyMarketplace);
      case AppShellRole.admin:
        context.push('${AppRoutes.adminHome}/analytics');
      case AppShellRole.serviceCoordinator:
        context.push('${AppRoutes.serviceCoordinatorHome}/follow-ups');
    }
  }

  void _openProfile(BuildContext context, UserRole role) {
    switch (role) {
      case UserRole.parent:
        context.push(AppRoutes.parentProfile);
      case UserRole.therapist:
        context.push(AppRoutes.therapistProfile);
      default:
        context.push(AppRoutes.security);
    }
  }
}
