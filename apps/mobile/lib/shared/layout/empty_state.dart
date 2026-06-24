import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import 'action_button.dart';
import '../widgets/glossy_button.dart';

/// Calm empty state for lists and dashboards — guides users to the next action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      container: true,
      label: '$title. ${message ?? ''}',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 40,
                    color: colorScheme.primary,
                    semanticLabel: '',
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (message != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                  ),
                ],
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  ActionButton(
                    label: actionLabel!,
                    onPressed: onAction,
                    fullWidth: true,
                  ),
                ],
                if (secondaryActionLabel != null && onSecondaryAction != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  ActionButton(
                    label: secondaryActionLabel!,
                    onPressed: onSecondaryAction,
                    variant: GlossyButtonVariant.neutral,
                    bordered: true,
                    fullWidth: true,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
