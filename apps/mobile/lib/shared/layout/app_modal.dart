import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import 'action_button.dart';
import '../widgets/glossy_button.dart';

/// Confirmation modal for important healthcare actions.
class AppModal {
  AppModal._();

  static Future<bool?> confirm({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    GlossyButtonVariant confirmVariant = GlossyButtonVariant.primary,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        title: Text(title),
        content: Text(
          message,
          style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(height: 1.45),
        ),
        actions: [
          ActionButton(
            label: cancelLabel,
            onPressed: () => Navigator.of(ctx).pop(false),
            variant: GlossyButtonVariant.neutral,
            bordered: true,
            fullWidth: false,
            size: GlossyButtonSize.medium,
          ),
          ActionButton(
            label: confirmLabel,
            onPressed: () => Navigator.of(ctx).pop(true),
            variant: destructive
                ? GlossyButtonVariant.danger
                : confirmVariant,
            fullWidth: false,
            size: GlossyButtonSize.medium,
          ),
        ],
      ),
    );
  }
}
