import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceCommandService {
  VoiceCommandService._internal();
  static final VoiceCommandService instance = VoiceCommandService._internal();

  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;
  bool _isListening = false;
  Map<String, VoidCallback> _activeCommands = {};
  DateTime? _lastTriggerTime;

  // Track if we are running to manage the auto-restart loop
  bool get isListening => _isListening;

  Future<bool> initialize() async {
    if (_isInitialized) return true;
    try {
      _isInitialized = await _speechToText.initialize(
        onStatus: _handleStatus,
        onError: _handleError,
      );
      debugPrint('VoiceCommandService initialized: $_isInitialized');
      return _isInitialized;
    } catch (e) {
      debugPrint('VoiceCommandService initialization error: $e');
      _isInitialized = false;
      return false;
    }
  }

  void startListening(Map<String, VoidCallback> commands) async {
    _activeCommands = commands;
    _isListening = true;

    if (!_isInitialized) {
      final success = await initialize();
      if (!success) {
        debugPrint('VoiceCommandService could not start: initialization failed');
        return;
      }
    }

    _startListeningLoop();
  }

  void stopListening() {
    _isListening = false;
    _activeCommands.clear();
    try {
      if (_speechToText.isListening) {
        _speechToText.stop();
      }
    } catch (e) {
      debugPrint('Error stopping speech engine: $e');
    }
  }

  bool _isStartingListen = false;

  void _startListeningLoop() async {
    if (!_isListening) return;
    if (_isStartingListen) return;

    _isStartingListen = true;
    try {
      if (!_speechToText.isListening) {
        await _speechToText.listen(
          onResult: (result) {
            final words = result.recognizedWords.toLowerCase().trim();
            debugPrint('Speech recognized: "$words" (final: ${result.finalResult})');
            _checkForKeywords(words);
          },
          listenMode: ListenMode.confirmation,
          partialResults: true,
          pauseFor: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      debugPrint('Error starting listening loop: $e');
      if (_isListening) {
        Future.delayed(const Duration(seconds: 2), _startListeningLoop);
      }
    } finally {
      _isStartingListen = false;
    }
  }

  void _checkForKeywords(String text) {
    if (text.isEmpty) return;

    final now = DateTime.now();
    if (_lastTriggerTime != null && now.difference(_lastTriggerTime!) < const Duration(milliseconds: 1500)) {
      return;
    }

    for (final entry in _activeCommands.entries) {
      final keyword = entry.key.toLowerCase();
      if (text.contains(keyword)) {
        _lastTriggerTime = now;
        debugPrint('Voice command keyword matched: "$keyword". Triggering callback.');
        
        try {
          _speechToText.stop();
        } catch (_) {}

        entry.value();

        if (_isListening) {
          Future.delayed(const Duration(milliseconds: 500), _startListeningLoop);
        }
        break;
      }
    }
  }

  void _handleStatus(String status) {
    debugPrint('Speech recognizer status change: $status');
    if ((status == 'done' || status == 'notListening') && _isListening) {
      // Add a 500ms delay to give the native speech engine time to clean up
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_isListening && !_speechToText.isListening) {
          _startListeningLoop();
        }
      });
    }
  }

  void _handleError(dynamic error) {
    debugPrint('Speech recognizer error occurred: $error');
    // We let the status handler manage the restart when status transitions to done/notListening.
    // This avoids parallel restart loops and error_busy states.
  }
}
