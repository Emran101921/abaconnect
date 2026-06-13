import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../models/dashboard_action_model.dart';

class DashboardActionInbox extends StatelessWidget {
  const DashboardActionInbox({super.key, required this.items, this.onRefresh});

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
      'MARKETPLACE_INTEREST' => Icons.storefront_outlined,
      'CLAIM' => Icons.receipt_long_outlined,
      'EVV' => Icons.location_on_outlined,
      'VERIFICATION' => Icons.verified_user_outlined,
      _ => Icons.notifications_outlined,
    };
  }

  void _navigate(BuildContext context, DashboardActionModel item) {
    switch (item.actionType) {
      case 'MESSAGE':
        if (item.threadId != null) {
          context.push('${AppRoutes.messages}/${item.threadId}');
        } else {
          context.push(AppRoutes.messages);
        }
      case 'SOAP_DUE':
        context.push('${AppRoutes.therapistHome}/session-notes');
      case 'REVIEW':
        final therapistQ = item.therapistId != null
            ? 'therapistId=${item.therapistId}&submit=true'
            : 'submit=true';
        context.push('${AppRoutes.parentHome}/reviews?$therapistQ');
      case 'APPOINTMENT':
        if (item.appointmentId != null) {
          context.push(
            '${AppRoutes.therapistHome}/appointments?id=${item.appointmentId}',
          );
        } else {
          context.push('${AppRoutes.therapistHome}/appointments');
        }
      case 'TELEHEALTH':
        if (item.appointmentId != null) {
          context.push(
            '${AppRoutes.parentHome}/appointments?id=${item.appointmentId}',
          );
        } else {
          context.push(AppRoutes.telehealth);
        }
      case 'MARKETPLACE_INTEREST':
        if (item.marketplaceRequestId != null) {
          context.push(
            '${AppRoutes.parentMarketplace}/${item.marketplaceRequestId}/interests',
          );
        } else {
          context.push(AppRoutes.parentMarketplace);
        }
      case 'CLAIM':
        if (item.claimId != null) {
          context.push('${AppRoutes.insurance}?claimId=${item.claimId}');
        } else {
          context.push(AppRoutes.insurance);
        }
      case 'ONBOARDING':
        if (item.id == 'onboard-child') {
          context.push('${AppRoutes.parentHome}/children');
        } else if (item.id == 'onboard-screening') {
          context.push('${AppRoutes.parentHome}/screening');
        } else {
          context.push(AppRoutes.matching);
        }
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
