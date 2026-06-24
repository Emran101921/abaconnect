import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Preset color schemes for [GlossyButton] (semantic roles; rendered iOS-flat).
enum GlossyButtonVariant {
  tealBlue,
  bluePurple,
  orangeRed,
  greenTeal,
  redDarkRed,
  primary,
  secondary,
  tertiary,
  success,
  warning,
  info,
  danger,
  neutral,
}

enum GlossyButtonSize { large, medium, small }

/// Back-compat alias used across home dashboards.
typedef AppGlossyButtonVariant = GlossyButtonVariant;

/// Back-compat alias used across home dashboards.
typedef AppGlossyButtonSize = GlossyButtonSize;

/// iOS-style flat button used across the app (filled, bordered, destructive).
class GlossyButton extends StatefulWidget {
  const GlossyButton({
    super.key,
    String? title,
    String? label,
    this.icon,
    this.onPressed,
    this.variant = GlossyButtonVariant.primary,
    this.gradient,
    this.size = GlossyButtonSize.large,
    this.badgeCount,
    this.disabled = false,
    this.loading = false,
    this.fullWidth = true,
    this.showTrailingIcon = true,
    this.iconLeading = false,
    this.iconOnly = false,
    this.bordered = false,
    this.semanticLabel,
  }) : title = title ?? label ?? '',
       assert(
         iconOnly || title != null || label != null,
         'GlossyButton requires title or label unless iconOnly',
       );

  /// Compact constructor matching legacy dashboard call sites.
  factory GlossyButton.legacy({
    Key? key,
    required String label,
    IconData? icon,
    VoidCallback? onPressed,
    GlossyButtonVariant variant = GlossyButtonVariant.primary,
    GlossyButtonSize size = GlossyButtonSize.large,
    bool showTrailingChevron = true,
    bool expanded = true,
  }) {
    return GlossyButton(
      key: key,
      title: label,
      icon: icon,
      onPressed: onPressed,
      variant: variant,
      size: size,
      showTrailingIcon: showTrailingChevron,
      fullWidth: expanded,
    );
  }

  final String title;
  final IconData? icon;
  final VoidCallback? onPressed;
  final GlossyButtonVariant variant;
  final LinearGradient? gradient;
  final GlossyButtonSize size;
  final int? badgeCount;
  final bool disabled;
  final bool loading;
  final bool fullWidth;
  final bool showTrailingIcon;
  final bool iconLeading;
  final bool iconOnly;
  final bool bordered;
  final String? semanticLabel;

  static GlossyButton startJourney({VoidCallback? onPressed}) => GlossyButton(
    title: 'Start Journey',
    icon: Icons.rocket_launch_rounded,
    onPressed: onPressed,
  );

  static GlossyButton profileSettings({VoidCallback? onPressed}) =>
      GlossyButton(
        title: 'Profile Settings',
        icon: Icons.person_rounded,
        onPressed: onPressed,
      );

  static GlossyButton notifications({
    VoidCallback? onPressed,
    int badgeCount = 0,
  }) => GlossyButton(
    title: 'Notifications',
    icon: Icons.notifications_rounded,
    badgeCount: badgeCount > 0 ? badgeCount : null,
    onPressed: onPressed,
  );

  static GlossyButton exploreNow({VoidCallback? onPressed}) => GlossyButton(
    title: 'Explore Now',
    icon: Icons.explore_rounded,
    variant: GlossyButtonVariant.success,
    onPressed: onPressed,
  );

  static GlossyButton logOut({VoidCallback? onPressed}) => GlossyButton(
    title: 'Log Out',
    icon: Icons.logout_rounded,
    variant: GlossyButtonVariant.danger,
    onPressed: onPressed,
  );

  @override
  State<GlossyButton> createState() => _GlossyButtonState();
}

class _IosButtonAppearance {
  const _IosButtonAppearance({
    required this.background,
    required this.foreground,
    required this.pressedOpacity,
    this.border,
  });

  final Color background;
  final Color foreground;
  final Border? border;
  final double pressedOpacity;
}

class _GlossyButtonState extends State<GlossyButton> {
  bool _pressed = false;

