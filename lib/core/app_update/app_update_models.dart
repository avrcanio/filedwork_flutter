class AppUpdateConfig {
  const AppUpdateConfig({
    required this.app,
    required this.platform,
    required this.minVersion,
    required this.latestVersion,
    required this.forceUpdate,
    required this.storeUrl,
    required this.message,
  });

  factory AppUpdateConfig.fromJson(Map<String, dynamic> json) {
    return AppUpdateConfig(
      app: json['app'] as String? ?? 'roadly',
      platform: json['platform'] as String? ?? 'android',
      minVersion: json['min_version'] as String? ?? '0.0.0',
      latestVersion: json['latest_version'] as String? ?? '0.0.0',
      forceUpdate: json['force_update'] as bool? ?? false,
      storeUrl: json['store_url'] as String? ?? '',
      message: json['message'] as String? ??
          'Dostupna je nova verzija aplikacije Roadly.',
    );
  }

  final String app;
  final String platform;
  final String minVersion;
  final String latestVersion;
  final bool forceUpdate;
  final String storeUrl;
  final String message;
}

enum AppUpdateAction {
  none,
  optional,
  required,
}
