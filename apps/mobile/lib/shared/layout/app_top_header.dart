import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/notifications/notification_providers.dart';
import '../widgets/app_account_menu.dart';
import '../widgets/app_theme_toggle.dart';
import 'action_button.dart';
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
                      onSubmitted: (q) => _onSearchSubmitted(context, q.trim()),
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
                const AppAccountMenuButton(),
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

  void _onSearchSubmitted(BuildContext context, String query) {
    if (query.isEmpty) return;
    final role = shellRole;
    if (role == null) return;

    switch (role) {
      case AppShellRole.parent:
        final normalized = query.toLowerCase();
        if (RegExp(r'marketplace|service request|anonymous request')
            .hasMatch(normalized)) {
          context.push(AppRoutes.parentMarketplace);
          return;
        }
        if (RegExp(r'\bappointment|session|schedule\b').hasMatch(normalized)) {
          context.push('${AppRoutes.parentHome}/appointments');
          return;
        }
        if (RegExp(r'\bmessage|chat\b').hasMatch(normalized)) {
          context.push(AppRoutes.messages);
          return;
        }
        final therapyTypes = _parentTherapyTypesFromQuery(query);
        if (therapyTypes.isEmpty) {
          context.push(AppRoutes.matching);
        } else {
          context.push(
            '${AppRoutes.matching}?therapyTypes=${therapyTypes.join(',')}',
          );
        }
      case AppShellRole.therapist:
        final normalized = query.toLowerCase();
        if (RegExp(r'\bapplication|applied\b').hasMatch(normalized)) {
          context.push(
            '${AppRoutes.therapistJobApplications}?q=${Uri.encodeComponent(query)}',
          );
          return;
        }
        final zip = RegExp(r'^\d{5}$').hasMatch(query) ? query : null;
        final q = zip == null ? query : null;
        final params = <String>[
          if (q != null) 'q=${Uri.encodeComponent(q)}',
          if (zip != null) 'zip=$zip',
        ];
        final uri = params.isEmpty
            ? AppRoutes.therapistJobOpportunities
            : '${AppRoutes.therapistJobOpportunities}?${params.join('&')}';
        context.push(uri);
      case AppShellRole.agency:
        context.push(
          '${AppRoutes.agencyOpportunities}?q=${Uri.encodeComponent(query)}',
        );
      case AppShellRole.admin:
        _routeAdminSearch(context, query);
      case AppShellRole.serviceCoordinator:
        context.push(
          '${AppRoutes.serviceCoordinatorHome}/follow-ups?q=${Uri.encodeComponent(query)}',
        );
    }
  }

  void _routeAdminSearch(BuildContext context, String query) {
    final normalized = query.toLowerCase();
    if (RegExp(r'\bjob\b|staffing|opportunit|applicant').hasMatch(normalized)) {
      context.push(
        '${AppRoutes.adminMarketplaceAdmin}?q=${Uri.encodeComponent(query)}',
      );
      return;
    }
    if (RegExp(r'\bei\b|medicaid|claim|billing').hasMatch(normalized)) {
      context.push(AppRoutes.adminEiBilling);
      return;
    }
    if (RegExp(r'\bcomplaint|support|dispute').hasMatch(normalized)) {
      context.push('${AppRoutes.adminHome}/complaints');
      return;
    }
    if (RegExp(r'\bmarketplace|listing|provider request').hasMatch(normalized)) {
      context.push(AppRoutes.adminMarketplace);
      return;
    }
    if (RegExp(r'\baudit|compliance|hipaa').hasMatch(normalized)) {
      context.push('${AppRoutes.adminHome}/audit');
      return;
    }
    context.push(
      '${AppRoutes.adminHome}/users?q=${Uri.encodeComponent(query)}',
    );
  }

  List<String> _parentTherapyTypesFromQuery(String query) {
    final normalized = query.toLowerCase();
    final types = <String>{};

    if (RegExp(r'\baba\b|applied behavior').hasMatch(normalized)) {
      types.add('ABA');
    }
    if (RegExp(r'\bspeech\b|slp\b|language therapy').hasMatch(normalized)) {
      types.add('SPEECH');
    }
    if (RegExp(r'\bot\b|occupational').hasMatch(normalized)) {
      types.add('OCCUPATIONAL');
    }
    if (RegExp(r'\bpt\b|physical therapy').hasMatch(normalized)) {
      types.add('PHYSICAL');
    }
    if (RegExp(r'early intervention|\bei\b').hasMatch(normalized)) {
      types.add('EARLY_INTERVENTION');
    }

    return types.toList();
  }
}
