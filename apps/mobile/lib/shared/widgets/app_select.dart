import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_spacing.dart';

/// One selectable row in [AppSelectField], [AppSelectMultiField], or [AppSelect.show].
class AppSelectOption<T> {
  const AppSelectOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.leading,
    this.enabled = true,
  });

  final T value;
  final String label;
  final String? subtitle;
  final Widget? leading;
  final bool enabled;
}

/// Scrollable anchored selection toolkit — no page jump, keyboard-friendly.
abstract final class AppSelect {
  static const double defaultMaxHeight = 280;

  /// Imperative single-select (replaces SimpleDialog pickers).
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required List<AppSelectOption<T>> options,
    T? selected,
    String? searchHint,
    double maxHeight = defaultMaxHeight,
    GlobalKey? anchorKey,
  }) {
    return _AppSelectOverlay.show<T>(
      context: context,
      title: title,
      options: options,
      selected: selected != null ? {selected} : {},
      multiSelect: false,
      searchHint: searchHint,
      maxHeight: maxHeight,
      anchorKey: anchorKey,
    ).then((set) => set == null || set.isEmpty ? null : set.first);
  }

  /// Imperative multi-select with Done action.
  static Future<Set<T>?> showMulti<T>({
    required BuildContext context,
    required String title,
    required List<AppSelectOption<T>> options,
    Set<T> selected = const {},
    String? searchHint,
    double maxHeight = defaultMaxHeight,
    GlobalKey? anchorKey,
  }) {
    return _AppSelectOverlay.show<T>(
      context: context,
      title: title,
      options: options,
      selected: selected,
      multiSelect: true,
      searchHint: searchHint,
      maxHeight: maxHeight,
      anchorKey: anchorKey,
    );
  }
}

/// Single-select form field — opens anchored scrollable list at tap position.
class AppSelectField<T> extends StatefulWidget {
  const AppSelectField({
    super.key,
    required this.options,
    this.value,
    this.onChanged,
    this.label,
    this.hint,
    this.prefixIcon,
    this.enabled = true,
    this.maxHeight = AppSelect.defaultMaxHeight,
    this.searchHint,
  });

  final List<AppSelectOption<T>> options;
  final T? value;
  final ValueChanged<T?>? onChanged;
  final String? label;
  final String? hint;
  final Widget? prefixIcon;
  final bool enabled;
  final double maxHeight;
  final String? searchHint;

  @override
  State<AppSelectField<T>> createState() => _AppSelectFieldState<T>();
}

class _AppSelectFieldState<T> extends State<AppSelectField<T>> {
  final _anchorKey = GlobalKey();

  String get _displayLabel {
    if (widget.value == null) return widget.hint ?? 'Select…';
    for (final o in widget.options) {
      if (o.value == widget.value) return o.label;
    }
    return widget.hint ?? 'Select…';
  }

