/// Globalna konfiguracija API-ja.
///
/// `baseUrl` se može nadjačati pri buildu:
///   flutter run --dart-define=API_BASE_URL=https://fw.dalekopro.hr
class ApiConfig {
  const ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://fw.dalekopro.hr',
  );

  static const String apiPrefix = '/api';
  static const String fieldworkPrefix = '/api/fieldwork';

  static const String loginPath = '$apiPrefix/auth/login/';
  static const String appConfigPath = '$apiPrefix/auth/mobile/app-config/';
  static const String profilePath = '$apiPrefix/auth/profile/';

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
