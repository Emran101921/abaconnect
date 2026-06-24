import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/models/user_role.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../messaging/messaging_providers.dart';
import '../../messaging/presentation/messages_screen.dart';
import '../../messaging/presentation/recent_messages_section.dart';
import '../../platform/data/platform_repository.dart';
import '../notification_providers.dart';

final notificationsProvider = FutureProvider<List<NotificationItemModel>>((
  ref,
) {
  return ref.watch(platformRepositoryProvider).fetchNotifications();
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  bool _hasDestination(NotificationItemModel n) {
    if (n.actionType == 'MESSAGE' && n.threadId != null) return true;
    if (n.actionType != null &&
        n.actionType!.startsWith('APPOINTMENT') &&
        n.appointmentId != null) {
      return true;
    }
    if (n.actionType == 'SESSION_COMPLETED') return true;
    if (n.actionType == 'SOAP_DUE') return true;
    if (n.marketplaceRequestId != null &&
        (n.actionType == 'MARKETPLACE_INTEREST' ||
            n.actionType == 'MARKETPLACE_CONSENT_GRANTED' ||
            n.actionType == 'MARKETPLACE_CONSENT_REVOKED' ||
            n.actionType == 'MARKETPLACE_SAVED_SEARCH_MATCH')) {
      return true;
    }
    if (n.actionType == 'SESSION_PAYMENT_DUE' && n.paymentId != null) {
      return true;
    }
    return false;
  }

  Future<void> _onTap(
    BuildContext context,
    WidgetRef ref,
    NotificationItemModel n,
  ) async {
    if (!n.isRead) {
      await ref.read(platformRepositoryProvider).markNotificationRead(n.id);
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationsProvider);
    }
    if (!context.mounted) return;

    final role = ref.read(authStateProvider).valueOrNull?.user.role;

    if (n.actionType == 'MESSAGE' && n.threadId != null) {
      ref.invalidate(unreadMessageThreadsProvider);
      context.push('${AppRoutes.messages}/${n.threadId}');
      return;
    }

    if (n.actionType == 'SOAP_DUE' && role == UserRole.therapist) {
      context.push('${AppRoutes.therapistHome}/session-notes');
      return;
    }

    if (n.actionType != null &&
        n.actionType!.startsWith('APPOINTMENT') &&
        n.appointmentId != null) {
      if (role == UserRole.therapist) {
        context.push(
          '${AppRoutes.therapistHome}/appointments?id=${n.appointmentId}',
        );
      } else {
        context.push(
          '${AppRoutes.parentHome}/appointments?id=${n.appointmentId}',
        );
      }
      return;
    }
    if (n.actionType == 'TELEHEALTH' && n.appointmentId != null) {
      context.push(
        '${AppRoutes.parentHome}/appointments?id=${n.appointmentId}',
      );
      return;
    }

    if (n.actionType == 'SESSION_COMPLETED') {
      context.push('${AppRoutes.parentHome}/reviews');
      return;
    }

    if (n.actionType == 'SESSION_PAYMENT_DUE' &&
        n.paymentId != null &&
        role == UserRole.parent) {
      context.push('${AppRoutes.payments}?paymentId=${n.paymentId}');
      return;
    }

    final marketplaceId = n.marketplaceRequestId;
    if (marketplaceId != null) {
      if (n.actionType == 'MARKETPLACE_INTEREST' && role == UserRole.parent) {
        context.push('${AppRoutes.parentMarketplace}/$marketplaceId/interests');
        return;
      }
      if (n.actionType == 'MARKETPLACE_CONSENT_GRANTED' &&
          role == UserRole.therapist) {
        context.push(
          '${AppRoutes.therapistMarketplace}/$marketplaceId/authorized-child',
        );
        return;
      }
      if (n.actionType == 'MARKETPLACE_CONSENT_GRANTED' &&
          role == UserRole.agency) {
        context.push(
          '${AppRoutes.agencyMarketplace}/$marketplaceId/authorized-child',
        );
        return;
      }
      if (n.actionType == 'MARKETPLACE_CONSENT_REVOKED' &&
          role == UserRole.therapist) {
        context.push(AppRoutes.therapistMarketplace);
        return;
      }
      if (n.actionType == 'MARKETPLACE_CONSENT_REVOKED' &&
          role == UserRole.agency) {
        context.push(AppRoutes.agencyMarketplace);
        return;
      }
      if (n.actionType == 'MARKETPLACE_SAVED_SEARCH_MATCH' &&
          role == UserRole.therapist) {
        context.push(AppRoutes.therapistMarketplace);
        return;
      }
      if (n.actionType == 'MARKETPLACE_SAVED_SEARCH_MATCH' &&
          role == UserRole.agency) {
        context.push(AppRoutes.agencyMarketplace);
        return;
      }
    }
  }

  Future<void> _onRefresh(WidgetRef ref) async {
    ref.invalidate(notificationsProvider);
    ref.invalidate(messageThreadsProvider);
    ref.invalidate(unreadMessageThreadsProvider);
    await ref.read(notificationsProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(notificationsProvider);

    return AppScaffold(
      title: 'Notifications',
      bottomNavigationBar: const RoleBottomNav(current: CoreNavTab.home),
      actions: [
        TextButton(
          onPressed: () async {
            await ref
                .read(platformRepositoryProvider)
                .markAllNotificationsRead();
            ref.invalidate(notificationsProvider);
            ref.invalidate(unreadNotificationsProvider);
          },
          child: const Text('Mark all read'),
        ),
      ],
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          return RefreshIndicator(
            onRefresh: () => _onRefresh(ref),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const RecentMessagesSection(inNotificationCenter: true),
                const SizedBox(height: 20),
                Text(
                  'Alerts',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (list.isEmpty)
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.notifications_none),
                      title: Text('No alerts'),
                      subtitle: Text(
                        'Appointment reminders and updates appear here',
                      ),
                    ),
                  )
                else
                  ...list.map(
                    (n) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          n.isRead
                              ? Icons.notifications_none
                              : Icons.notifications_active,
                          color: n.isRead
                              ? null
                              : Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(n.title),
                        subtitle: Text(n.body),
                        trailing: _hasDestination(n)
                            ? const Icon(Icons.chevron_right)
                            : null,
                        onTap: () => _onTap(context, ref, n),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
