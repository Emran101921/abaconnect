import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import 'secure_storage_config.dart';

/// Stable per-install device fingerprint used for MFA / new-device detection.
///
/// The [deviceId] is a random UUID persisted in the secure keychain so it
/// survives app restarts (and, on iOS, stays stable for the install). Device
/// model + OS version come from `device_info_plus`. These values are attached
/// to every API request as `x-device-*` headers so the backend can stamp auth
/// events with the originating device + location.
class DeviceInfo {
  const DeviceInfo({
    required this.deviceId,
    required this.model,
    required this.platform,
    required this.osVersion,
  });

  final String deviceId;
  final String model;
  final String platform;
  final String osVersion;

  Map<String, String> toHeaders() => {
    'x-device-id': deviceId,
    'x-device-model': model,
    'x-device-platform': platform,
    'x-device-os': osVersion,
  };
}

class DeviceIdentity {
  DeviceIdentity._();

  static const _deviceIdKey = 'auth_device_id';
  static final FlutterSecureStorage _storage = secureStorage;
  static Future<DeviceInfo>? _cached;

  /// Resolves (and caches) the device fingerprint for the current install.
  static Future<DeviceInfo> resolve() => _cached ??= _resolve();

  static Future<DeviceInfo> _resolve() async {
    final deviceId = await _resolveDeviceId();
    final plugin = DeviceInfoPlugin();

    try {
      if (kIsWeb) {
        final web = await plugin.webBrowserInfo;
        return DeviceInfo(
          deviceId: deviceId,
          model: web.browserName.name,
          platform: 'web',
          osVersion: web.appVersion ?? 'unknown',
        );
      }
      switch (defaultTargetPlatform) {
        case TargetPlatform.iOS:
          final ios = await plugin.iosInfo;
          return DeviceInfo(
            deviceId: deviceId,
            model: ios.utsname.machine.isNotEmpty
                ? ios.utsname.machine
                : ios.model,
            platform: 'ios',
            osVersion: '${ios.systemName} ${ios.systemVersion}',
          );
        case TargetPlatform.android:
          final android = await plugin.androidInfo;
          return DeviceInfo(
            deviceId: deviceId,
            model: '${android.manufacturer} ${android.model}',
            platform: 'android',
            osVersion: 'Android ${android.version.release}',
          );
        default:
          break;
      }
    } catch (_) {
      // Fall through to a generic descriptor if the platform channel fails.
    }
    return DeviceInfo(
      deviceId: deviceId,
      model: 'unknown',
      platform: defaultTargetPlatform.name,
      osVersion: 'unknown',
    );
  }

  static Future<String> _resolveDeviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final generated = const Uuid().v4();
    await _storage.write(key: _deviceIdKey, value: generated);
    return generated;
  }
}
