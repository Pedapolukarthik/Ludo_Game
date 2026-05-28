class EnvConfig {
  /// The base URL of the game server.
  /// Can be overridden at compile-time with:
  /// `--dart-define=SERVER_URL=https://your-render-url.onrender.com`
  static const String serverUrl = String.fromEnvironment(
    'SERVER_URL',
    defaultValue: 'https://ludo-backend-f1wa.onrender.com',
  );

  static String get baseUrl => '$serverUrl/api';
  static String get socketUrl => serverUrl;
}
