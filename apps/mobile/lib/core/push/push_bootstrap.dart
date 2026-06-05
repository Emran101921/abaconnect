import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

class PushBootstrap {
  static bool firebaseReady = false;

  static Future<void> init({
    void Function(Map<String, dynamic> data)? onOpened,
  }) async {
    if (kIsWeb || DefaultFirebaseOptions.isDemoConfig) {
      firebaseReady = false;
      return;
    }
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      firebaseReady = true;
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        final data = _stringifyData(message.data);
        onOpened?.call(data);
      });

      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        onOpened?.call(_stringifyData(initial.data));
      }
    } catch (_) {
      firebaseReady = false;
    }
  }

  static Map<String, dynamic> _stringifyData(Map<String, dynamic> raw) {
    return raw.map((key, value) => MapEntry(key, value?.toString() ?? ''));
  }
}