  bool get _isEnabled =>
      !widget.disabled && !widget.loading && widget.onPressed != null;

  static const _radius = AppSpacing.radiusMd;

  double get _height => switch (widget.size) {
    GlossyButtonSize.large => 50,
    GlossyButtonSize.medium => 44,
    GlossyButtonSize.small => 36,
  };

  double get _fontSize => switch (widget.size) {
    GlossyButtonSize.large => 17,
    GlossyButtonSize.medium => 15,
    GlossyButtonSize.small => 13,
  };

  double get _iconSize => switch (widget.size) {
    GlossyButtonSize.large => 20,
    GlossyButtonSize.medium => 18,
    GlossyButtonSize.small => 16,
  };

  _IosButtonAppearance _appearance(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.bordered) {
      return _IosButtonAppearance(
        background: Colors.transparent,
        foreground: AppColors.primary,
        border: Border.all(color: AppColors.border, width: 1),
        pressedOpacity: 0.55,
      );
    }

    final (Color bg, Color fg) = switch (widget.variant) {
      GlossyButtonVariant.neutral => isDark
          ? (const Color(0xFF334155), const Color(0xFFF8FAFC))
          : (const Color(0xFFF1F5F9), AppColors.textPrimary),
      GlossyButtonVariant.danger ||
      GlossyButtonVariant.redDarkRed => (AppColors.error, Colors.white),
      GlossyButtonVariant.success ||
      GlossyButtonVariant.greenTeal => (AppColors.success, Colors.white),
      GlossyButtonVariant.warning ||
      GlossyButtonVariant.orangeRed => (AppColors.warning, Colors.white),
      GlossyButtonVariant.secondary ||
      GlossyButtonVariant.tealBlue => (AppColors.secondary, Colors.white),
      GlossyButtonVariant.tertiary ||
      GlossyButtonVariant.bluePurple => (AppColors.primaryDark, Colors.white),
      _ => (AppColors.primary, Colors.white),
    };

