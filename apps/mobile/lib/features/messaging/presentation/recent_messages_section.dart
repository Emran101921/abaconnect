import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../data/messaging_repository.dart';
import 'messages_screen.dart' show messageThreadsProvider;

class RecentMessagesSection extends ConsumerWidget {
  const RecentMessagesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threads = ref.watch(messageThreadsProvider);

    return threads.when(
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
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
                  'Recent messages',
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
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
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
        subtitle: Text(
          thread.lastMessageBody ?? thread.subject ?? 'No messages yet',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: thread.hasUnread
            ? const Badge(label: Text('New'))
            : Text(
                DateFormat.MMMd().format(time),
                style: Theme.of(context).textTheme.bodySmall,
              ),
        onTap: () => context.push('${AppRoutes.messages}/${thread.id}'),
      ),
    );
  }
}
