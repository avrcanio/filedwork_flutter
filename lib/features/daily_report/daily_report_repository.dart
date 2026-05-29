import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../config/api_config.dart';
import '../../core/network/api_client.dart';
import 'daily_report_models.dart';

enum DailyReportViewMode { day, week }

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

  Future<WeeklyReport> fetchWeekly(DateTime weekStart) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(weekStart);
    final res = await _client.dio.get<Map<String, dynamic>>(
      '${ApiConfig.fieldworkPrefix}/work-executions/weekly_report/',
      queryParameters: {'week_start': dateStr},
    );
    return WeeklyReport.fromJson(res.data ?? const {});
  }
}

final dailyReportRepositoryProvider = Provider<DailyReportRepository>((ref) {
  return DailyReportRepository(ref.watch(apiClientProvider));
});

/// Dan / tjedan prikaz.
final dailyReportViewModeProvider =
    StateProvider<DailyReportViewMode>((ref) => DailyReportViewMode.day);

/// Odabrani datum dnevnog izvještaja.
final dailyReportDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// Ponedjeljak trenutno odabranog tjedna.
final dailyReportWeekStartProvider = Provider<DateTime>((ref) {
  final date = ref.watch(dailyReportDateProvider);
  return date.subtract(Duration(days: date.weekday - DateTime.monday));
});

final dailyReportProvider =
    FutureProvider.autoDispose<DailyReport>((ref) async {
  final repo = ref.watch(dailyReportRepositoryProvider);
  final date = ref.watch(dailyReportDateProvider);
  return repo.fetch(date);
});

final weeklyReportProvider =
    FutureProvider.autoDispose<WeeklyReport>((ref) async {
  final repo = ref.watch(dailyReportRepositoryProvider);
  final weekStart = ref.watch(dailyReportWeekStartProvider);
  return repo.fetchWeekly(weekStart);
});
