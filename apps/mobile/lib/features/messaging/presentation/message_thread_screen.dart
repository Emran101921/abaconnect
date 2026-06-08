import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../notifications/notification_providers.dart';
import '../data/messaging_repository.dart';
import '../messaging_providers.dart';
import 'message_status_badge.dart';
import 'messages_screen.dart' show messageThreadsProvider;

class MessageThreadScreen extends ConsumerStatefulWidget {
  const MessageThreadScreen({super.key, required this.threadId});

  final String threadId;

  @override
  ConsumerState<MessageThreadScreen> createState() =>
      _MessageThreadScreenState();
}

class _MessageThreadScreenState extends ConsumerState<MessageThreadScreen> {
  final _controller = TextEditingController();
  List<ChatMessageModel> _messages = [];
  bool _loading = true;
  bool _sending = false;
  Timer? _statusPoll;

  @override
  void initState() {
    super.initState();
    _load();
    _statusPoll = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshStatuses(),
    );
  }

  @override
  void dispose() {
    _statusPoll?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(messagingRepositoryProvider);
      final list = await repo.fetchMessages(widget.threadId);
      if (mounted) {
        setState(() {
          _messages = list;
          _loading = false;
        });
      }
      try {
        await repo.markThreadRead(widget.threadId);
        if (mounted) {
          ref.invalidate(messageThreadsProvider);
          ref.invalidate(unreadMessageThreadsProvider);
        }
        await _refreshStatuses();
      } catch (_) {
        // Read receipt is best-effort; messages are already visible.
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Load failed: $e')));
      }
    }
  }

  Future<void> _refreshStatuses() async {
    if (_loading || !mounted) return;
    try {
      final list = await ref
          .read(messagingRepositoryProvider)
          .fetchMessages(widget.threadId);
      if (mounted) {
        setState(() => _messages = list);
      }
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final msg = await ref
          .read(messagingRepositoryProvider)
          .sendMessage(threadId: widget.threadId, body: text);
      _controller.clear();
      setState(() {
        _messages = [..._messages, msg];
        _sending = false;
      });
      ref.invalidate(messageThreadsProvider);
      ref.invalidate(unreadMessageThreadsProvider);
      ref.invalidate(unreadNotificationsProvider);
    } catch (e) {
      setState(() => _sending = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Send failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Conversation',
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final m = _messages[index];
                      final status = m.status ?? MessageDeliveryStatus.sent;
                      return Align(
                        alignment: m.isMine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: m.isMine
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(
                                AppSpacing.radiusLg,
                              ),
                              topRight: const Radius.circular(
                                AppSpacing.radiusLg,
                              ),
                              bottomLeft: Radius.circular(
                                m.isMine
                                    ? AppSpacing.radiusLg
                                    : AppSpacing.radiusSm,
                              ),
                              bottomRight: Radius.circular(
                                m.isMine
                                    ? AppSpacing.radiusSm
                                    : AppSpacing.radiusLg,
                              ),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * 0.75,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!m.isMine)
                                Text(
                                  m.senderName,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              Text(
                                m.body,
                                style: TextStyle(
                                  color: m.isMine
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    DateFormat.jm().format(m.sentAt),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: m.isMine
                                              ? Theme.of(context)
                                                    .colorScheme
                                                    .onPrimary
                                                    .withValues(alpha: 0.8)
                                              : null,
                                        ),
                                  ),
                                  if (m.isMine) ...[
                                    const SizedBox(width: 6),
                                    MessageStatusBadge(
                                      status: status,
                                      readAt: m.readAt,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Type a secure message…',
                        filled: true,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
