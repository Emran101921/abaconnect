import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/push/push_bootstrap.dart';
import 'core/push/push_navigation.dart';
import 'core/providers/app_providers.dart';
import 'core/router/app_router.dart';
import 'core/providers/theme_mode_provider.dart';
import 'core/security/session_idle_guard.dart';
import 'core/theme/app_theme.dart';
import 'features/calls/call_providers.dart';

final pendingPushPayloadProvider = StateProvider<Map<String, dynamic>?>(
  (ref) => null,
);

const _enableWebSemantics =
    bool.fromEnvironment('ENABLE_WEB_SEMANTICS', defaultValue: false);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb && _enableWebSemantics) {
    SemanticsBinding.instance.ensureSemantics();
  }
  runApp(const ProviderScope(child: BloomOraApp()));
}

class BloomOraApp extends ConsumerStatefulWidget {
  const BloomOraApp({super.key});

  @override
  ConsumerState<BloomOraApp> createState() => _BloomOraAppState();
}

class _BloomOraAppState extends ConsumerState<BloomOraApp> {
  @override
  void initState() {
    super.initState();
    PushBootstrap.init(
      onOpened: (data) {
        ref.read(pendingPushPayloadProvider.notifier).state = data;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final pending = ref.watch(pendingPushPayloadProvider);
    final auth = ref.watch(authStateProvider).valueOrNull;

    if (pending != null && auth != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigateFromPushPayload(router, data: pending, role: auth.user.role);
        ref.read(pendingPushPayloadProvider.notifier).state = null;
      });
    }

    final themeMode = ref.watch(themeModeProvider);

    return SessionIdleGuard(
      child: IncomingCallListener(
        child: MaterialApp.router(
          title: 'BloomOra',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          routerConfig: router,
        ),
      ),
    );
  }
}

/// Polls for ringing calls and surfaces the incoming-call screen.
class IncomingCallListener extends ConsumerStatefulWidget {
  const IncomingCallListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<IncomingCallListener> createState() =>
      _IncomingCallListenerState();
}

class _IncomingCallListenerState extends ConsumerState<IncomingCallListener> {
  String? _presentedCallId;

  @override
  void initState() {
    super.initState();
    _schedulePoll();
  }

  void _schedulePoll() {
    Future.delayed(const Duration(seconds: 12), () {
      if (!mounted) return;
      _pollIncoming();
      _schedulePoll();
    });
  }

  Future<void> _pollIncoming() async {
    final auth = ref.read(authStateProvider).valueOrNull;
    if (auth == null) return;

    ref.invalidate(incomingRingingCallProvider);
    final call = await ref.read(incomingRingingCallProvider.future);
    if (!mounted || call == null) return;
    if (_presentedCallId == call.id) return;

    final router = ref.read(appRouterProvider);
    final location = router.state.matchedLocation;
    if (location.contains('/incoming-call/')) return;

    _presentedCallId = call.id;
    router.push('${AppRoutes.incomingCall}/${call.id}', extra: call);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
