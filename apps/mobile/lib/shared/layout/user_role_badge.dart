import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../shared/models/user_role.dart';

/// Displays the signed-in user's role with healthcare-appropriate styling.
class UserRoleBadge extends StatelessWidget {
  const UserRoleBadge({
    super.key,
    required this.role,
    this.compact = false,
  });

  final UserRole role;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (icon, color) = _styleForRole(role, colorScheme);

    return Semantics(
      label: 'Role: ${role.displayName}',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpacing.sm : AppSpacing.md,
          vertical: compact ? AppSpacing.xs : AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 14 : 16, color: color),
            const SizedBox(width: AppSpacing.xs),
            Text(
              role.displayName,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  (IconData, Color) _styleForRole(UserRole role, ColorScheme scheme) {
    switch (role) {
      case UserRole.parent:
        return (Icons.family_restroom_outlined, scheme.primary);
      case UserRole.therapist:
        return (Icons.medical_services_outlined, scheme.secondary);
      case UserRole.agency:
      case UserRole.departmentAdmin:
        return (Icons.business_outlined, scheme.tertiary);
      case UserRole.payroll:
        return (Icons.payments_outlined, scheme.tertiary);
      case UserRole.serviceCoordinator:
        return (Icons.support_agent_outlined, scheme.primary);
      case UserRole.admin:
      case UserRole.billing:
      case UserRole.complianceAuditor:
      case UserRole.support:
        return (Icons.admin_panel_settings_outlined, scheme.error);
    }
  }
}
