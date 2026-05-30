import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/api_config.dart';
import '../../core/network/api_client.dart';
import '../../shared/utils/app_dates.dart';
import '../project/selected_project_controller.dart';
import 'daily_report_models.dart';

enum DailyReportViewMode { day, week }

class DailyReportRepository {
  DailyReportRepository(this._client);

  final ApiClient _client;

  Future<DailyReport> fetch(DateTime date, {required int projectId}) async {
    final dateStr = toApiDate(date);
    final res = await _client.dio.get<Map<String, dynamic>>(
      '${ApiConfig.fieldworkPrefix}/work-executions/daily_report/',
      queryParameters: {
        'date': dateStr,
        'project': projectId,
      },
    );
    return DailyReport.fromJson(res.data ?? const {});
  }

  Future<WeeklyReport> fetchWeekly(
    DateTime weekStart, {
    required int projectId,
  }) async {
    final dateStr = toApiDate(weekStart);
    final res = await _client.dio.get<Map<String, dynamic>>(
      '${ApiConfig.fieldworkPrefix}/work-executions/weekly_report/',
      queryParameters: {
        'week_start': dateStr,
        'project': projectId,
      },
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
  final projectId = ref.watch(selectedProjectIdProvider)!;
  final repo = ref.watch(dailyReportRepositoryProvider);
  final date = ref.watch(dailyReportDateProvider);
  return repo.fetch(date, projectId: projectId);
});

final weeklyReportProvider =
    FutureProvider.autoDispose<WeeklyReport>((ref) async {
  final projectId = ref.watch(selectedProjectIdProvider)!;
  final repo = ref.watch(dailyReportRepositoryProvider);
  final weekStart = ref.watch(dailyReportWeekStartProvider);
  return repo.fetchWeekly(weekStart, projectId: projectId);
});
