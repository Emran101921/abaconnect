import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/api_constants.dart';
import '../security/device_identity.dart';
import '../security/secure_storage_config.dart';

class GraphqlClient {
  GraphqlClient({FlutterSecureStorage? storage})
    : _secureStorage = storage ?? secureStorage,
      _dio = Dio(
        BaseOptions(
          connectTimeout: ApiConstants.connectTimeout,
          receiveTimeout: ApiConstants.receiveTimeout,
          headers: {'Content-Type': 'application/json'},
        ),
      );

  final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  Future<Map<String, dynamic>> query(
    String document, {
    Map<String, dynamic>? variables,
  }) async {
    return _post(document, variables: variables, retried: false);
  }

  Future<Map<String, dynamic>> _post(
    String document, {
    Map<String, dynamic>? variables,
    required bool retried,
  }) async {
    final headers = await _buildHeaders();
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.graphqlUrl,
        data: {'query': document, 'variables': ?variables},
        options: Options(
          headers: headers,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      final body = response.data;
      if (body == null) {
        throw Exception('Empty GraphQL response');
      }

      if (response.statusCode == 401 && !retried) {
        final refreshed = await _tryRefreshToken();
        if (refreshed != null) {
          return _post(document, variables: variables, retried: true);
        }
        await _clearAuthTokens();
        throw Exception('Session expired. Please sign in again.');
      }

      final errors = body['errors'];
      if (errors is List && errors.isNotEmpty) {
        final message = _formatGraphqlError(errors.first);
        if (_isAuthError(message) && !retried) {
          final refreshed = await _tryRefreshToken();
          if (refreshed != null) {
            return _post(document, variables: variables, retried: true);
          }
          await _clearAuthTokens();
        }
        throw Exception(message);
      }

      if (response.statusCode != null && response.statusCode! >= 400) {
        throw Exception('Request failed (${response.statusCode})');
      }
      return body;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 && !retried) {
        final refreshed = await _tryRefreshToken();
        if (refreshed != null) {
          return _post(document, variables: variables, retried: true);
        }
        await _clearAuthTokens();
        throw Exception('Session expired. Please sign in again.');
      }
      final body = e.response?.data;
      if (body is Map) {
        final errors = body['errors'];
        if (errors is List && errors.isNotEmpty) {
          throw Exception(_formatGraphqlError(errors.first));
        }
      }
      rethrow;
    }
  }

  Future<Map<String, String>> _buildHeaders() async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = await _secureStorage.read(key: ApiConstants.authTokenKey);
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    try {
      final device = await DeviceIdentity.resolve();
      headers.addAll(device.toHeaders());
    } catch (_) {
      // Device headers are best-effort.
    }
    return headers;
  }

  Future<String?> _tryRefreshToken() async {
    final refreshToken = await _secureStorage.read(
      key: ApiConstants.refreshTokenKey,
    );
    if (refreshToken == null || refreshToken.isEmpty) {
      return null;
    }
    try {
      final headers = await _buildHeaders();
      final response = await _dio.post<Map<String, dynamic>>(
        '${ApiConstants.baseUrl}/auth/refresh',
        data: {'refreshToken': refreshToken},
        options: Options(headers: headers),
      );
      final accessToken = response.data?['accessToken'] as String?;
      final newRefresh = response.data?['refreshToken'] as String?;
      if (accessToken == null || accessToken.isEmpty) return null;
      await _secureStorage.write(
        key: ApiConstants.authTokenKey,
        value: accessToken,
      );
      if (newRefresh != null && newRefresh.isNotEmpty) {
        await _secureStorage.write(
          key: ApiConstants.refreshTokenKey,
          value: newRefresh,
        );
      }
      return accessToken;
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearAuthTokens() async {
    await _secureStorage.delete(key: ApiConstants.authTokenKey);
    await _secureStorage.delete(key: ApiConstants.refreshTokenKey);
  }

  static bool _isAuthError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('session has been revoked') ||
        lower.contains('unauthorized') ||
        lower.contains('jwt expired');
  }

  static String _formatGraphqlError(dynamic error) {
    if (error is! Map) {
      return error.toString();
    }
    final extensions = error['extensions'];
    if (extensions is Map) {
      final original = extensions['originalError'];
      if (original is Map) {
        final nested = original['message'];
        if (nested is List && nested.isNotEmpty) {
          return nested.map((e) => e.toString()).join('; ');
        }
        if (nested is String && nested.isNotEmpty) {
          return nested;
        }
      }
    }
    final message = error['message']?.toString();
    if (message != null &&
        message.isNotEmpty &&
        message != 'Bad Request Exception') {
      return message;
    }
    return 'Request failed. Please check your entries and try again.';
  }
}
