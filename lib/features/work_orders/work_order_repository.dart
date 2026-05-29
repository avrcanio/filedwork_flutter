import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/api_config.dart';
import '../../core/network/api_client.dart';
import 'work_order_models.dart';

class WorkOrderRepository {
  WorkOrderRepository(this._client);

  final ApiClient _client;

  Future<List<WorkOrder>> fetchList({String? status, String? search}) async {
    final res = await _client.dio.get<dynamic>(
      '${ApiConfig.fieldworkPrefix}/work-orders/',
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
        if (search != null && search.isNotEmpty) 'search': search,
        'ordering': '-created_at',
      },
    );
    final data = res.data;
    final list = data is Map ? (data['results'] as List? ?? const []) : (data as List);
    return list
        .map((e) => WorkOrder.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<WorkOrder> fetchDetail(int id) async {
    final res = await _client.dio.get<Map<String, dynamic>>(
      '${ApiConfig.fieldworkPrefix}/work-orders/$id/',
    );
    return WorkOrder.fromJson(res.data!);
  }

  Future<String> startOrder(int id) => _statusAction(id, 'start');
  Future<String> completeOrder(int id) => _statusAction(id, 'complete');

  Future<String> _statusAction(int id, String action) async {
    final res = await _client.dio.post<Map<String, dynamic>>(
      '${ApiConfig.fieldworkPrefix}/work-orders/$id/$action/',
    );
    return res.data?['status'] as String? ?? '';
  }
}

final workOrderRepositoryProvider = Provider<WorkOrderRepository>((ref) {
  return WorkOrderRepository(ref.watch(apiClientProvider));
});

/// Filter statusa za listu naloga.
final workOrderStatusFilterProvider = StateProvider<String?>((ref) => null);

final workOrderListProvider =
    FutureProvider.autoDispose<List<WorkOrder>>((ref) async {
  final repo = ref.watch(workOrderRepositoryProvider);
  final status = ref.watch(workOrderStatusFilterProvider);
  return repo.fetchList(status: status);
});

final workOrderDetailProvider =
    FutureProvider.autoDispose.family<WorkOrder, int>((ref, id) async {
  final repo = ref.watch(workOrderRepositoryProvider);
  return repo.fetchDetail(id);
});
