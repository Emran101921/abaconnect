import 'package:flutter/material.dart';

class AdminStatCard extends StatelessWidget {
  const AdminStatCard({
    super.key,
    required this.label,
    required this.value,
    this.periodDelta,
    this.highlight = false,
    this.onTap,
  });

  final String label;
  final Object value;
  final String? periodDelta;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: Theme.of(context).textTheme.headlineMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (periodDelta != null) ...[
            const SizedBox(height: 4),
            Text(
              'vs prior period: $periodDelta',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _deltaColor(context, periodDelta!),
                  ),
            ),
          ],
        ],
      ),
    );

    return SizedBox(
      width: 160,
      child: Card(
        color: highlight
            ? Theme.of(context).colorScheme.primaryContainer
            : null,
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? child
            : InkWell(
                onTap: onTap,
                child: child,
              ),
      ),
    );
  }
}

Color? _deltaColor(BuildContext context, String delta) {
  if (delta == '—') {
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }
  if (delta.startsWith('+')) {
    return Colors.green.shade700;
  }
  if (delta.startsWith('-')) {
    return Colors.red.shade700;
  }
  return Theme.of(context).colorScheme.onSurfaceVariant;
}
