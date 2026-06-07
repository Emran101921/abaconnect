// Demo Firebase options — replace via `flutterfire configure` for production push.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  /// True when placeholder keys from `flutterfire configure` have not been applied.
  static bool get isDemoConfig => currentPlatform.apiKey.startsWith('demo-');

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'demo-web-key',
    appId: '1:demo:web:abaconnect',
    messagingSenderId: 'demo-sender',
    projectId: 'abaconnect-demo',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'demo-android-key',
    appId: '1:demo:android:abaconnect',
    messagingSenderId: 'demo-sender',
    projectId: 'abaconnect-demo',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'demo-ios-key',
    appId: '1:demo:ios:abaconnect',
    messagingSenderId: 'demo-sender',
    projectId: 'abaconnect-demo',
    iosBundleId: 'com.abaconnect.mobile',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'demo-ios-key',
    appId: '1:demo:ios:abaconnect',
    messagingSenderId: 'demo-sender',
    projectId: 'abaconnect-demo',
    iosBundleId: 'com.abaconnect.mobile',
  );
}
