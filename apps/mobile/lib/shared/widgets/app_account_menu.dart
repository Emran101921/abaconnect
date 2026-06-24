import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/app_providers.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/models/user_role.dart';
import '../layout/user_role_badge.dart';

/// Shared account menu — profile, security, privacy, sign out.
class AppAccountMenuButton extends ConsumerWidget {
  const AppAccountMenuButton({super.key, this.compact = false});

  /// Compact icon-only trigger for mobile AppBar actions.
  final bool compact;

  static void openProfile(BuildContext context, UserRole role) {
    switch (role) {
      case UserRole.parent:
        context.push(AppRoutes.parentProfile);
      case UserRole.therapist:
        context.push(AppRoutes.therapistProfile);
      case UserRole.agency:
        context.push(AppRoutes.agencyProfile);
      default:
        context.push(AppRoutes.security);
    }
  }

  static Future<void> handleSelection(
    BuildContext context,
    WidgetRef ref,
    String value,
    UserRole role,
  ) async {
    switch (value) {
      case 'profile':
        openProfile(context, role);
      case 'security':
        context.push(AppRoutes.security);
      case 'privacy':
        context.push(AppRoutes.settingsPrivacy);
      case 'logout':
        await ref.read(authStateProvider.notifier).logout();
        if (context.mounted) context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    if (user == null) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      tooltip: 'Account menu',
      offset: const Offset(0, 44),
      child: compact
          ? CircleAvatar(
              radius: 16,
              backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
              child: Icon(
                Icons.person_outline,
                size: 18,
                color: colorScheme.primary,
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
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
      onSelected: (value) =>
          handleSelection(context, ref, value, user.role),
    );
  }
}
