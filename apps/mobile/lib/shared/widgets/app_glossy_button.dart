import 'package:flutter/material.dart';

import '../../core/theme/app_glossy_gradients.dart';
import '../../core/theme/app_spacing.dart';

enum AppGlossyButtonVariant {
  primary,
  secondary,
  tertiary,
  success,
  warning,
  info,
  neutral,
}

enum AppGlossyButtonSize { large, medium, small }

/// Glossy 3D extruded button matching the wellness dashboard reference.
class AppGlossyButton extends StatefulWidget {
  const AppGlossyButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.variant = AppGlossyButtonVariant.primary,
    this.size = AppGlossyButtonSize.large,
    this.showTrailingChevron = true,
    this.expanded = true,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final AppGlossyButtonVariant variant;
  final AppGlossyButtonSize size;
  final bool showTrailingChevron;
  final bool expanded;

  @override
  State<AppGlossyButton> createState() => _AppGlossyButtonState();
}

class _AppGlossyButtonState extends State<AppGlossyButton> {
  bool _pressed = false;

  LinearGradient get _gradient {
    switch (widget.variant) {
      case AppGlossyButtonVariant.primary:
        return AppGlossyGradients.primary;
      case AppGlossyButtonVariant.secondary:
        return AppGlossyGradients.secondary;
      case AppGlossyButtonVariant.tertiary:
        return AppGlossyGradients.tertiary;
      case AppGlossyButtonVariant.success:
        return AppGlossyGradients.success;
      case AppGlossyButtonVariant.warning:
        return AppGlossyGradients.warning;
      case AppGlossyButtonVariant.info:
        return AppGlossyGradients.info;
      case AppGlossyButtonVariant.neutral:
        return AppGlossyGradients.neutral;
    }
  }

  double get _height {
    switch (widget.size) {
      case AppGlossyButtonSize.large:
        return 64;
      case AppGlossyButtonSize.medium:
        return 52;
      case AppGlossyButtonSize.small:
        return 44;
    }
  }

  double get _radius {
    switch (widget.size) {
      case AppGlossyButtonSize.large:
        return AppSpacing.radiusXl;
      case AppGlossyButtonSize.medium:
        return AppSpacing.radiusLg;
      case AppGlossyButtonSize.small:
        return AppSpacing.radiusMd;
    }
  }

  TextStyle _labelStyle(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final isNeutral = widget.variant == AppGlossyButtonVariant.neutral;
    final color = isNeutral ? const Color(0xFF334155) : Colors.white;
    switch (widget.size) {
      case AppGlossyButtonSize.large:
        return theme.titleMedium!.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        );
      case AppGlossyButtonSize.medium:
        return theme.titleSmall!.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        );
      case AppGlossyButtonSize.small:
        return theme.labelLarge!.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradient = _gradient;
    final baseColor = AppGlossyGradients.baseShadowColor(gradient);
    final depth = _pressed ? 2.0 : 6.0;
    final topOffset = _pressed ? 4.0 : 0.0;

    final button = GestureDetector(
      onTapDown: widget.onPressed == null
          ? null
          : (_) => setState(() => _pressed = true),
      onTapUp: widget.onPressed == null
          ? null
          : (_) => setState(() => _pressed = false),
      onTapCancel: widget.onPressed == null
          ? null
          : () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        height: _height + depth,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: _height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(_radius),
                  boxShadow: [
                    BoxShadow(
                      color: baseColor.withValues(alpha: 0.45),
                      blurRadius: 12,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              left: 0,
              right: 0,
              top: topOffset,
              height: _height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(_radius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.35),
                      blurRadius: 0,
                      offset: const Offset(0, -1),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_radius),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: _height * 0.45,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(
                                  alpha: widget.variant ==
                                          AppGlossyButtonVariant.neutral
                                      ? 0.55
                                      : 0.28,
                                ),
                                Colors.white.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: widget.size == AppGlossyButtonSize.small
                              ? AppSpacing.md
                              : AppSpacing.lg,
                        ),
                        child: Row(
                          children: [
                            if (widget.icon != null) ...[
                              _IconChip(
                                icon: widget.icon!,
                                variant: widget.variant,
                                size: widget.size,
                              ),
                              SizedBox(
                                width: widget.size == AppGlossyButtonSize.small
                                    ? AppSpacing.sm
                                    : AppSpacing.md,
                              ),
                            ],
                            Expanded(
                              child: Text(
                                widget.label,
                                style: _labelStyle(context),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (widget.showTrailingChevron &&
                                widget.size != AppGlossyButtonSize.small)
                              Icon(
                                Icons.chevron_right_rounded,
                                color: widget.variant ==
                                        AppGlossyButtonVariant.neutral
                                    ? const Color(0xFF64748B)
                                    : Colors.white.withValues(alpha: 0.9),
                                size: widget.size == AppGlossyButtonSize.large
                                    ? 28
                                    : 22,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.expanded) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({
    required this.icon,
    required this.variant,
    required this.size,
  });

  final IconData icon;
  final AppGlossyButtonVariant variant;
  final AppGlossyButtonSize size;

  @override
  Widget build(BuildContext context) {
    final isNeutral = variant == AppGlossyButtonVariant.neutral;
    final chipSize = size == AppGlossyButtonSize.large ? 40.0 : 32.0;
    final iconSize = size == AppGlossyButtonSize.large ? 22.0 : 18.0;

    return Container(
      width: chipSize,
      height: chipSize,
      decoration: BoxDecoration(
        color: isNeutral
            ? Colors.white.withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: Colors.white.withValues(alpha: isNeutral ? 0.5 : 0.35),
        ),
      ),
      child: Icon(
        icon,
        size: iconSize,
        color: isNeutral ? const Color(0xFF475569) : Colors.white,
      ),
    );
  }
}
