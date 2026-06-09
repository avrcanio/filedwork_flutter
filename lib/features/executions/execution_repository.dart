import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';

import '../../config/api_config.dart';
import '../../core/network/api_client.dart';
import 'execution_models.dart';

class ExecutionRepository {
  ExecutionRepository(this._client);

  final ApiClient _client;

  /// Kreira izvršenje stavke. Backend automatski postavlja status
  /// (in_progress / completed) ovisno o pokrivenoj količini.
  Future<WorkExecution> createExecution({
    required int workItemId,
    required double quantityExecuted,
    required String executionDate,
    String? notes,
    double? laborHours,
    List<({int zaposlenikId, double laborHours})>? laborEntries,
  }) async {
    final res = await _client.dio.post<Map<String, dynamic>>(
      '${ApiConfig.fieldworkPrefix}/work-executions/',
      data: {
        'work_item': workItemId,
        'quantity_executed': quantityExecuted,
        'execution_date': executionDate,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (laborEntries != null && laborEntries.isNotEmpty)
          'labor_entries': [
            for (final entry in laborEntries)
              {
                'zaposlenik': entry.zaposlenikId,
                'labor_hours': entry.laborHours.toStringAsFixed(2),
              },
          ]
        else if (laborHours != null && laborHours > 0)
          'labor_hours': laborHours.toStringAsFixed(2),
      },
    );
    return WorkExecution.fromJson(res.data!);
  }

  Future<List<WorkExecution>> listExecutions({
    required int workItemId,
    required String executionDate,
  }) async {
    final res = await _client.dio.get<dynamic>(
      '${ApiConfig.fieldworkPrefix}/work-executions/',
      queryParameters: {
        'work_item': workItemId,
        'execution_date': executionDate,
        'ordering': '-created_at',
      },
    );
    final data = res.data;
    final list =
        data is Map ? (data['results'] as List? ?? const []) : (data as List);
    return list
        .map((e) => WorkExecution.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<WorkExecution> updateExecution({
    required int executionId,
    double? quantityExecuted,
    String? executionDate,
    String? notes,
    List<({int zaposlenikId, double laborHours})>? laborEntries,
  }) async {
    final res = await _client.dio.patch<Map<String, dynamic>>(
      '${ApiConfig.fieldworkPrefix}/work-executions/$executionId/',
      data: {
        if (quantityExecuted != null)
          'quantity_executed': quantityExecuted.toStringAsFixed(3),
        if (executionDate != null) 'execution_date': executionDate,
        if (notes != null) 'notes': notes,
        if (laborEntries != null)
          'labor_entries': [
            for (final entry in laborEntries)
              {
                'zaposlenik': entry.zaposlenikId,
                'labor_hours': entry.laborHours.toStringAsFixed(2),
              },
          ],
      },
    );
    return WorkExecution.fromJson(res.data!);
  }

  /// Otvara planned izvršenje (qty=0) za upload fotografija prije rada.
  Future<WorkExecution> openExecution(int workItemId) async {
    final res = await _client.dio.post<Map<String, dynamic>>(
      '${ApiConfig.fieldworkPrefix}/work-items/$workItemId/open-execution/',
    );
    return WorkExecution.fromJson(res.data!);
  }

  /// Upload jedne fotografije (multipart). Vraća se metapodatak fotografije.
  Future<ExecutionPhoto> uploadPhoto({
    required int executionId,
    required String filePath,
    String? caption,
    String? phase,
  }) async {
    final fileName = filePath.split(RegExp(r'[\\/]')).last;
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'jpg';
    final subtype = switch (ext) {
      'png' => 'png',
      'webp' => 'webp',
      _ => 'jpeg',
    };

    final form = FormData.fromMap({
      'image': await MultipartFile.fromFile(
        filePath,
        filename: fileName,
        contentType: MediaType('image', subtype),
      ),
      if (caption != null && caption.isNotEmpty) 'caption': caption,
      if (phase != null && phase.isNotEmpty) 'phase': phase,
    });

    final res = await _client.dio.post<Map<String, dynamic>>(
      '${ApiConfig.fieldworkPrefix}/work-executions/$executionId/photos/',
      data: form,
    );
    return ExecutionPhoto.fromJson(res.data!);
  }
}

final executionRepositoryProvider = Provider<ExecutionRepository>((ref) {
  return ExecutionRepository(ref.watch(apiClientProvider));
});
