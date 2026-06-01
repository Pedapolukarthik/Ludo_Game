import 'package:flutter_tts/flutter_tts.dart';
import 'local_storage.dart';

class TtsService {
  static final TtsService instance = TtsService._internal();
  TtsService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      _initialized = true;
    } catch (e) {
      // Ignore initialization errors gracefully
    }
  }

  Future<void> speak(String text) async {
    if (!LocalStorage.isVoiceAssistanceEnabled()) return;
    if (!_initialized) {
      await init();
    }
    try {
      await _flutterTts.stop();
      await _flutterTts.speak(text);
    } catch (e) {
      // Ignore speak errors gracefully
    }
  }
}
