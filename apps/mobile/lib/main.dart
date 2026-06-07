import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/push/push_bootstrap.dart';
import 'core/push/push_navigation.dart';
import 'core/providers/app_providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

final pendingPushPayloadProvider =
    StateProvider<Map<String, dynamic>?>((ref) => null);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: AbaConnectApp()));
}

class AbaConnectApp extends ConsumerStatefulWidget {
  const AbaConnectApp({super.key});

  @override
  ConsumerState<AbaConnectApp> createState() => _AbaConnectAppState();
}

class _AbaConnectAppState extends ConsumerState<AbaConnectApp> {
  @override
  void initState() {
    super.initState();
    PushBootstrap.init(onOpened: (data) {
      ref.read(pendingPushPayloadProvider.notifier).state = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final pending = ref.watch(pendingPushPayloadProvider);
    final auth = ref.watch(authStateProvider).valueOrNull;

    if (pending != null && auth != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigateFromPushPayload(
          router,
          data: pending,
          role: auth.user.role,
        );
        ref.read(pendingPushPayloadProvider.notifier).state = null;
      });
    }

    return MaterialApp.router(
      title: 'ABA Connect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
