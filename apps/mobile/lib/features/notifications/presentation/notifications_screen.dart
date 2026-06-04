import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../platform/data/platform_repository.dart';
import '../notification_providers.dart';

final notificationsProvider =
    FutureProvider<List<NotificationItemModel>>((ref) {
  return ref.watch(platformRepositoryProvider).fetchNotifications();
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

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
    if (n.actionType == 'MESSAGE' && n.threadId != null) {
      context.push('${AppRoutes.messages}/${n.threadId}');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(notificationsProvider);

    return AppScaffold(
      title: 'Notifications',
      actions: [
        TextButton(
          onPressed: () async {
            await ref.read(platformRepositoryProvider).markAllNotificationsRead();
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
          if (list.isEmpty) {
            return const Center(child: Text('No notifications'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(notificationsProvider);
              await ref.read(notificationsProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final n = list[index];
                final canOpenThread =
                    n.actionType == 'MESSAGE' && n.threadId != null;
                return ListTile(
                  leading: Icon(
                    n.isRead ? Icons.notifications_none : Icons.notifications_active,
                    color: n.isRead ? null : Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(n.title),
                  subtitle: Text(n.body),
                  trailing: canOpenThread
                      ? const Icon(Icons.chevron_right)
                      : null,
                  onTap: () => _onTap(context, ref, n),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
