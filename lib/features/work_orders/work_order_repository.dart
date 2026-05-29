import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/api_config.dart';
import '../../core/network/api_client.dart';
import 'work_order_models.dart';

/// Globalni broj radnih naloga po statusu (za badge na filterima).
class WorkOrderStatusCounts {
  const WorkOrderStatusCounts({required this.total, required this.byStatus});

  final int total;
  final Map<String, int> byStatus;

  /// Broj za zadani status; `null` status vraća ukupan broj ("Svi").
  int countFor(String? status) =>
      status == null ? total : (byStatus[status] ?? 0);

  factory WorkOrderStatusCounts.fromJson(Map<String, dynamic> json) {
    final raw = (json['by_status'] as Map?) ?? const {};
    return WorkOrderStatusCounts(
      total: (json['total'] as num?)?.toInt() ?? 0,
      byStatus: raw.map(
        (key, value) => MapEntry(key.toString(), (value as num).toInt()),
      ),
    );
  }
}

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

  Future<WorkOrderStatusCounts> fetchStatusCounts() async {
    final res = await _client.dio.get<Map<String, dynamic>>(
      '${ApiConfig.fieldworkPrefix}/work-orders/status-counts/',
    );
    return WorkOrderStatusCounts.fromJson(res.data!);
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

final workOrderStatusCountsProvider =
    FutureProvider.autoDispose<WorkOrderStatusCounts>((ref) async {
  return ref.watch(workOrderRepositoryProvider).fetchStatusCounts();
});

final workOrderDetailProvider =
    FutureProvider.autoDispose.family<WorkOrder, int>((ref, id) async {
  final repo = ref.watch(workOrderRepositoryProvider);
  return repo.fetchDetail(id);
});
