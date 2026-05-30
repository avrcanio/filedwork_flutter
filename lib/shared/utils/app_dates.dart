import 'package:intl/intl.dart';

/// Format datuma za Django API (query, POST, PATCH).
const apiDatePattern = 'yyyy-MM-dd';

/// Format datuma za prikaz korisniku.
const displayDatePattern = 'dd.MM.yyyy';

final _apiFormat = DateFormat(apiDatePattern);
final _displayFormat = DateFormat(displayDatePattern);

/// Parsira API datum (`yyyy-MM-dd`) u lokalni kalendar.
DateTime? parseApiDate(String? value) {
  if (value == null || value.isEmpty) return null;
  try {
    return _apiFormat.parseStrict(value);
  } catch (_) {
    return DateTime.tryParse(value);
  }
}

/// [DateTime] → string za API i interne usporedbe.
String toApiDate(DateTime date) => _apiFormat.format(date);

/// API string → prikaz; fallback na original ako ne parsira.
String formatDateForDisplay(String? value) {
  if (value == null || value.isEmpty) return '';
  final parsed = parseApiDate(value);
  if (parsed == null) return value;
  return _displayFormat.format(parsed);
}

/// Lokalni [DateTime] (npr. nakon DatePickera) → prikaz.
String formatDisplayDate(DateTime date) => _displayFormat.format(date);
