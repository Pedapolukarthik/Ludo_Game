import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class EnvConfig {
  static const String _envUrl = String.fromEnvironment('SERVER_URL');
  static const String productionUrl = 'https://ludo-backend-f1wa.onrender.com';

  // Dynamic fallback variable if the local/emulator server is unreachable
  static String? _fallbackServerUrl;

  /// The base URL of the game server.
  static String get serverUrl {
    if (_envUrl.isNotEmpty) return _envUrl;
    if (_fallbackServerUrl != null) return _fallbackServerUrl!;

    // In debug/development mode, default to emulator or local server
    if (kDebugMode) {
      if (!kIsWeb && Platform.isAndroid) {
        return 'http://10.0.2.2:5000';
      }
      return 'http://localhost:5000';
    }

    return productionUrl;
  }

  /// Triggers a fallback to the production backend if the local server is unreachable.
  static void useProductionFallback() {
    _fallbackServerUrl ??= productionUrl;
  }

  static String get baseUrl => '$serverUrl/api';
  static String get socketUrl => serverUrl;
}
