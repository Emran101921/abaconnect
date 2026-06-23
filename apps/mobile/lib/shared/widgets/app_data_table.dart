import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';
import '../widgets/app_status_badge.dart';

class AppDataColumn<T> {
  const AppDataColumn({
    required this.label,
    required this.cellBuilder,
    this.flex = 1,
    this.mobilePriority = false,
  });

  final String label;
  final Widget Function(BuildContext context, T row) cellBuilder;
  final int flex;
  final bool mobilePriority;
}

/// Professional data table with search, mobile card fallback, and status support.
class AppDataTable<T> extends StatefulWidget {
  const AppDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.searchHint = 'Search…',
    this.searchPredicate,
    this.emptyMessage = 'No records found',
    this.onRowTap,
    this.actionsBuilder,
    this.showSearch = true,
  });

  final List<AppDataColumn<T>> columns;
  final List<T> rows;
  final String searchHint;
  final bool Function(T row, String query)? searchPredicate;
  final String emptyMessage;
  final void Function(T row)? onRowTap;
  final Widget Function(BuildContext context, T row)? actionsBuilder;
  final bool showSearch;

  @override
  State<AppDataTable<T>> createState() => _AppDataTableState<T>();
}

class _AppDataTableState<T> extends State<AppDataTable<T>> {
  String _query = '';

  List<T> get _filtered {
    if (_query.isEmpty || widget.searchPredicate == null) return widget.rows;
    return widget.rows
        .where((row) => widget.searchPredicate!(row, _query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= AppSpacing.breakpointWide;
    final rows = _filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showSearch && widget.searchPredicate != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: TextField(
              decoration: InputDecoration(
                hintText: widget.searchHint,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
            child: Center(
              child: Text(
                widget.emptyMessage,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          )
        else if (wide)
          _DesktopTable<T>(
            columns: widget.columns,
            rows: rows,
            onRowTap: widget.onRowTap,
            actionsBuilder: widget.actionsBuilder,
          )
        else
          _MobileList<T>(
            columns: widget.columns,
            rows: rows,
            onRowTap: widget.onRowTap,
            actionsBuilder: widget.actionsBuilder,
          ),
      ],
    );
  }
}

class _DesktopTable<T> extends StatelessWidget {
  const _DesktopTable({
    required this.columns,
    required this.rows,
    this.onRowTap,
    this.actionsBuilder,
  });

  final List<AppDataColumn<T>> columns;
  final List<T> rows;
  final void Function(T row)? onRowTap;
  final Widget Function(BuildContext context, T row)? actionsBuilder;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            child: Row(
              children: [
                for (final col in columns)
                  Expanded(
                    flex: col.flex,
                    child: Text(
                      col.label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                if (actionsBuilder != null)
                  const SizedBox(width: 48),
              ],
            ),
          ),
          for (var i = 0; i < rows.length; i++)
            InkWell(
              onTap: onRowTap == null ? null : () => onRowTap!(rows[i]),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    for (final col in columns)
                      Expanded(
                        flex: col.flex,
                        child: col.cellBuilder(context, rows[i]),
                      ),
                    if (actionsBuilder != null)
                      actionsBuilder!(context, rows[i]),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MobileList<T> extends StatelessWidget {
  const _MobileList({
    required this.columns,
    required this.rows,
    this.onRowTap,
    this.actionsBuilder,
  });

  final List<AppDataColumn<T>> columns;
  final List<T> rows;
  final void Function(T row)? onRowTap;
  final Widget Function(BuildContext context, T row)? actionsBuilder;

  @override
  Widget build(BuildContext context) {
    final priority = columns.where((c) => c.mobilePriority).toList();
    final displayCols = priority.isNotEmpty ? priority : columns.take(2).toList();

    return Column(
      children: [
        for (final row in rows)
          Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: InkWell(
              onTap: onRowTap == null ? null : () => onRowTap!(row),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < displayCols.length; i++) ...[
                      if (i > 0) const SizedBox(height: AppSpacing.xs),
                      Text(
                        displayCols[i].label,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      displayCols[i].cellBuilder(context, row),
                    ],
                    if (actionsBuilder != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: Alignment.centerRight,
                        child: actionsBuilder!(context, row),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Helper for status cells in [AppDataTable].
Widget appTableStatusCell(String label, AppStatusKind kind) =>
    AppStatusBadge.fromKind(kind, label: label);
