import 'package:flutter/foundation.dart';

class ApiConstants {
  ApiConstants._();

  /// Host machine API address. Android emulator uses 10.0.2.2 to reach the Mac.
  static String get apiHost {
    const override = String.fromEnvironment('API_HOST');
    if (override.isNotEmpty) return override;
    if (kIsWeb) return 'localhost';
    if (defaultTargetPlatform == TargetPlatform.android) return '10.0.2.2';
    return 'localhost';
  }

  static String get baseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) {
      _assertHttpsInRelease(override);
      return override;
    }
    final url = kReleaseMode
        ? 'https://$apiHost:3000/api/v1'
        : 'http://$apiHost:3000/api/v1';
    _assertHttpsInRelease(url);
    return url;
  }

  static String get graphqlUrl {
    const override = String.fromEnvironment('GRAPHQL_URL');
    if (override.isNotEmpty) {
      _assertHttpsInRelease(override);
      return override;
    }
    final url = kReleaseMode
        ? 'https://$apiHost:3000/graphql'
        : 'http://$apiHost:3000/graphql';
    _assertHttpsInRelease(url);
    return url;
  }

  static void _assertHttpsInRelease(String url) {
    if (kReleaseMode && !url.startsWith('https://')) {
      throw StateError(
        'Release builds require HTTPS API URLs. Set API_BASE_URL and GRAPHQL_URL via --dart-define.',
      );
    }
  }

  static const String hipaaConsentKey = 'hipaa_consent_granted';

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);

  static const String authTokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userRoleKey = 'user_role';
  static const String userEmailKey = 'user_email';
  static const String userIdKey = 'user_id';
  static const String tenantIdKey = 'tenant_id';
  static const String parentIdKey = 'parent_id';
  static const String therapistIdKey = 'therapist_id';
}