  Future<void> _open() async {
    if (!widget.enabled || widget.options.isEmpty) return;
    final picked = await _AppSelectOverlay.show<T>(
      context: context,
      title: widget.label ?? 'Select',
      options: widget.options,
      selected: widget.value != null ? {widget.value as T} : {},
      multiSelect: false,
      searchHint: widget.searchHint,
      maxHeight: widget.maxHeight,
      anchorKey: _anchorKey,
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    widget.onChanged?.call(picked.first);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasValue = widget.value != null;

    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: '${widget.label ?? 'Selection'}, $_displayLabel',
      child: KeyedSubtree(
        key: _anchorKey,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.enabled ? _open : null,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: widget.label,
                hintText: widget.hint,
                prefixIcon: widget.prefixIcon,
                suffixIcon: Icon(
                  Icons.unfold_more_rounded,
                  color: widget.enabled
                      ? scheme.onSurfaceVariant
                      : scheme.onSurface.withValues(alpha: 0.38),
                ),
                enabled: widget.enabled,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _displayLabel,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: hasValue
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Multi-select form field — list stays open while toggling options.
class AppSelectMultiField<T> extends StatefulWidget {
  const AppSelectMultiField({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.label,
    this.hint,
    this.prefixIcon,
    this.enabled = true,
    this.maxHeight = AppSelect.defaultMaxHeight,
    this.searchHint,
  });

  final List<AppSelectOption<T>> options;
  final Set<T> selected;
  final ValueChanged<Set<T>> onChanged;
  final String? label;
  final String? hint;
  final Widget? prefixIcon;
  final bool enabled;
  final double maxHeight;
  final String? searchHint;

  @override
  State<AppSelectMultiField<T>> createState() => _AppSelectMultiFieldState<T>();
}

class _AppSelectMultiFieldState<T> extends State<AppSelectMultiField<T>> {
  final _anchorKey = GlobalKey();

  String get _displayLabel {
    if (widget.selected.isEmpty) return widget.hint ?? 'Select…';
    final labels = <String>[];
    for (final o in widget.options) {
      if (widget.selected.contains(o.value)) labels.add(o.label);
    }
    return labels.join(', ');
  }

  Future<void> _open() async {
    if (!widget.enabled) return;
    final picked = await _AppSelectOverlay.show<T>(
      context: context,
      title: widget.label ?? 'Select',
      options: widget.options,
      selected: widget.selected,
      multiSelect: true,
      searchHint: widget.searchHint,
      maxHeight: widget.maxHeight,
      anchorKey: _anchorKey,
    );
    if (picked == null || !mounted) return;
    widget.onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      enabled: widget.enabled,
      child: KeyedSubtree(
        key: _anchorKey,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.enabled ? _open : null,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: widget.label,
                hintText: widget.hint,
                prefixIcon: widget.prefixIcon,
                suffixIcon: const Icon(Icons.unfold_more_rounded),
                enabled: widget.enabled,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.selected.isEmpty)
                    Text(
                      _displayLabel,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final o in widget.options)
                          if (widget.selected.contains(o.value))
                            Chip(
                              label: Text(o.label),
                              visualDensity: VisualDensity.compact,
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: widget.enabled
                                  ? () {
                                      final next = Set<T>.from(widget.selected)
                                        ..remove(o.value);
                                      widget.onChanged(next);
                                    }
                                  : null,
                            ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppSelectOverlay<T> extends StatefulWidget {
  const _AppSelectOverlay({
    required this.title,
    required this.options,
    required this.selected,
    required this.multiSelect,
    required this.maxHeight,
    required this.anchorRect,
    required this.onClose,
    this.searchHint,
  });

  final String title;
  final List<AppSelectOption<T>> options;
  final Set<T> selected;
  final bool multiSelect;
  final double maxHeight;
  final Rect? anchorRect;
  final void Function(Set<T>? result) onClose;
  final String? searchHint;

  static Future<Set<T>?> show<T>({
    required BuildContext context,
    required String title,
    required List<AppSelectOption<T>> options,
    required Set<T> selected,
    required bool multiSelect,
    double maxHeight = AppSelect.defaultMaxHeight,
    GlobalKey? anchorKey,
    String? searchHint,
  }) {
    final overlay = Overlay.of(context);
    final renderBox = anchorKey?.currentContext?.findRenderObject() as RenderBox?;
    Rect? anchorRect;
    if (renderBox != null && renderBox.hasSize) {
      final offset = renderBox.localToGlobal(Offset.zero);
      anchorRect = offset & renderBox.size;
    }

    final completer = Completer<Set<T>?>();
    late OverlayEntry entry;

    void close(Set<T>? result) {
      entry.remove();
      if (!completer.isCompleted) completer.complete(result);
    }

    entry = OverlayEntry(
      builder: (ctx) => _AppSelectOverlay<T>(
        title: title,
        options: options,
        selected: Set<T>.from(selected),
        multiSelect: multiSelect,
        maxHeight: maxHeight,
        anchorRect: anchorRect,
        searchHint: searchHint,
        onClose: close,
      ),
    );

    overlay.insert(entry);
    return completer.future;
  }

  @override
  State<_AppSelectOverlay<T>> createState() => _AppSelectOverlayState<T>();
}

class _AppSelectOverlayState<T> extends State<_AppSelectOverlay<T>> {
  late Set<T> _selected;
  late List<AppSelectOption<T>> _filtered;
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  int _highlightIndex = 0;

  @override
  void initState() {
    super.initState();
    _selected = Set<T>.from(widget.selected);
    _filtered = widget.options;
    _syncHighlightToSelection();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _syncHighlightToSelection() {
    if (_filtered.isEmpty) {
      _highlightIndex = 0;
      return;
    }
    if (!widget.multiSelect && _selected.isNotEmpty) {
      final idx = _filtered.indexWhere((o) => _selected.contains(o.value));
      if (idx >= 0) _highlightIndex = idx;
    }
    _highlightIndex = _highlightIndex.clamp(0, _filtered.length - 1);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _applySearch(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.options
          : widget.options
                .where(
                  (o) =>
                      o.label.toLowerCase().contains(q) ||
                      (o.subtitle?.toLowerCase().contains(q) ?? false),
                )
                .toList();
      _highlightIndex = 0;
    });
  }

  void _toggle(AppSelectOption<T> option) {
    if (!option.enabled) return;
    setState(() {
      if (widget.multiSelect) {
        if (_selected.contains(option.value)) {
          _selected.remove(option.value);
        } else {
          _selected.add(option.value);
        }
      } else {
        _selected = {option.value};
      }
    });
    if (!widget.multiSelect) {
      widget.onClose(_selected);
    }
  }

  void _done() => widget.onClose(_selected);

  void _cancel() => widget.onClose(null);

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_filtered.isEmpty) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _cancel();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _highlightIndex = (_highlightIndex + 1).clamp(0, _filtered.length - 1);
      });
      _scrollToHighlight();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _highlightIndex = (_highlightIndex - 1).clamp(0, _filtered.length - 1);
      });
      _scrollToHighlight();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      _toggle(_filtered[_highlightIndex]);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _cancel();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _scrollToHighlight() {
    if (!_scrollController.hasClients) return;
    const itemExtent = 56.0;
    final target = _highlightIndex * itemExtent;
    final max = _scrollController.position.maxScrollExtent;
    _scrollController.animateTo(
      target.clamp(0, max),
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final scheme = Theme.of(context).colorScheme;
    final screen = media.size;
    final anchor = widget.anchorRect;

    double left;
    double width;
    double top;
    double maxH;

    if (anchor != null) {
      left = anchor.left.clamp(8.0, screen.width - anchor.width - 8);
      width = anchor.width.clamp(200.0, screen.width - 16);
      final spaceBelow = screen.height - anchor.bottom - media.padding.bottom;
      final spaceAbove = anchor.top - media.padding.top;
      final openDown = spaceBelow >= 160 || spaceBelow >= spaceAbove;
      maxH = widget.maxHeight.clamp(120, openDown ? spaceBelow - 8 : spaceAbove - 8);
      top = openDown ? anchor.bottom + 4 : anchor.top - maxH - 4;
    } else {
      left = 16;
      width = screen.width - 32;
      maxH = widget.maxHeight.clamp(120, screen.height * 0.55);
      top = (screen.height - maxH) / 2;
    }

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _cancel,
              behavior: HitTestBehavior.opaque,
              child: const ColoredBox(color: Color(0x33000000)),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            width: width,
            child: Focus(
              focusNode: _focusNode,
              onKeyEvent: _onKey,
              child: Material(
                elevation: 8,
                shadowColor: scheme.shadow.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                color: scheme.surface,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxH),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.title,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              tooltip: 'Close',
                              onPressed: _cancel,
                            ),
                          ],
                        ),
                      ),
                      if (widget.searchHint != null &&
                          widget.options.length > 6) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: widget.searchHint,
                              prefixIcon: const Icon(Icons.search, size: 20),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 10,
                              ),
                            ),
                            onChanged: _applySearch,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Flexible(
                        child: NotificationListener<ScrollNotification>(
                          onNotification: (_) => true,
                          child: ScrollConfiguration(
                            behavior: ScrollConfiguration.of(context).copyWith(
                              scrollbars: true,
                            ),
                            child: ListView.separated(
                              controller: _scrollController,
                              shrinkWrap: true,
                              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                              itemCount: _filtered.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 2),
                              itemBuilder: (context, index) {
                                final option = _filtered[index];
                                final isSelected =
                                    _selected.contains(option.value);
                                final highlighted = index == _highlightIndex;

                                return _AppSelectOptionRow(
                                  label: option.label,
                                  subtitle: option.subtitle,
                                  leading: option.leading,
                                  selected: isSelected,
                                  highlighted: highlighted,
                                  enabled: option.enabled,
                                  multiSelect: widget.multiSelect,
                                  onTap: () {
                                    setState(() => _highlightIndex = index);
                                    _toggle(option);
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      if (widget.multiSelect)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                          child: FilledButton(
                            onPressed: _done,
                            child: Text(
                              _selected.isEmpty
                                  ? 'Done'
                                  : 'Done (${_selected.length})',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppSelectOptionRow extends StatelessWidget {
  const _AppSelectOptionRow({
    required this.label,
    required this.selected,
    required this.highlighted,
    required this.onTap,
    required this.multiSelect,
    this.subtitle,
    this.leading,
    this.enabled = true,
  });

  final String label;
  final String? subtitle;
  final Widget? leading;
  final bool selected;
  final bool highlighted;
  final bool enabled;
  final bool multiSelect;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = selected
        ? scheme.primaryContainer
        : highlighted
        ? scheme.surfaceContainerHighest
        : Colors.transparent;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              if (multiSelect)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    selected
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    size: 22,
                    color: selected
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                  ),
                )
              else if (leading != null) ...[
                leading!,
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: enabled
                            ? scheme.onSurface
                            : scheme.onSurface.withValues(alpha: 0.38),
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (!multiSelect && selected)
                Icon(Icons.check_rounded, color: scheme.primary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
