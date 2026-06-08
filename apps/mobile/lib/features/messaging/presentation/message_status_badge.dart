import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/messaging_repository.dart';

class MessageStatusBadge extends StatelessWidget {
  const MessageStatusBadge({
    super.key,
    required this.status,
    this.readAt,
    this.compact = false,
  });

  final MessageDeliveryStatus status;
  final DateTime? readAt;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isRead = status == MessageDeliveryStatus.read;
    final color = isRead
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final icon = status == MessageDeliveryStatus.sent
        ? Icons.done
        : Icons.done_all;
    final label = switch (status) {
      MessageDeliveryStatus.read => 'Read',
      MessageDeliveryStatus.delivered => 'Delivered',
      MessageDeliveryStatus.sent => 'Sent',
    };

    if (compact) {
      return Icon(icon, size: 14, color: color);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 2),
        Text(
          isRead && readAt != null
              ? '$label · ${DateFormat.jm().format(readAt!)}'
              : label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: isRead ? FontWeight.w600 : null,
          ),
        ),
      ],
    );
  }
}
