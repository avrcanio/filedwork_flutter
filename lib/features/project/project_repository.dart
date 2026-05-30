import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/api_config.dart';
import '../../core/network/api_client.dart';
import 'project_models.dart';

class ProjectRepository {
  ProjectRepository(this._client);

  final ApiClient _client;

  Future<List<FieldworkProject>> fetchActive() async {
    final res = await _client.dio.get<dynamic>(
      '${ApiConfig.fieldworkPrefix}/projects/',
      queryParameters: {
        'is_active': true,
        'ordering': '-created_at',
      },
    );
    final data = res.data;
    final list =
        data is Map ? (data['results'] as List? ?? const []) : (data as List);
    return list
        .map((e) => FieldworkProject.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository(ref.watch(apiClientProvider));
});

final activeProjectsProvider =
    FutureProvider.autoDispose<List<FieldworkProject>>((ref) async {
  return ref.watch(projectRepositoryProvider).fetchActive();
});
