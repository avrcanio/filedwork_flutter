import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/api_config.dart';
import '../storage/secure_storage.dart';

/// Signal da je token nevažeći (401) — sluša ga auth sloj za odjavu.
typedef UnauthorizedCallback = void Function();

class ApiClient {
  ApiClient(this._storage) {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        headers: {
          'Accept': 'application/json',
          'X-Client': 'roadly',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.readToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Token $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401) {
            _onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  late final Dio _dio;
  final SecureStorage _storage;
  UnauthorizedCallback? _onUnauthorized;

  Dio get dio => _dio;

  set onUnauthorized(UnauthorizedCallback? cb) => _onUnauthorized = cb;

  /// Pretvara DioException u čitljivu poruku na hrvatskom.
  static String describeError(Object error) {
    if (error is DioException) {
      final res = error.response;
      if (res != null) {
        final data = res.data;
        if (data is Map) {
          for (final key in const ['detail', 'error', 'non_field_errors']) {
            final value = data[key];
            if (value is String) return value;
            if (value is List && value.isNotEmpty) return value.first.toString();
          }
          // Prvi field error.
          final firstEntry = data.entries.isNotEmpty ? data.entries.first : null;
          if (firstEntry != null) {
            final v = firstEntry.value;
            final msg = v is List && v.isNotEmpty ? v.first.toString() : v.toString();
            return '${firstEntry.key}: $msg';
          }
        }
        return 'Greška ${res.statusCode}.';
      }
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return 'Isteklo je vrijeme čekanja. Provjerite vezu.';
        case DioExceptionType.connectionError:
          return 'Nije moguće povezati se s poslužiteljem.';
        default:
          return 'Greška u komunikaciji s poslužiteljem.';
      }
    }
    return error.toString();
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return ApiClient(storage);
});
