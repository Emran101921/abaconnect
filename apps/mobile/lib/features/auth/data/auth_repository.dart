import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/push/push_token_service.dart';
import '../../../shared/models/user_role.dart';

class LoginResponse {
  const LoginResponse._({this.tokens, this.mfaChallengeToken});

  factory LoginResponse.authenticated(AuthTokens tokens) =>
      LoginResponse._(tokens: tokens);

  factory LoginResponse.mfaRequired(String challengeToken) =>
      LoginResponse._(mfaChallengeToken: challengeToken);

  final AuthTokens? tokens;
  final String? mfaChallengeToken;

  bool get requiresMfa => mfaChallengeToken != null;
}

class MfaSetupResult {
  const MfaSetupResult({required this.secret, required this.otpauthUrl});

  final String secret;
  final String otpauthUrl;
}

class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
  });

  final String accessToken;
  final String refreshToken;
}

class MeProfile {
  const MeProfile({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.tenantId,
    this.parentId,
    this.therapistId,
  });

  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String role;
  final String tenantId;
  final String? parentId;
  final String? therapistId;

  String get fullName => '$firstName $lastName';
}

class AuthRepository {
  AuthRepository(this._api, {FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final ApiClient _api;
  final FlutterSecureStorage _storage;

  Future<LoginResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    final data = response.data;
    if (data == null) {
      throw Exception('Invalid login response');
    }
    if (data['requiresMfa'] == true) {
      return LoginResponse.mfaRequired(
        data['mfaChallengeToken'] as String,
      );
    }
    final tokens = AuthTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
    await _persistTokens(tokens);
    return LoginResponse.authenticated(tokens);
  }

  Future<AuthTokens> completeMfaLogin({
    required String mfaChallengeToken,
    required String code,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/auth/login/mfa',
      data: {'mfaChallengeToken': mfaChallengeToken, 'code': code},
    );
    final data = response.data;
    if (data == null) {
      throw Exception('Invalid MFA login response');
    }
    final tokens = AuthTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
    await _persistTokens(tokens);
    return tokens;
  }

  Future<void> _persistTokens(AuthTokens tokens) async {
    await _api.saveToken(tokens.accessToken);
    await _storage.write(
      key: ApiConstants.refreshTokenKey,
      value: tokens.refreshToken,
    );
    final me = await fetchMe();
    await _persistMe(me);
    await registerPushDevice(userId: me.id);
  }

  Future<void> registerPushDevice({required String userId}) async {
    try {
      final platform = kIsWeb
          ? 'web'
          : switch (defaultTargetPlatform) {
              TargetPlatform.iOS => 'ios',
              TargetPlatform.android => 'android',
              _ => 'other',
            };
      final push = PushTokenService();
      final token = await push.resolveToken(userId: userId);
      await _registerDeviceToken(
        userId: userId,
        token: token,
        platform: platform,
      );
      push.listenForTokenRefresh((newToken) async {
        await _registerDeviceToken(
          userId: userId,
          token: newToken,
          platform: platform,
        );
      });
    } catch (_) {
      // Push registration is best-effort until FCM/APNs credentials are configured.
    }
  }

  Future<void> _registerDeviceToken({
    required String userId,
    required String token,
    required String platform,
  }) async {
    await _api.post(
      '/auth/device',
      data: {
        'deviceToken': token,
        'platform': platform,
        'appVersion': '1.0.0',
      },
    );
  }

  Future<bool> fetchMfaStatus() async {
    final response = await _api.get<Map<String, dynamic>>('/auth/mfa/status');
    return response.data?['enabled'] as bool? ?? false;
  }

  Future<MfaSetupResult> beginMfaSetup() async {
    final response = await _api.post<Map<String, dynamic>>('/auth/mfa/setup');
    final data = response.data;
    if (data == null) throw Exception('MFA setup failed');
    return MfaSetupResult(
      secret: data['secret'] as String,
      otpauthUrl: data['otpauthUrl'] as String,
    );
  }

  Future<void> enableMfa(String code) async {
    await _api.post('/auth/mfa/enable', data: {'code': code});
  }

  Future<void> disableMfa({
    required String code,
    required String password,
  }) async {
    await _api.post('/auth/mfa/disable', data: {
      'code': code,
      'password': password,
    });
  }

  Future<AuthTokens> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    UserRole role = UserRole.parent,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'email': email,
        'password': password,
        'firstName': firstName,
        'lastName': lastName,
        'role': _roleToApi(role),
      },
    );
    final data = response.data;
    if (data == null) {
      throw Exception('Invalid register response');
    }
    final tokens = AuthTokens(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
    );
    await _persistTokens(tokens);
    return tokens;
  }

  Future<MeProfile> fetchMe() async {
    final response = await _api.get<Map<String, dynamic>>('/auth/me');
    final data = response.data;
    if (data == null) {
      throw Exception('Could not load profile');
    }
    return MeProfile(
      id: data['id'] as String,
      email: data['email'] as String,
      firstName: data['firstName'] as String,
      lastName: data['lastName'] as String,
      role: data['role'] as String,
      tenantId: data['tenantId'] as String,
      parentId: data['parentId'] as String?,
      therapistId: data['therapistId'] as String?,
    );
  }

  Future<AuthSession?> loadSession() async {
    final token = await _storage.read(key: ApiConstants.authTokenKey);
    if (token == null || token.isEmpty) {
      return null;
    }
    try {
      final me = await fetchMe();
      return AuthSession(user: _meToAuthUser(me), accessToken: token);
    } catch (_) {
      return _loadSessionFromStorage(token);
    }
  }

  Future<AuthSession?> _loadSessionFromStorage(String token) async {
    final roleName = await _storage.read(key: ApiConstants.userRoleKey);
    final email = await _storage.read(key: ApiConstants.userEmailKey);
    final id = await _storage.read(key: ApiConstants.userIdKey);
    if (roleName == null || email == null) {
      return null;
    }
    final role = UserRole.values.firstWhere(
      (r) => r.name == roleName,
      orElse: () => UserRole.parent,
    );
    return AuthSession(
      user: AuthUser(id: id ?? '', email: email, role: role),
      accessToken: token,
    );
  }

  Future<void> _persistMe(MeProfile me) async {
    await _storage.write(key: ApiConstants.userRoleKey, value: _apiRoleToUserRole(me.role).name);
    await _storage.write(key: ApiConstants.userEmailKey, value: me.email);
    await _storage.write(key: ApiConstants.userIdKey, value: me.id);
    await _storage.write(key: ApiConstants.tenantIdKey, value: me.tenantId);
    if (me.parentId != null) {
      await _storage.write(key: ApiConstants.parentIdKey, value: me.parentId);
    }
    if (me.therapistId != null) {
      await _storage.write(key: ApiConstants.therapistIdKey, value: me.therapistId);
    }
  }

  Future<String?> requestPasswordReset(String email) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/auth/forgot-password',
      data: {'email': email},
    );
    return response.data?['resetToken'] as String?;
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await _api.post<Map<String, dynamic>>(
      '/auth/reset-password',
      data: {'token': token, 'newPassword': newPassword},
    );
  }

  Future<void> logout() async {
    await _api.clearToken();
    await _storage.delete(key: ApiConstants.refreshTokenKey);
    await _storage.delete(key: ApiConstants.userRoleKey);
    await _storage.delete(key: ApiConstants.userEmailKey);
    await _storage.delete(key: ApiConstants.userIdKey);
    await _storage.delete(key: ApiConstants.tenantIdKey);
    await _storage.delete(key: ApiConstants.parentIdKey);
    await _storage.delete(key: ApiConstants.therapistIdKey);
  }

  AuthUser _meToAuthUser(MeProfile me) {
    return AuthUser(
      id: me.id,
      email: me.email,
      role: _apiRoleToUserRole(me.role),
      fullName: me.fullName,
    );
  }

  String _roleToApi(UserRole role) {
    switch (role) {
      case UserRole.parent:
        return 'PARENT';
      case UserRole.therapist:
        return 'THERAPIST';
      case UserRole.agency:
        return 'AGENCY_ADMIN';
      case UserRole.admin:
        return 'PLATFORM_ADMIN';
    }
  }

  UserRole _apiRoleToUserRole(String apiRole) {
    switch (apiRole) {
      case 'THERAPIST':
        return UserRole.therapist;
      case 'AGENCY_ADMIN':
        return UserRole.agency;
      case 'PLATFORM_ADMIN':
        return UserRole.admin;
      default:
        return UserRole.parent;
    }
  }
}

class AuthSession {
  const AuthSession({required this.user, required this.accessToken});

  final AuthUser user;
  final String accessToken;
}
