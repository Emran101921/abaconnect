import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../models/dashboard_action_model.dart';

class DashboardActionInbox extends StatelessWidget {
  const DashboardActionInbox({
    super.key,
    required this.items,
    this.onRefresh,
  });

  final List<DashboardActionModel> items;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final sorted = [...items]
      ..sort((a, b) => (a.priority ?? 99).compareTo(b.priority ?? 99));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Needs attention', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...sorted.map((item) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(_iconFor(item.actionType)),
              title: Text(item.title),
              subtitle: item.subtitle != null ? Text(item.subtitle!) : null,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _navigate(context, item),
            ),
          );
        }),
      ],
    );
  }

  IconData _iconFor(String actionType) {
    return switch (actionType) {
      'MESSAGE' => Icons.chat_bubble_outline,
      'SOAP_DUE' => Icons.description_outlined,
      'REVIEW' => Icons.star_outline,
      'APPOINTMENT' => Icons.event_outlined,
      'TELEHEALTH' => Icons.videocam_outlined,
      'CLAIM' => Icons.receipt_long_outlined,
      'EVV' => Icons.location_on_outlined,
      'VERIFICATION' => Icons.verified_user_outlined,
      _ => Icons.notifications_outlined,
    };
  }

  void _navigate(BuildContext context, DashboardActionModel item) {
    switch (item.actionType) {
      case 'MESSAGE':
        context.push(AppRoutes.messages);
      case 'SOAP_DUE':
        context.push('${AppRoutes.therapistHome}/session-notes');
      case 'REVIEW':
        context.push('${AppRoutes.parentHome}/reviews');
      case 'APPOINTMENT':
        context.push('${AppRoutes.therapistHome}/appointments');
      case 'TELEHEALTH':
        if (item.appointmentId != null) {
          context.push('${AppRoutes.parentHome}/appointments');
        }
      case 'CLAIM':
        context.push(AppRoutes.insurance);
      case 'EVV':
        context.push('${AppRoutes.agencyHome}/appointments');
      case 'VERIFICATION':
        context.push('${AppRoutes.agencyHome}/roster');
      default:
        context.push(AppRoutes.notifications);
    }
    onRefresh?.call();
  }
}
