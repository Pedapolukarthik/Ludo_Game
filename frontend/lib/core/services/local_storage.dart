import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static const String authBoxName = 'auth_box';
  static const String tokenKey = 'jwt_token';
  static const String userKey = 'user_profile';
  
  static late SharedPreferences _prefs;

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(authBoxName);
    _prefs = await SharedPreferences.getInstance();
  }

  // --- Token Persistence ---
  
  static Future<void> saveToken(String token) async {
    final box = Hive.box(authBoxName);
    await box.put(tokenKey, token);
  }

  static String? getToken() {
    final box = Hive.box(authBoxName);
    return box.get(tokenKey) as String?;
  }

  static Future<void> clearToken() async {
    final box = Hive.box(authBoxName);
    await box.delete(tokenKey);
  }

  // --- User Profile JSON Cache ---

  static Future<void> saveUserProfile(Map<String, dynamic> userMap) async {
    final box = Hive.box(authBoxName);
    await box.put(userKey, userMap);
  }

  static Map<String, dynamic>? getUserProfile() {
    final box = Hive.box(authBoxName);
    final profile = box.get(userKey);
    if (profile == null) return null;
    return Map<String, dynamic>.from(profile as Map);
  }

  static Future<void> clearUserProfile() async {
    final box = Hive.box(authBoxName);
    await box.delete(userKey);
  }

  // --- App Settings (Preferences) ---
  
  static Future<void> setMusicEnabled(bool enabled) async {
    await _prefs.setBool('music_enabled', enabled);
  }

  static bool isMusicEnabled() {
    return _prefs.getBool('music_enabled') ?? true;
  }

  static Future<void> setSfxEnabled(bool enabled) async {
    await _prefs.setBool('sfx_enabled', enabled);
  }

  static bool isSfxEnabled() {
    return _prefs.getBool('sfx_enabled') ?? true;
  }

  static Future<void> setVoiceAssistanceEnabled(bool enabled) async {
    await _prefs.setBool('voice_assistance_enabled', enabled);
  }

  static bool isVoiceAssistanceEnabled() {
    return _prefs.getBool('voice_assistance_enabled') ?? true;
  }

  static Future<void> clearAll() async {
    final box = Hive.box(authBoxName);
    await box.clear();
    await _prefs.clear();
  }
}
