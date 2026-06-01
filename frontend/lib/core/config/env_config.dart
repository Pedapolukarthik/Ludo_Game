import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class EnvConfig {
  static const String _envUrl = String.fromEnvironment('SERVER_URL');
  static const String productionUrl = 'https://ludo-backend-f1wa.onrender.com';

  /// The base URL of the game server.
  static String get serverUrl {
    if (_envUrl.isNotEmpty) return _envUrl;

    return productionUrl;
  }

  static String get baseUrl => '$serverUrl/api';
  static String get socketUrl => serverUrl;
}
