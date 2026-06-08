import 'package:flutter/material.dart';

class WeeklyProgressWeek {
  const WeeklyProgressWeek({
    required this.weekLabel,
    required this.reportCount,
  });

  final String weekLabel;
  final int reportCount;
}

class ChildProgressSummary {
  const ChildProgressSummary({
    required this.childId,
    required this.childName,
    required this.goalCompletionPercent,
    this.activePlanTitle,
  });

  final String childId;
  final String childName;
  final double goalCompletionPercent;
  final String? activePlanTitle;
}

/// Simple weekly bar chart for therapist progress reports (no extra chart deps).
class WeeklyProgressChart extends StatelessWidget {
  const WeeklyProgressChart({
    super.key,
    required this.weeks,
    this.height = 140,
  });

  final List<WeeklyProgressWeek> weeks;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (weeks.isEmpty) {
      return const Text('No weekly data yet.');
    }
    final maxCount = weeks.map((w) => w.reportCount).fold(1, (a, b) => a > b ? a : b);
    final color = Theme.of(context).colorScheme.primary;

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: weeks.map((w) {
          final barHeight = w.reportCount == 0
              ? 4.0
              : (w.reportCount / maxCount) * (height - 48);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (w.reportCount > 0)
                    Text(
                      '${w.reportCount}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: w.reportCount > 0
                          ? color
                          : color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    w.weekLabel,
                    style: Theme.of(context).textTheme.labelSmall,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class ChildGoalProgressList extends StatelessWidget {
  const ChildGoalProgressList({super.key, required this.children});

  final List<ChildProgressSummary> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      children: children.map((c) {
        final pct = c.goalCompletionPercent.clamp(0, 100) / 100;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.childName,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (c.activePlanTitle != null)
                  Text(
                    c.activePlanTitle!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: pct,
                  borderRadius: BorderRadius.circular(4),
                  minHeight: 8,
                ),
                const SizedBox(height: 4),
                Text(
                  '${c.goalCompletionPercent.round()}% goals met',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
