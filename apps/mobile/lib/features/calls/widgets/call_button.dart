import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../call_providers.dart';
import '../data/call_models.dart';

Future<void> startSecureCall(
  BuildContext context,
  WidgetRef ref, {
  required String recipientUserId,
  required String recipientName,
  String? childId,
  required CallType type,
}) async {
  try {
    final session = await ref.read(callsRepositoryProvider).initiateCall(
      recipientUserId: recipientUserId,
      callType: type,
      childId: childId,
    );
    if (!context.mounted) return;
    context.push(
      '${AppRoutes.activeCall}/${session.id}',
      extra: session,
    );
  } catch (e) {
    if (context.mounted) {
      AppSnackBar.showError(context, e);
    }
  }
}

/// App bar call control — single phone icon with audio/video menu.
class CallAppBarAction extends ConsumerWidget {
  const CallAppBarAction({
    super.key,
    required this.recipientUserId,
    required this.recipientName,
    this.childId,
  });

  final String recipientUserId;
  final String recipientName;
  final String? childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<CallType>(
      tooltip: 'Call $recipientName',
      icon: const Icon(Icons.call_outlined),
      onSelected: (type) => startSecureCall(
        context,
        ref,
        recipientUserId: recipientUserId,
        recipientName: recipientName,
        childId: childId,
        type: type,
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: CallType.AUDIO,
          child: ListTile(
            leading: Icon(Icons.call_outlined),
            title: Text('Audio call'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: CallType.VIDEO,
          child: ListTile(
            leading: Icon(Icons.videocam_outlined),
            title: Text('Video call'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

class CallButton extends ConsumerWidget {
  const CallButton({
    super.key,
    required this.recipientUserId,
    required this.recipientName,
    this.childId,
    this.compact = false,
  });

  final String recipientUserId;
  final String recipientName;
  final String? childId;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Audio call $recipientName',
            onPressed: () => startSecureCall(
              context,
              ref,
              recipientUserId: recipientUserId,
              recipientName: recipientName,
              childId: childId,
              type: CallType.AUDIO,
            ),
            icon: const Icon(Icons.call_outlined),
          ),
          IconButton(
            tooltip: 'Video call $recipientName',
            onPressed: () => startSecureCall(
              context,
              ref,
              recipientUserId: recipientUserId,
              recipientName: recipientName,
              childId: childId,
              type: CallType.VIDEO,
            ),
            icon: const Icon(Icons.videocam_outlined),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlossyButton(
          title: 'Call $recipientName',
          icon: Icons.call_outlined,
          onPressed: () => startSecureCall(
            context,
            ref,
            recipientUserId: recipientUserId,
            recipientName: recipientName,
            childId: childId,
            type: CallType.AUDIO,
          ),
        ),
        const SizedBox(height: 8),
        GlossyButton(
          title: 'Video call',
          icon: Icons.videocam_outlined,
          variant: GlossyButtonVariant.secondary,
          onPressed: () => startSecureCall(
            context,
            ref,
            recipientUserId: recipientUserId,
            recipientName: recipientName,
            childId: childId,
            type: CallType.VIDEO,
          ),
        ),
      ],
    );
  }
}
