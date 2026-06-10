import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/api_constants.dart';
import '../security/device_identity.dart';
import '../security/secure_storage_config.dart';

class ApiClient {
  ApiClient({FlutterSecureStorage? storage})
    : _storage = storage ?? secureStorage,
      _dio = Dio(
        BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          connectTimeout: ApiConstants.connectTimeout,
          receiveTimeout: ApiConstants.receiveTimeout,
          headers: {'Content-Type': 'application/json'},
        ),
      ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: ApiConstants.authTokenKey);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          try {
            final device = await DeviceIdentity.resolve();
            options.headers.addAll(device.toHeaders());
          } catch (_) {
            // Device headers are best-effort; never block a request on them.
          }
          if (options.data is FormData) {
            options.headers.remove('Content-Type');
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401 &&
              error.requestOptions.extra['retried'] != true) {
            final refreshed = await _tryRefreshToken();
            if (refreshed != null) {
              final opts = error.requestOptions;
              opts.headers['Authorization'] = 'Bearer $refreshed';
              opts.extra['retried'] = true;
              final response = await _dio.fetch(opts);
              return handler.resolve(response);
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;
  final FlutterSecureStorage _storage;

  Dio get dio => _dio;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.get<T>(path, queryParameters: queryParameters);
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.post<T>(path, data: data, queryParameters: queryParameters);
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.put<T>(path, data: data, queryParameters: queryParameters);
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.patch<T>(path, data: data, queryParameters: queryParameters);
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.delete<T>(path, data: data, queryParameters: queryParameters);
  }

  Future<void> saveToken(String token) {
    return _storage.write(key: ApiConstants.authTokenKey, value: token);
  }

  Future<void> clearToken() {
    return _storage.delete(key: ApiConstants.authTokenKey);
  }

  Future<String?> _tryRefreshToken() async {
    final refreshToken = await _storage.read(
      key: ApiConstants.refreshTokenKey,
    );
    if (refreshToken == null || refreshToken.isEmpty) {
      return null;
    }
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final accessToken = response.data?['accessToken'] as String?;
      final newRefresh = response.data?['refreshToken'] as String?;
      if (accessToken == null) return null;
      await saveToken(accessToken);
      if (newRefresh != null) {
        await _storage.write(
          key: ApiConstants.refreshTokenKey,
          value: newRefresh,
        );
      }
      return accessToken;
    } catch (_) {
      await clearToken();
      await _storage.delete(key: ApiConstants.refreshTokenKey);
      return null;
    }
  }
}
