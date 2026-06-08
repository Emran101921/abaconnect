import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../data/messaging_repository.dart';
import 'message_status_badge.dart';
import 'messages_screen.dart' show messageThreadsProvider;

class RecentMessagesSection extends ConsumerWidget {
  const RecentMessagesSection({super.key, this.inNotificationCenter = false});
  final bool inNotificationCenter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threads = ref.watch(messageThreadsProvider);

    return threads.when(
      data: (list) {
        if (list.isEmpty) {
          if (!inNotificationCenter) return const SizedBox.shrink();
          return Card(
            child: ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('No messages yet'),
              subtitle: const Text('Conversations with your care team appear here'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(AppRoutes.messages),
            ),
          );
        }
        final preview = [...list]
          ..sort((a, b) {
            if (a.hasUnread != b.hasUnread) {
              return a.hasUnread ? -1 : 1;
            }
            return b.updatedAt.compareTo(a.updatedAt);
          });
        final top = preview.take(2).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  inNotificationCenter ? 'Messages' : 'Recent messages',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.push(AppRoutes.messages),
                  child: const Text('All'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...top.map((t) => _ThreadPreviewCard(thread: t)),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      ),
      error: (e, _) => Card(
        child: ListTile(
          leading: const Icon(Icons.error_outline),
          title: const Text('Messages unavailable'),
          subtitle: Text(
            e.toString(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

class _ThreadPreviewCard extends StatelessWidget {
  const _ThreadPreviewCard({required this.thread});

  final MessageThreadModel thread;

  @override
  Widget build(BuildContext context) {
    final time = thread.lastMessageAt ?? thread.updatedAt;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: thread.hasUnread
          ? Theme.of(context).colorScheme.secondaryContainer
          : null,
      child: ListTile(
        leading: CircleAvatar(
          child: Text(thread.otherParticipantName.characters.first),
        ),
        title: Text(thread.otherParticipantName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              thread.lastMessageBody ?? thread.subject ?? 'No messages yet',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (thread.lastMessageIsMine && thread.lastMessageStatus != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: MessageStatusBadge(
                  status: thread.lastMessageStatus!,
                  compact: true,
                ),
              ),
          ],
        ),
        trailing: thread.hasUnread
            ? const Badge(label: Text('New'))
            : thread.lastMessageIsMine &&
                  thread.lastMessageStatus == MessageDeliveryStatus.read
            ? Text(
                'Read',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              )
            : Text(
                DateFormat.MMMd().format(time),
                style: Theme.of(context).textTheme.bodySmall,
              ),
        onTap: () => context.push('${AppRoutes.messages}/${thread.id}'),
      ),
    );
  }
}
