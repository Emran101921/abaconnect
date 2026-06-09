import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../providers/consent_gate_provider.dart';
import '../../features/auth/data/auth_repository.dart';

/// Notifies [GoRouter] when auth state changes so redirects re-run.
class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(this._ref) {
    _ref.listen<AsyncValue<AuthSession?>>(
      authStateProvider,
      (_, _) => notifyListeners(),
    );
    _ref.listen<bool>(
      hipaaConsentGrantedProvider,
      (_, _) => notifyListeners(),
    );
  }

  final Ref _ref;
}

final routerRefreshNotifierProvider = Provider<RouterRefreshNotifier>((ref) {
  final notifier = RouterRefreshNotifier(ref);
  ref.onDispose(notifier.dispose);
  return notifier;
});
