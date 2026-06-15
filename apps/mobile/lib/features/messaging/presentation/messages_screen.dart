import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/models/user_role.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/app_dashboard_card.dart';
import '../../../shared/widgets/app_healthcare_illustration.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_section_header.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../data/messaging_repository.dart';
import '../messaging_providers.dart';
import 'message_status_badge.dart';

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
    final isParent = role == UserRole.parent;

    return AppScaffold(
      title: 'Messages',
      bottomNavigationBar: isParent
          ? ParentBottomNav(current: ParentNavTab.messages)
          : isTherapist
          ? TherapistBottomNav(current: TherapistNavTab.messages)
          : null,
      floatingActionButton: GlossyFab(
        icon: Icons.add_comment,
        onPressed: () => isTherapist
            ? _startParentChat(context, ref)
            : _startTherapistChat(context, ref),
        tooltip: 'New message',
      ),
      body: threads.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Could not load messages',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  AppSnackBar.messageFromError(e),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                GlossyButton(
                  title: 'Retry',
                  icon: Icons.refresh_rounded,
                  variant: GlossyButtonVariant.neutral,
                  onPressed: () {
                    ref.invalidate(messageThreadsProvider);
                    ref.invalidate(unreadMessageThreadsProvider);
                  },
                ),
              ],
            ),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const AppHealthcareIllustration(
                      type: AppIllustrationType.messaging,
                      size: 120,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No conversations yet',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isTherapist
                          ? 'Connect with parents on your caseload'
                          : 'Message your therapist or care coordinator',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    GlossyButton(
                      title: isTherapist
                          ? 'Message a parent'
                          : 'Start a conversation',
                      icon: Icons.add_comment,
                      variant: GlossyButtonVariant.tealBlue,
                      onPressed: () => isTherapist
                          ? _startParentChat(context, ref)
                          : _startTherapistChat(context, ref),
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(messageThreadsProvider);
              ref.invalidate(unreadMessageThreadsProvider);
              await ref.read(messageThreadsProvider.future);
            },
            child: AppContentContainer(
              child: ListView.separated(
                itemCount: list.length + 1,
                separatorBuilder: (context, index) => index == 0
                    ? const SizedBox.shrink()
                    : const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return const AppSectionHeader(
                      title: 'Conversations',
                      subtitle: 'Secure messaging with your care team',
                    );
                  }
                  final t = list[index - 1];
                  final time = t.lastMessageAt ?? t.updatedAt;
                  return AppDashboardCard(
                    onTap: () => context.push('${AppRoutes.messages}/${t.id}'),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        child: Text(t.otherParticipantName.characters.first),
                      ),
                      title: Text(t.otherParticipantName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.lastMessageBody ?? t.subject ?? 'No messages yet',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (t.lastMessageIsMine &&
                              t.lastMessageStatus != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: MessageStatusBadge(
                                status: t.lastMessageStatus!,
                                compact: true,
                              ),
                            ),
                        ],
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
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                            ),
                          ] else if (t.lastMessageIsMine &&
                              t.lastMessageStatus ==
                                  MessageDeliveryStatus.read) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Read',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _startTherapistChat(BuildContext context, WidgetRef ref) async {
    try {
      final therapists = await ref
          .read(parentBookingRepositoryProvider)
          .fetchTherapists();
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not start chat: $e')));
      }
    }
  }

  Future<void> _startParentChat(BuildContext context, WidgetRef ref) async {
    try {
      final parents = await ref
          .read(messagingRepositoryProvider)
          .fetchParentContacts();
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
      final threadId = await ref
          .read(messagingRepositoryProvider)
          .startParentConversation(selected);
      ref.invalidate(messageThreadsProvider);
      ref.invalidate(unreadMessageThreadsProvider);
      if (context.mounted) {
        context.push('${AppRoutes.messages}/$threadId');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not start chat: $e')));
      }
    }
  }
}
