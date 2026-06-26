import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/models/user_role.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/glossy_button.dart';
import '../../job_opportunities/data/job_opportunities_repository.dart';
import '../call_providers.dart';
import '../data/call_models.dart';
import '../widgets/call_disclaimer.dart';
import '../widgets/in_app_call_room.dart';

class IncomingCallLoaderScreen extends ConsumerWidget {
  const IncomingCallLoaderScreen({super.key, required this.callSessionId});

  final String callSessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final call = ref.watch(callSessionProvider(callSessionId));
    return call.when(
      loading: () => const AppScaffold(
        title: 'Incoming call',
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => AppScaffold(
        title: 'Incoming call',
        body: Center(child: Text('Could not load call: $e')),
      ),
      data: (session) {
        if (session == null) {
          return const AppScaffold(
            title: 'Incoming call',
            body: Center(child: Text('Call not found')),
          );
        }
        return IncomingCallScreen(call: session);
      },
    );
  }
}

class IncomingCallScreen extends ConsumerStatefulWidget {
  const IncomingCallScreen({super.key, required this.call});

  final CallSessionModel call;

  @override
  ConsumerState<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends ConsumerState<IncomingCallScreen> {
  bool _busy = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollStatus());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _pollStatus() async {
    if (_busy || !mounted) return;
    final updated = await ref
        .read(callsRepositoryProvider)
        .fetchCallSession(widget.call.id);
    if (!mounted || updated == null) return;
    if (_isTerminalCallStatus(updated.status)) {
      _pollTimer?.cancel();
      _leaveCallScreen(ref);
    }
  }

  bool _isTerminalCallStatus(CallSessionStatus status) =>
      status == CallSessionStatus.ENDED ||
      status == CallSessionStatus.CANCELLED ||
      status == CallSessionStatus.DECLINED ||
      status == CallSessionStatus.MISSED ||
      status == CallSessionStatus.FAILED;

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      final session = await ref
          .read(callsRepositoryProvider)
          .acceptCall(widget.call.id);
      if (!mounted) return;
      context.push(
        '${AppRoutes.activeCall}/${session.id}',
        extra: session,
      );
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline() async {
    setState(() => _busy = true);
    try {
      await ref.read(callsRepositoryProvider).endCall(widget.call.id);
      if (mounted) _leaveCallScreen(ref);
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message() {
    context.push(AppRoutes.messages);
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.call.callType == CallType.VIDEO;
    return AppScaffold(
      title: 'Incoming call',
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            Icon(
              isVideo ? Icons.videocam_rounded : Icons.call_rounded,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              widget.call.initiatedByName,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isVideo ? 'Secure video call' : 'Secure audio call',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            const CallEmergencyDisclaimer(),
            const Spacer(),
            GlossyButton(
              title: 'Accept',
              icon: Icons.call_rounded,
              onPressed: _busy ? null : _accept,
            ),
            const SizedBox(height: 12),
            GlossyButton(
              title: 'Decline',
              icon: Icons.call_end_rounded,
              variant: GlossyButtonVariant.neutral,
              onPressed: _busy ? null : _decline,
            ),
            const SizedBox(height: 12),
            GlossyButton(
              title: 'Message',
              icon: Icons.message_outlined,
              variant: GlossyButtonVariant.secondary,
              onPressed: _busy ? null : _message,
            ),
          ],
        ),
      ),
    );
  }
}

class ActiveCallScreen extends ConsumerStatefulWidget {
  const ActiveCallScreen({super.key, required this.session});

  final CallSessionModel session;

  @override
  ConsumerState<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends ConsumerState<ActiveCallScreen> {
  bool _ending = false;

  Future<void> _endCall() async {
    if (_ending) return;
    setState(() => _ending = true);
    try {
      await ref.read(callsRepositoryProvider).endCall(widget.session.id);
      if (widget.session.jobInterviewId != null) {
        _invalidateInterviewProviders();
      }
    } catch (e) {
      final msg = AppSnackBar.messageFromError(e).toLowerCase();
      final alreadyDone = msg.contains('not active') ||
          msg.contains('cannot be cancelled') ||
          msg.contains('no longer ringing') ||
          msg.contains('not ringing');
      if (!alreadyDone && mounted) {
        AppSnackBar.showError(context, e);
        setState(() => _ending = false);
        return;
      }
    }
    if (mounted) _leaveCallScreen(ref, jobInterviewId: widget.session.jobInterviewId);
  }

  void _invalidateInterviewProviders() {
    ref.invalidate(agencyJobInterviewsProvider);
    ref.invalidate(therapistJobInterviewsProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: InAppCallRoom(
        session: widget.session,
        onEndCall: _endCall,
        onCancelRinging: _endCall,
        onRemoteEnded: () {
          if (widget.session.jobInterviewId != null) {
            _invalidateInterviewProviders();
          }
          if (mounted) {
            _leaveCallScreen(ref, jobInterviewId: widget.session.jobInterviewId);
          }
        },
      ),
    );
  }
}

void _leaveCallScreen(WidgetRef ref, {String? jobInterviewId}) {
  final context = ref.context;
  if (!context.mounted) return;
  if (context.canPop()) {
    context.pop();
    return;
  }
  final role = ref.read(authStateProvider).valueOrNull?.user.role;
  switch (role) {
    case UserRole.therapist:
      context.go(AppRoutes.therapistHome);
    case UserRole.parent:
      context.go(AppRoutes.parentHome);
    case UserRole.serviceCoordinator:
      context.go(AppRoutes.serviceCoordinatorHome);
    case UserRole.agency:
      context.go(AppRoutes.agencyHome);
    case UserRole.admin:
      context.go(AppRoutes.adminHome);
    default:
      context.go(AppRoutes.messages);
  }
}
