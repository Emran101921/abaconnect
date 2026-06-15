import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Tab descriptor for [GlassyBottomNav].
class GlassyNavTab {
  const GlassyNavTab({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.badgeCount,
    this.isCenter = false,
    this.semanticLabel,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final int? badgeCount;
  final bool isCenter;
  final String? semanticLabel;
}

/// iOS-style tab bar with blur background, system blue selection, and labels.
class GlassyBottomNav extends StatelessWidget {
  const GlassyBottomNav({
    super.key,
    required this.activeTab,
    required this.onTabPress,
    required this.tabs,
    this.smallButtonSize = 52,
    this.centerButtonSize = 72,
  }) : assert(tabs.length >= 3, 'GlassyBottomNav needs at least 3 tabs');

  final int activeTab;
  final ValueChanged<int> onTabPress;
  final List<GlassyNavTab> tabs;
  final double smallButtonSize;
  final double centerButtonSize;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barColor = isDark
        ? const Color(0xCC1C1C1E)
        : const Color(0xF2F9F9F9);
    final borderColor = isDark
        ? CupertinoColors.separator.darkColor
        : CupertinoColors.separator.color;

    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: borderColor, width: 0.5)),
        ),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: ColoredBox(
              color: barColor,
              child: Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 2),
                child: Row(
                  children: [
                    for (var i = 0; i < tabs.length; i++)
                      Expanded(
                        child: _IosTabItem(
                          tab: tabs[i],
                          selected: activeTab == i,
                          onTap: () => onTabPress(i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IosTabItem extends StatefulWidget {
  const _IosTabItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final GlassyNavTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_IosTabItem> createState() => _IosTabItemState();
}

class _IosTabItemState extends State<_IosTabItem> {
  bool _pressed = false;

  String _accessibilityLabel(GlassyNavTab tab) {
    final base = tab.semanticLabel ?? tab.label;
    final count = tab.badgeCount;
    if (count == null || count <= 0) return base;
    final suffix = count == 1 ? '1 notification' : '$count notifications';
    return '$base, $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final activeColor = CupertinoColors.activeBlue.resolveFrom(context);
    final inactiveColor = CupertinoColors.inactiveGray.resolveFrom(context);
    final color = selected ? activeColor : inactiveColor;
    final opacity = _pressed ? 0.55 : 1.0;

    return Semantics(
      button: true,
      selected: selected,
      label: _accessibilityLabel(widget.tab),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: AnimatedOpacity(
          opacity: opacity,
          duration: const Duration(milliseconds: 100),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _TabIcon(
                  icon: selected ? widget.tab.selectedIcon : widget.tab.icon,
                  color: color,
                  badgeCount: widget.tab.badgeCount,
                  emphasized: widget.tab.isCenter && selected,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.tab.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabIcon extends StatelessWidget {
  const _TabIcon({
    required this.icon,
    required this.color,
    this.badgeCount,
    this.emphasized = false,
  });

  final IconData icon;
  final Color color;
  final int? badgeCount;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(
      icon,
      size: emphasized ? 28 : 24,
      color: color,
    );

    if (badgeCount == null || badgeCount! <= 0) {
      return iconWidget;
    }

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        iconWidget,
        Positioned(
          right: -10,
          top: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: CupertinoColors.systemRed.resolveFrom(context),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              badgeCount! > 9 ? '9+' : '$badgeCount',
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
