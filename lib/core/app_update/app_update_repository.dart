import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/api_config.dart';
import 'app_update_models.dart';

class AppUpdateRepository {
  AppUpdateRepository(this._dio);

  final Dio _dio;

  Future<AppUpdateConfig> fetchConfig() async {
    final platform = Platform.isIOS ? 'ios' : 'android';
    final response = await _dio.get<Map<String, dynamic>>(
      ApiConfig.appConfigPath,
      queryParameters: {'platform': platform},
    );
    return AppUpdateConfig.fromJson(response.data ?? {});
  }
}

final appUpdateRepositoryProvider = Provider<AppUpdateRepository>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      headers: const {
        'Accept': 'application/json',
        'X-Client': 'roadly',
      },
    ),
  );
  return AppUpdateRepository(dio);
});
