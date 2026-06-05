import 'package:flutter/foundation.dart';

/// Resolves a device push token for registration with the API.
/// Wire [firebase_messaging] here after `flutterfire configure`.
class PushTokenService {
  Future<String> resolveToken({required String userId}) async {
    if (kIsWeb) {
      return 'web-$userId';
    }
    // Placeholder until Firebase is configured; API push worker logs in dev.
    final day = DateTime.now().millisecondsSinceEpoch ~/ 86400000;
    return 'mobile-$userId-$day';
  }
}
