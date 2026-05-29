import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../config/api_config.dart';
import '../../core/network/api_client.dart';
import 'daily_report_models.dart';

class DailyReportRepository {
  DailyReportRepository(this._client);

  final ApiClient _client;

  Future<DailyReport> fetch(DateTime date) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final res = await _client.dio.get<Map<String, dynamic>>(
      '${ApiConfig.fieldworkPrefix}/work-executions/daily_report/',
      queryParameters: {'date': dateStr},
    );
    return DailyReport.fromJson(res.data ?? const {});
  }
}

final dailyReportRepositoryProvider = Provider<DailyReportRepository>((ref) {
  return DailyReportRepository(ref.watch(apiClientProvider));
});

/// Odabrani datum dnevnog izvještaja.
final dailyReportDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

final dailyReportProvider =
    FutureProvider.autoDispose<DailyReport>((ref) async {
  final repo = ref.watch(dailyReportRepositoryProvider);
  final date = ref.watch(dailyReportDateProvider);
  return repo.fetch(date);
});
