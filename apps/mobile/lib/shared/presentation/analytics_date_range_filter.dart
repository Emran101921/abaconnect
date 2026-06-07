import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/analytics_date_range.dart';

class AnalyticsDateRangeBar extends ConsumerWidget {
  const AnalyticsDateRangeBar({
    super.key,
    required this.dateRangeProvider,
  });

  final StateProvider<AnalyticsDateRange> dateRangeProvider;

  Future<void> _pickRange(BuildContext context, WidgetRef ref) async {
    final current = ref.read(dateRangeProvider);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: current.from != null && current.to != null
          ? DateTimeRange(start: current.from!, end: current.to!)
          : null,
    );
    if (picked != null) {
      ref.read(dateRangeProvider.notifier).state = AnalyticsDateRange(
        from: picked.start,
        to: picked.end,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(dateRangeProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.date_range, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    range.label,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                if (range.isActive)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    tooltip: 'Clear date range',
                    onPressed: () {
                      ref.read(dateRangeProvider.notifier).state =
                          const AnalyticsDateRange();
                    },
                  ),
                TextButton(
                  onPressed: () => _pickRange(context, ref),
                  child: Text(range.isActive ? 'Change' : 'Set range'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: AnalyticsDateRangePreset.values.map((preset) {
                return FilterChip(
                  label: Text(preset.label),
                  selected: preset.matches(range),
                  onSelected: (_) {
                    ref.read(dateRangeProvider.notifier).state = preset.range;
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
