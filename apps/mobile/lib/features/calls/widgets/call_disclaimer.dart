import 'package:flutter/material.dart';

/// HIPAA/compliance: visible on all call entry points.
class CallEmergencyDisclaimer extends StatelessWidget {
  const CallEmergencyDisclaimer({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.error,
      fontWeight: FontWeight.w600,
    );
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 4 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: compact ? 16 : 18,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'This calling feature is not for emergencies. Call 911 for emergencies.',
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}
