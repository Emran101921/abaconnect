import 'package:flutter/material.dart';

import '../models/analytics_metric.dart';

class AnalyticsListHeader extends StatelessWidget {
  const AnalyticsListHeader({
    super.key,
    required this.count,
    required this.priorCount,
    this.amountLabel,
  });

  final int count;
  final int priorCount;
  final String? amountLabel;

  @override
  Widget build(BuildContext context) {
    final delta = formatCountPeriodDelta(count, priorCount);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$count in selected range',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(
            'vs prior period: $delta',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (amountLabel != null) ...[
            const SizedBox(height: 4),
            Text(amountLabel!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
