import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'push_bootstrap.dart';

typedef TokenRefreshHandler = Future<void> Function(String token);

/// Resolves FCM device tokens for API registration.
class PushTokenService {
  static bool _refreshListenerSet = false;

  Future<String> resolveToken({required String userId}) async {
    if (kIsWeb) {
      return 'web-$userId';
    }
    try {
      if (Firebase.apps.isNotEmpty && PushBootstrap.firebaseReady) {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null && token.isNotEmpty) {
          return token;
        }
      }
    } catch (_) {}
    final day = DateTime.now().millisecondsSinceEpoch ~/ 86400000;
    return 'mobile-$userId-$day';
  }

  void listenForTokenRefresh(TokenRefreshHandler onRefresh) {
    if (_refreshListenerSet || kIsWeb || !PushBootstrap.firebaseReady) {
      return;
    }
    try {
      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        onRefresh(token);
      });
      _refreshListenerSet = true;
    } catch (_) {}
  }
}
