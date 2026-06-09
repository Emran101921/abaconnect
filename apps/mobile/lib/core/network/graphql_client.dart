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
      final message = errors.first is Map
          ? (errors.first as Map)['message']?.toString()
          : errors.first.toString();
      throw Exception(message ?? 'GraphQL error');
    }
    return body;
  }
}
