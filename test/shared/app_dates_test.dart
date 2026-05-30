import 'package:fieldwork_flutter/shared/utils/app_dates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toApiDate and parseApiDate round-trip', () {
    final date = DateTime(2026, 5, 29);
    expect(toApiDate(date), '2026-05-29');
    expect(parseApiDate('2026-05-29'), date);
  });

  test('formatDateForDisplay formats API date', () {
    expect(formatDateForDisplay('2026-05-29'), '29.05.2026');
    expect(formatDateForDisplay(null), '');
    expect(formatDateForDisplay(''), '');
  });

  test('formatDisplayDate matches display pattern', () {
    expect(formatDisplayDate(DateTime(2026, 5, 29)), '29.05.2026');
  });
}
