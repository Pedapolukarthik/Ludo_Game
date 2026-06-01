import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'local_storage.dart';

class AudioService {
  static final AudioService instance = AudioService._internal();
  AudioService._internal();

  // Distinct audio players to prevent bad overlaps and cutting each other off
  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _bgmPlayer = AudioPlayer();
  final AudioPlayer _clickPlayer = AudioPlayer();
  final AudioPlayer _victoryPlayer = AudioPlayer();

  bool _bgmPlaying = false;
  bool _bgmPaused = false;
  String? _currentBgmTrack;

  /// Initialize any audio settings if necessary
  Future<void> init() async {
    // Set release mode for BGM to loop
    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
  }

  /// Play a sound effect from assets/audio/
  Future<void> _playSfx(String fileName) async {
    if (!LocalStorage.isSfxEnabled()) return;
    try {
      // AudioPlayer in audioplayers 6.x uses AssetSource for assets
      // By default it searches inside the assets/ directory, so we pass 'audio/filename'
      await _sfxPlayer.stop();
      await _sfxPlayer.play(AssetSource('audio/$fileName'));
    } catch (e) {
      debugPrint('AudioService: Failed to play SFX $fileName. (File might be missing): $e');
    }
  }

  /// Play a button click sound from assets/audio/
  Future<void> playButtonClick() async {
    if (!LocalStorage.isSfxEnabled()) return;
    try {
      await _clickPlayer.stop();
      await _clickPlayer.play(AssetSource('audio/Button_click.mp3'));
    } catch (e) {
      debugPrint('AudioService: Failed to play button click: $e');
    }
  }

  /// Play a longer celebration or reward claim sound
  Future<void> _playVictory(String fileName) async {
    if (!LocalStorage.isSfxEnabled()) return;
    try {
      await _victoryPlayer.stop();
      await _victoryPlayer.play(AssetSource('audio/$fileName'));
    } catch (e) {
      debugPrint('AudioService: Failed to play victory/reward sound $fileName: $e');
    }
  }

  /// Play dice rolling sound
  void playDiceRoll() => _playSfx('dice_roll.mp3');

  /// Play distinct sound when a 6 is rolled
  void playRollSix() => _playVictory('Reward_claims.mp3');

  /// Play pawn move step sound
  void playPawnMove() => _playSfx('pawn_move.mp3');

  /// Play pawn capture sound
  void playPawnCapture() => _playSfx('wheel_spin.mp3');

  /// Play goal reached sound
  void playGoalReached() => _playSfx('goal_reached.mp3');

  /// Play safe zone reached sound
  void playSafeZone() => _playSfx('goal_reached.mp3');

  /// Play winning celebration sound
  void playWin() => _playVictory('Victory.mp3');

  /// Play losing/defeat sound
  void playLose() => _playVictory('game_lose.mp3');

  /// Play reward claim sound
  void playRewardClaim() => _playVictory('Reward_claims.mp3');

  /// Play spin wheel sound
  void playSpinWheel() => _playSfx('wheel_spin.mp3');

  /// Start playing background music
  Future<void> startBgm(String fileName) async {
    _currentBgmTrack = fileName;
    if (!LocalStorage.isMusicEnabled()) return;
    
    try {
      if (_bgmPlaying) {
        await _bgmPlayer.stop();
      }
      await _bgmPlayer.play(AssetSource('audio/$fileName'));
      _bgmPlaying = true;
      _bgmPaused = false;
    } catch (e) {
      debugPrint('AudioService: Failed to play BGM $fileName. (File might be missing): $e');
    }
  }

  /// Stop background music
  Future<void> stopBgm() async {
    try {
      await _bgmPlayer.stop();
      _bgmPlaying = false;
      _bgmPaused = false;
    } catch (e) {
      debugPrint('AudioService: Error stopping BGM: $e');
    }
  }

  /// Pause background music (e.g. during active gameplay)
  Future<void> pauseBgm() async {
    try {
      if (_bgmPlaying && !_bgmPaused) {
        await _bgmPlayer.pause();
        _bgmPaused = true;
      }
    } catch (e) {
      debugPrint('AudioService: Error pausing BGM: $e');
    }
  }

  /// Resume background music if enabled (e.g. returning to lobby)
  Future<void> resumeBgm() async {
    if (!LocalStorage.isMusicEnabled()) return;
    try {
      if (_bgmPaused) {
        await _bgmPlayer.resume();
        _bgmPaused = false;
      } else if (!_bgmPlaying && _currentBgmTrack != null) {
        await startBgm(_currentBgmTrack!);
      }
    } catch (e) {
      debugPrint('AudioService: Error resuming BGM: $e');
    }
  }

  /// Handle settings change dynamically
  void handleSettingsChanged() {
    // If music was disabled, stop the current BGM
    if (!LocalStorage.isMusicEnabled()) {
      stopBgm();
    } else {
      // If music was enabled, resume/start BGM
      resumeBgm();
    }
  }

  /// Dispose of all players to prevent memory leaks
  Future<void> dispose() async {
    await _sfxPlayer.dispose();
    await _bgmPlayer.dispose();
    await _clickPlayer.dispose();
    await _victoryPlayer.dispose();
  }
}

