import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';

/// Logs the user out after prolonged inactivity on clinical sessions.
class SessionIdleGuard extends ConsumerStatefulWidget {
  const SessionIdleGuard({
    super.key,
    required this.child,
    this.timeout = const Duration(minutes: 15),
  });

  final Widget child;
  final Duration timeout;

  @override
  ConsumerState<SessionIdleGuard> createState() => _SessionIdleGuardState();
}

class _SessionIdleGuardState extends ConsumerState<SessionIdleGuard>
    with WidgetsBindingObserver {
  Timer? _idleTimer;
  DateTime _lastActivity = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resetTimer();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkIdle();
    }
  }

  void _touch() {
    _lastActivity = DateTime.now();
    _resetTimer();
  }

  void _resetTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(widget.timeout, _onTimeout);
  }

  void _checkIdle() {
    if (DateTime.now().difference(_lastActivity) >= widget.timeout) {
      _onTimeout();
    }
  }

  Future<void> _onTimeout() async {
    final session = ref.read(authStateProvider).valueOrNull;
    if (session == null) return;
    await ref.read(authStateProvider.notifier).logout();
    _idleTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = ref.watch(authStateProvider).valueOrNull != null;
    if (!isAuthenticated) {
      return widget.child;
    }

    return Listener(
      onPointerDown: (_) => _touch(),
      onPointerSignal: (_) => _touch(),
      child: widget.child,
    );
  }
}
