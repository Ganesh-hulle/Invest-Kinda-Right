/// Runtime configuration that can be overridden in the Settings screen.
class AppConfig {
  final String baseUrl;
  final String wsBaseUrl;

  const AppConfig({
    required this.baseUrl,
    required this.wsBaseUrl,
  });

  /// Default: localhost (works for Android emulator via 10.0.2.2).
  factory AppConfig.defaultConfig() => const AppConfig(
        baseUrl: 'http://10.0.2.2:8080',
        wsBaseUrl: 'ws://10.0.2.2:8080',
      );

  AppConfig copyWith({String? baseUrl, String? wsBaseUrl}) => AppConfig(
        baseUrl: baseUrl ?? this.baseUrl,
        wsBaseUrl: wsBaseUrl ?? this.wsBaseUrl,
      );

  @override
  String toString() => 'AppConfig(baseUrl: $baseUrl, wsBaseUrl: $wsBaseUrl)';
}
