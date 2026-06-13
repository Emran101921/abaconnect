import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/api_constants.dart';
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
    final token = await _secureStorage.read(key: ApiConstants.authTokenKey);
    final response = await _dio.post<Map<String, dynamic>>(
      ApiConstants.graphqlUrl,
      data: {'query': document, 'variables': ?variables},
      options: Options(
        headers: token != null && token.isNotEmpty
            ? {'Authorization': 'Bearer $token'}
            : null,
      ),
    );

    final body = response.data;
    if (body == null) {
      throw Exception('Empty GraphQL response');
    }
    final errors = body['errors'];
    if (errors is List && errors.isNotEmpty) {
      throw Exception(_formatGraphqlError(errors.first));
    }
    return body;
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
