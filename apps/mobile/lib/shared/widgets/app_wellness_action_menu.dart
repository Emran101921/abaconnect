import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../../../shared/widgets/glossy_button.dart';

class AppWellnessActionItem {
  const AppWellnessActionItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.variant = AppGlossyButtonVariant.primary,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final AppGlossyButtonVariant variant;
}

/// Vertical stack of large glossy action buttons.
class AppWellnessActionMenu extends StatelessWidget {
  const AppWellnessActionMenu({
    super.key,
    required this.items,
    this.spacing = AppSpacing.md,
  });

  final List<AppWellnessActionItem> items;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          AppGlossyButton(
            label: items[i].label,
            icon: items[i].icon,
            variant: items[i].variant,
            onPressed: items[i].onTap,
            iconLeading: true,
            showTrailingIcon: false,
          ),
          if (i < items.length - 1) SizedBox(height: spacing),
        ],
      ],
    );
  }
}
