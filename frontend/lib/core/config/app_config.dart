/// Runtime configuration that can be overridden in the Settings screen.
class AppConfig {
  final String baseUrl;
  final String wsBaseUrl;

  const AppConfig({
    required this.baseUrl,
    required this.wsBaseUrl,
  });

  /// Default: localhost (works for physical device via adb reverse and web/desktop).
  factory AppConfig.defaultConfig() => const AppConfig(
        baseUrl: 'http://127.0.0.1:8080',
        wsBaseUrl: 'ws://127.0.0.1:8080',
      );

  AppConfig copyWith({String? baseUrl, String? wsBaseUrl}) => AppConfig(
        baseUrl: baseUrl ?? this.baseUrl,
        wsBaseUrl: wsBaseUrl ?? this.wsBaseUrl,
      );

  @override
  String toString() => 'AppConfig(baseUrl: $baseUrl, wsBaseUrl: $wsBaseUrl)';
}
