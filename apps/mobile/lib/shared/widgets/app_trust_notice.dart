import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Subtle HIPAA / security reassurance — use sparingly on auth and sensitive views.
class AppTrustNotice extends StatelessWidget {
  const AppTrustNotice({
    super.key,
    this.message = 'Secure HIPAA-aware communication',
    this.icon = Icons.shield_outlined,
    this.dense = false,
  });

  const AppTrustNotice.protectedInfo({super.key, this.dense = false})
      : message = 'Only authorized users can access this information',
        icon = Icons.lock_outline;

  const AppTrustNotice.dataProtected({super.key, this.dense = false})
      : message = 'Your information is protected',
        icon = Icons.verified_user_outlined;

  final String message;
  final IconData icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label: message,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: dense ? AppSpacing.sm : AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: dense ? 18 : 20, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
