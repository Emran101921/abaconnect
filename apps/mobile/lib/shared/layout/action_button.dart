import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../widgets/glossy_button.dart';

/// Consistent CTA buttons across BloomOra — wraps [GlossyButton] with healthcare sizing.
class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.variant = GlossyButtonVariant.primary,
    this.size = GlossyButtonSize.large,
    this.loading = false,
    this.disabled = false,
    this.fullWidth = false,
    this.bordered = false,
    this.semanticLabel,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final GlossyButtonVariant variant;
  final GlossyButtonSize size;
  final bool loading;
  final bool disabled;
  final bool fullWidth;
  final bool bordered;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      enabled: !disabled && onPressed != null,
      child: GlossyButton(
        title: label,
        icon: icon,
        onPressed: disabled ? null : onPressed,
        variant: variant,
        size: size,
        loading: loading,
        disabled: disabled,
        fullWidth: fullWidth,
        bordered: bordered,
        semanticLabel: semanticLabel ?? label,
      ),
    );
  }
}

/// Horizontal row of primary dashboard CTAs with consistent spacing.
class ActionButtonRow extends StatelessWidget {
  const ActionButtonRow({
    super.key,
    required this.buttons,
    this.wrapOnNarrow = true,
  });

  final List<Widget> buttons;
  final bool wrapOnNarrow;

  @override
  Widget build(BuildContext context) {
    if (wrapOnNarrow) {
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: buttons,
      );
    }
    return Row(
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          buttons[i],
        ],
      ],
    );
  }
}
