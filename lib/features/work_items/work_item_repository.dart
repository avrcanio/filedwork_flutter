import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/api_config.dart';
import '../../core/network/api_client.dart';
import 'work_item_geo.dart';

class WorkItemRepository {
  WorkItemRepository(this._client);

  final ApiClient _client;

  Future<List<WorkItemGeoFeature>> fetchGeojson(int workOrderId) async {
    final res = await _client.dio.get<Map<String, dynamic>>(
      '${ApiConfig.fieldworkPrefix}/work-items/geojson_export/',
      queryParameters: {'work_order': workOrderId},
    );
    return WorkItemGeoFeature.listFromFeatureCollection(res.data ?? const {});
  }
}

final workItemRepositoryProvider = Provider<WorkItemRepository>((ref) {
  return WorkItemRepository(ref.watch(apiClientProvider));
});

final workOrderGeojsonProvider = FutureProvider.autoDispose
    .family<List<WorkItemGeoFeature>, int>((ref, workOrderId) async {
  final repo = ref.watch(workItemRepositoryProvider);
  return repo.fetchGeojson(workOrderId);
});
