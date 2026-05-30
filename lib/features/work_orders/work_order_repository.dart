import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';

import '../../config/api_config.dart';
import '../../core/network/api_client.dart';
import '../executions/execution_models.dart';
import '../project/selected_project_controller.dart';
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

  Future<List<WorkOrder>> fetchList({
    required int projectId,
    String? status,
    String? search,
  }) async {
    final res = await _client.dio.get<dynamic>(
      '${ApiConfig.fieldworkPrefix}/work-orders/',
      queryParameters: {
        'project': projectId,
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

  Future<WorkOrderStatusCounts> fetchStatusCounts({required int projectId}) async {
    final res = await _client.dio.get<Map<String, dynamic>>(
      '${ApiConfig.fieldworkPrefix}/work-orders/status-counts/',
      queryParameters: {'project': projectId},
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

  Future<ExecutionPhoto> uploadWorkOrderPhoto({
    required int workOrderId,
    required String filePath,
    int? workItemId,
    String? caption,
    String? takenAt,
  }) async {
    final fileName = filePath.split(RegExp(r'[\\/]')).last;
    final ext =
        fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'jpg';
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
      if (workItemId != null) 'work_item': workItemId,
      if (caption != null && caption.isNotEmpty) 'caption': caption,
      if (takenAt != null && takenAt.isNotEmpty) 'taken_at': takenAt,
    });

    final res = await _client.dio.post<Map<String, dynamic>>(
      '${ApiConfig.fieldworkPrefix}/work-orders/$workOrderId/photos/',
      data: form,
    );
    return ExecutionPhoto.fromJson(res.data!);
  }

  Future<List<WorkerLookup>> fetchWorkers({String? search}) async {
    final res = await _client.dio.get<dynamic>(
      '${ApiConfig.fieldworkPrefix}/workers/',
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    final list = res.data as List? ?? const [];
    return list
        .map((e) => WorkerLookup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<VehicleLookup>> fetchVehicles({String? search}) async {
    final res = await _client.dio.get<dynamic>(
      '${ApiConfig.fieldworkPrefix}/vehicles/',
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    final list = res.data as List? ?? const [];
    return list
        .map((e) => VehicleLookup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<WorkOrderAssignment> createAssignment({
    required int workOrderId,
    required int zaposlenikId,
    required String datum,
    required double sati,
    int? voziloId,
    String uloga = '',
    String napomena = '',
  }) async {
    final res = await _client.dio.post<Map<String, dynamic>>(
      '${ApiConfig.fieldworkPrefix}/work-assignments/',
      data: {
        'work_order': workOrderId,
        'zaposlenik': zaposlenikId,
        'datum': datum,
        'sati': sati.toStringAsFixed(2),
        if (voziloId != null) 'vozilo': voziloId,
        if (uloga.isNotEmpty) 'uloga': uloga,
        if (napomena.isNotEmpty) 'napomena': napomena,
      },
    );
    return WorkOrderAssignment.fromJson(res.data!);
  }

  Future<WorkOrderAssignment> updateAssignment({
    required int id,
    String? datum,
    double? sati,
    int? voziloId,
    bool clearVozilo = false,
    String? uloga,
    String? napomena,
  }) async {
    final data = <String, dynamic>{};
    if (datum != null) data['datum'] = datum;
    if (sati != null) data['sati'] = sati.toStringAsFixed(2);
    if (clearVozilo) {
      data['vozilo'] = null;
    } else if (voziloId != null) {
      data['vozilo'] = voziloId;
    }
    if (uloga != null) data['uloga'] = uloga;
    if (napomena != null) data['napomena'] = napomena;

    final res = await _client.dio.patch<Map<String, dynamic>>(
      '${ApiConfig.fieldworkPrefix}/work-assignments/$id/',
      data: data,
    );
    return WorkOrderAssignment.fromJson(res.data!);
  }

  Future<WorkOrderVehicle> createVehicle({
    required int workOrderId,
    required int voziloId,
    required String datum,
    required double sati,
    String napomena = '',
  }) async {
    final res = await _client.dio.post<Map<String, dynamic>>(
      '${ApiConfig.fieldworkPrefix}/work-vehicles/',
      data: {
        'work_order': workOrderId,
        'vozilo': voziloId,
        'datum': datum,
        'sati': sati.toStringAsFixed(2),
        if (napomena.isNotEmpty) 'napomena': napomena,
      },
    );
    return WorkOrderVehicle.fromJson(res.data!);
  }

  Future<WorkOrderVehicle> updateVehicle({
    required int id,
    String? datum,
    double? sati,
    String? napomena,
  }) async {
    final data = <String, dynamic>{};
    if (datum != null) data['datum'] = datum;
    if (sati != null) data['sati'] = sati.toStringAsFixed(2);
    if (napomena != null) data['napomena'] = napomena;

    final res = await _client.dio.patch<Map<String, dynamic>>(
      '${ApiConfig.fieldworkPrefix}/work-vehicles/$id/',
      data: data,
    );
    return WorkOrderVehicle.fromJson(res.data!);
  }

  /// Brzi unos: PATCH ako postoji zapis za (nalog, djelatnik, datum), inače POST.
  Future<WorkOrderAssignment> upsertAssignment({
    required int workOrderId,
    required int zaposlenikId,
    required String datum,
    required double sati,
    int? voziloId,
    bool clearVozilo = false,
    WorkOrderAssignment? existing,
  }) async {
    if (existing != null) {
      return updateAssignment(
        id: existing.id,
        datum: datum,
        sati: sati,
        voziloId: voziloId,
        clearVozilo: clearVozilo,
      );
    }
    return createAssignment(
      workOrderId: workOrderId,
      zaposlenikId: zaposlenikId,
      datum: datum,
      sati: sati,
      voziloId: voziloId,
    );
  }
}

final workOrderRepositoryProvider = Provider<WorkOrderRepository>((ref) {
  return WorkOrderRepository(ref.watch(apiClientProvider));
});

/// Filter statusa za listu naloga.
final workOrderStatusFilterProvider = StateProvider<String?>((ref) => null);

final workOrderListProvider =
    FutureProvider.autoDispose<List<WorkOrder>>((ref) async {
  final projectId = ref.watch(selectedProjectIdProvider);
  if (projectId == null) return const [];
  final repo = ref.watch(workOrderRepositoryProvider);
  final status = ref.watch(workOrderStatusFilterProvider);
  return repo.fetchList(projectId: projectId, status: status);
});

final workOrderStatusCountsProvider =
    FutureProvider.autoDispose<WorkOrderStatusCounts>((ref) async {
  final projectId = ref.watch(selectedProjectIdProvider);
  if (projectId == null) {
    return const WorkOrderStatusCounts(total: 0, byStatus: {});
  }
  return ref
      .watch(workOrderRepositoryProvider)
      .fetchStatusCounts(projectId: projectId);
});

final workOrderDetailProvider =
    FutureProvider.autoDispose.family<WorkOrder, int>((ref, id) async {
  final repo = ref.watch(workOrderRepositoryProvider);
  return repo.fetchDetail(id);
});
