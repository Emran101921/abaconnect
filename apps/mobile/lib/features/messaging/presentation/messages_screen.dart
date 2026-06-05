import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/models/user_role.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../data/messaging_repository.dart';
import '../messaging_providers.dart';

final messageThreadsProvider = FutureProvider<List<MessageThreadModel>>((ref) {
  return ref.watch(messagingRepositoryProvider).fetchThreads();
});

class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threads = ref.watch(messageThreadsProvider);
    final role = ref.watch(authStateProvider).valueOrNull?.user.role;
    final isTherapist = role == UserRole.therapist;

    return AppScaffold(
      title: 'Messages',
      floatingActionButton: FloatingActionButton(
        onPressed: () => isTherapist
            ? _startParentChat(context, ref)
            : _startTherapistChat(context, ref),
        child: const Icon(Icons.add_comment),
      ),
      body: threads.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No conversations yet.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => isTherapist
                        ? _startParentChat(context, ref)
                        : _startTherapistChat(context, ref),
                    child: Text(
                      isTherapist ? 'Message a parent' : 'Message your therapist',
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(messageThreadsProvider);
              ref.invalidate(unreadMessageThreadsProvider);
              await ref.read(messageThreadsProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (context, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final t = list[index];
                final time = t.lastMessageAt ?? t.updatedAt;
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(t.otherParticipantName.characters.first),
                  ),
                  title: Text(t.otherParticipantName),
                  subtitle: Text(
                    t.lastMessageBody ?? t.subject ?? 'No messages yet',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        DateFormat.MMMd().format(time),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (t.hasUnread) ...[
                        const SizedBox(height: 4),
                        Badge(
                          label: const Text('New'),
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ],
                  ),
                  onTap: () => context.push('${AppRoutes.messages}/${t.id}'),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _startTherapistChat(BuildContext context, WidgetRef ref) async {
    try {
      final therapists =
          await ref.read(parentBookingRepositoryProvider).fetchTherapists();
      if (therapists.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No therapists available')),
          );
        }
        return;
      }
      if (!context.mounted) return;
      final selected = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Choose therapist'),
          children: therapists
              .map(
                (t) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, t.id),
                  child: Text(t.displayName),
                ),
              )
              .toList(),
        ),
      );
      if (selected == null) return;
      final threadId = await ref
          .read(messagingRepositoryProvider)
          .startTherapistConversation(selected);
      ref.invalidate(messageThreadsProvider);
      ref.invalidate(unreadMessageThreadsProvider);
      if (context.mounted) {
        context.push('${AppRoutes.messages}/$threadId');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start chat: $e')),
        );
      }
    }
  }

  Future<void> _startParentChat(BuildContext context, WidgetRef ref) async {
    try {
      final parents =
          await ref.read(messagingRepositoryProvider).fetchParentContacts();
      if (parents.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No parent contacts yet — book appointments first'),
            ),
          );
        }
        return;
      }
      if (!context.mounted) return;
      final selected = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Choose parent'),
          children: parents
              .map(
                (p) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, p.parentId),
                  child: Text(
                    p.childSummary != null
                        ? '${p.displayName}\n${p.childSummary}'
                        : p.displayName,
                  ),
                ),
              )
              .toList(),
        ),
      );
      if (selected == null) return;
      final threadId =
          await ref.read(messagingRepositoryProvider).startParentConversation(selected);
      ref.invalidate(messageThreadsProvider);
      ref.invalidate(unreadMessageThreadsProvider);
      if (context.mounted) {
        context.push('${AppRoutes.messages}/$threadId');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start chat: $e')),
        );
      }
    }
  }
}