    return _IosButtonAppearance(
      background: bg,
      foreground: fg,
      pressedOpacity: 0.55,
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = _appearance(context);
    final opacity = !_isEnabled
        ? 0.4
        : _pressed
        ? style.pressedOpacity
        : 1.0;

    final showIcon = widget.icon != null &&
        (widget.iconOnly || widget.iconLeading || widget.showTrailingIcon);

    final button = Semantics(
      button: true,
      enabled: _isEnabled,
      label: widget.semanticLabel ?? widget.title,
      child: AnimatedOpacity(
        opacity: opacity,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _isEnabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: _isEnabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: _isEnabled ? () => setState(() => _pressed = false) : null,
          onTap: _isEnabled
              ? () {
                  HapticFeedback.selectionClick();
                  widget.onPressed!();
                }
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: widget.iconOnly ? _height : null,
            height: _height,
            decoration: BoxDecoration(
              color: style.background,
              borderRadius: BorderRadius.circular(
                widget.iconOnly ? _height / 2 : _radius,
              ),
              border: style.border,
            ),
            child: Padding(
              padding: widget.iconOnly
                  ? EdgeInsets.zero
                  : EdgeInsets.symmetric(
                      horizontal: widget.size == GlossyButtonSize.small
                          ? AppSpacing.md
                          : AppSpacing.lg,
                    ),
              child: widget.iconOnly && widget.icon != null
                  ? Center(
                      child: Icon(
                        widget.icon,
                        size: _iconSize + 2,
                        color: style.foreground,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize:
                          widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
                      children: [
                        if (widget.loading) ...[
                          SizedBox(
                            width: _fontSize + 2,
                            height: _fontSize + 2,
                            child: CupertinoActivityIndicator(
                              radius: _fontSize / 2,
                              color: style.foreground,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (showIcon && widget.iconLeading) ...[
                          _ButtonIcon(
                            icon: widget.icon!,
                            color: style.foreground,
                            size: _iconSize,
                            badgeCount: widget.badgeCount,
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (!widget.iconOnly)
                          widget.fullWidth
                              ? Expanded(
                                  child: Text(
                                    widget.title,
                                    textAlign: widget.iconLeading
                                        ? TextAlign.start
                                        : TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: style.foreground,
                                      fontSize: _fontSize,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.2,
                                      height: 1.2,
                                    ),
                                  ),
                                )
                              : Text(
                                  widget.title,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: style.foreground,
                                    fontSize: _fontSize,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.2,
                                    height: 1.2,
                                  ),
                                ),
                        if (showIcon && !widget.iconLeading) ...[
                          const SizedBox(width: 6),
                          _ButtonIcon(
                            icon: widget.icon!,
                            color: style.foreground,
                            size: _iconSize,
                            badgeCount: widget.badgeCount,
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );

    if (widget.fullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

class _ButtonIcon extends StatelessWidget {
  const _ButtonIcon({
    required this.icon,
    required this.color,
    required this.size,
    this.badgeCount,
  });

  final IconData icon;
  final Color color;
  final double size;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, size: size, color: color);

    if (badgeCount == null || badgeCount! <= 0) {
      return iconWidget;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        iconWidget,
        Positioned(
          right: -8,
          top: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: CupertinoColors.systemRed.resolveFrom(context),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              badgeCount! > 99 ? '99+' : '$badgeCount',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Drop-in iOS-style replacement for Material [FilledButton].
class GlossyFilledButton extends StatelessWidget {
  const GlossyFilledButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
    this.variant = GlossyButtonVariant.primary,
    this.size = GlossyButtonSize.medium,
    this.fullWidth = false,
  });

  const GlossyFilledButton.icon({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.child,
    this.variant = GlossyButtonVariant.primary,
    this.size = GlossyButtonSize.medium,
    this.fullWidth = false,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final IconData? icon;
  final GlossyButtonVariant variant;
  final GlossyButtonSize size;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final label = child is Text ? (child as Text).data ?? '' : child.toString();
    return GlossyButton(
      title: label,
      icon: icon,
      onPressed: onPressed,
      variant: variant,
      size: size,
      fullWidth: fullWidth,
      iconLeading: icon != null,
      showTrailingIcon: false,
    );
  }
}

/// iOS bordered secondary action — replaces Material [OutlinedButton].
class GlossyOutlinedButton extends StatelessWidget {
  const GlossyOutlinedButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.size = GlossyButtonSize.medium,
    this.fullWidth = false,
    this.icon,
  });

  const GlossyOutlinedButton.icon({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.child,
    this.size = GlossyButtonSize.medium,
    this.fullWidth = false,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final IconData? icon;
  final GlossyButtonSize size;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final label = child is Text ? (child as Text).data ?? '' : child.toString();
    return GlossyButton(
      title: label,
      icon: icon,
      onPressed: onPressed,
      size: size,
      fullWidth: fullWidth,
      bordered: true,
      iconLeading: icon != null,
      showTrailingIcon: false,
    );
  }
}

/// iOS-style floating action — replaces Material [FloatingActionButton].
class GlossyFab extends StatelessWidget {
  const GlossyFab({
    super.key,
    required this.onPressed,
    required this.icon,
    this.label,
    this.variant = GlossyButtonVariant.primary,
    this.tooltip,
  });

  const GlossyFab.extended({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.variant = GlossyButtonVariant.primary,
    this.tooltip,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String? label;
  final GlossyButtonVariant variant;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    if (label != null && label!.isNotEmpty) {
      return GlossyButton(
        title: label!,
        icon: icon,
        onPressed: onPressed,
        variant: variant,
        size: GlossyButtonSize.medium,
        fullWidth: false,
        iconLeading: true,
        showTrailingIcon: false,
        semanticLabel: tooltip ?? label,
      );
    }

    final fab = GlossyButton(
      title: tooltip ?? 'Action',
      icon: icon,
      onPressed: onPressed,
      variant: variant,
      size: GlossyButtonSize.large,
      fullWidth: false,
      iconOnly: true,
      semanticLabel: tooltip,
    );

    if (tooltip == null) return fab;
    return Tooltip(message: tooltip!, child: fab);
  }
}

/// Back-compat export — existing screens import [AppGlossyButton].
typedef AppGlossyButton = GlossyButton;
