import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class VoiceNoteService {
  VoiceNoteService._internal();
  static final VoiceNoteService instance = VoiceNoteService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  String? _lastRecordPath;

  String? get lastRecordPath => _lastRecordPath;

  Future<bool> hasPermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (e) {
      debugPrint('VoiceNoteService: Permission check failed: $e');
      return false;
    }
  }

  Future<bool> startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _recorder.start(const RecordConfig(), path: path);
        _lastRecordPath = path;
        debugPrint('VoiceNoteService: Recording started at $path');
        return true;
      } else {
        debugPrint('VoiceNoteService: Recording failed - Permission denied');
        return false;
      }
    } catch (e) {
      debugPrint('VoiceNoteService: Error starting recording: $e');
      return false;
    }
  }

  Future<String?> stopRecording() async {
    try {
      final path = await _recorder.stop();
      _lastRecordPath = path;
      debugPrint('VoiceNoteService: Recording stopped. Path: $path');
      return path;
    } catch (e) {
      debugPrint('VoiceNoteService: Error stopping recording: $e');
      return null;
    }
  }

  void dispose() {
    try {
      _recorder.dispose();
    } catch (e) {
      debugPrint('VoiceNoteService: Error disposing recorder: $e');
    }
  }
}
