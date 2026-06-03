import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;

enum VoiceChatStatus {
  disconnected,
  connecting,
  connected,
  failed,
  permissionDenied,
}

class ParticipantVoiceState {
  final String identity;
  final String name;
  final bool isMuted;
  final bool isSpeaking;

  ParticipantVoiceState({
    required this.identity,
    required this.name,
    this.isMuted = false,
    this.isSpeaking = false,
  });

  ParticipantVoiceState copyWith({
    String? identity,
    String? name,
    bool? isMuted,
    bool? isSpeaking,
  }) {
    return ParticipantVoiceState(
      identity: identity ?? this.identity,
      name: name ?? this.name,
      isMuted: isMuted ?? this.isMuted,
      isSpeaking: isSpeaking ?? this.isSpeaking,
    );
  }
}

class VoiceChatState {
  final VoiceChatStatus status;
  final bool isMuted;
  final String? activeSpeaker;
  final String? lastError;
  final Map<String, ParticipantVoiceState> participants;
  final List<String> logs;

  VoiceChatState({
    this.status = VoiceChatStatus.disconnected,
    this.isMuted = true,
    this.activeSpeaker,
    this.lastError,
    this.participants = const {},
    this.logs = const [],
  });

  VoiceChatState copyWith({
    VoiceChatStatus? status,
    bool? isMuted,
    String? activeSpeaker,
    String? lastError,
    Map<String, ParticipantVoiceState>? participants,
    List<String>? logs,
    bool clearError = false,
  }) {
    return VoiceChatState(
      status: status ?? this.status,
      isMuted: isMuted ?? this.isMuted,
      activeSpeaker: activeSpeaker ?? this.activeSpeaker,
      lastError: clearError ? null : (lastError ?? this.lastError),
      participants: participants ?? this.participants,
      logs: logs ?? this.logs,
    );
  }
}

class VoiceChatService extends StateNotifier<VoiceChatState> {
  Room? _room;
  EventsListener<RoomEvent>? _listener;

  bool _enableLogs = true;

  VoiceChatService() : super(VoiceChatState());

  void setLoggingEnabled(bool enabled) {
    _enableLogs = enabled;
  }

  void _addLog(String msg) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    final logLine = '[$timestamp] $msg';
    if (_enableLogs) {
      debugPrint('[VoiceChatService] $logLine');
    }
    final trimmedLogs = state.logs.length > 80
        ? state.logs.sublist(state.logs.length - 80)
        : state.logs;
    state = state.copyWith(logs: [...trimmedLogs, logLine]);
  }

  static String normalizeLiveKitUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return 'wss://ludo-game-0ahtd6si.livekit.cloud';
    }
    if (trimmed.contains('localhost') || trimmed.contains('127.0.0.1')) {
      return 'wss://ludo-game-0ahtd6si.livekit.cloud';
    }
    if (trimmed.startsWith('https://')) {
      return 'wss://${trimmed.substring(8)}';
    }
    if (trimmed.startsWith('http://')) {
      return 'ws://${trimmed.substring(7)}';
    }
    return trimmed;
  }

  static bool isValidLiveKitToken(String? token) {
    if (token == null || token.trim().isEmpty) return false;
    final t = token.trim();
    if (t.startsWith('mock_lk_token_')) return false;
    return t.startsWith('eyJ') && t.split('.').length == 3;
  }

  static String formatVoiceRoomName(String roomCode) {
    final normalized = roomCode.trim().toUpperCase();
    return 'voice_$normalized';
  }

  Future<void> connect({
    required String token,
    required String url,
    required String roomCode,
    String? roomName,
  }) async {
    final cleanToken = token.trim();
    if (!isValidLiveKitToken(cleanToken)) {
      const err = 'Invalid voice token received from server';
      _addLog(err);
      state = state.copyWith(
        status: VoiceChatStatus.failed,
        lastError: err,
      );
      return;
    }

    final finalUrl = normalizeLiveKitUrl(url);
    final expectedRoom = roomName ?? formatVoiceRoomName(roomCode);

    if (state.status == VoiceChatStatus.connecting ||
        state.status == VoiceChatStatus.connected) {
      _addLog('Disconnecting previous session before reconnecting...');
      await disconnect();
    }

    state = state.copyWith(
      status: VoiceChatStatus.connecting,
      clearError: true,
    );
    _addLog('Connecting to $expectedRoom at $finalUrl (token len=${cleanToken.length})');

    var permissionStatus = await Permission.microphone.status;
    if (permissionStatus.isDenied) {
      permissionStatus = await Permission.microphone.request();
    }
    _addLog('Microphone permission: $permissionStatus');

    if (permissionStatus.isPermanentlyDenied) {
      await openAppSettings();
    }

    if (!permissionStatus.isGranted) {
      const err = 'Microphone permission denied';
      _addLog(err);
      state = state.copyWith(
        status: VoiceChatStatus.permissionDenied,
        lastError: err,
      );
      return;
    }

    try {
      try {
        final androidConfig = webrtc.AndroidAudioConfiguration(
          manageAudioFocus: true,
          androidAudioMode: webrtc.AndroidAudioMode.inCommunication,
          androidAudioFocusMode: webrtc.AndroidAudioFocusMode.gain,
          androidAudioStreamType: webrtc.AndroidAudioStreamType.voiceCall,
          androidAudioAttributesUsageType:
              webrtc.AndroidAudioAttributesUsageType.voiceCommunication,
          androidAudioAttributesContentType:
              webrtc.AndroidAudioAttributesContentType.speech,
        );
        await webrtc.WebRTC.initialize(options: {
          'androidAudioConfiguration': androidConfig.toMap(),
        });
        await webrtc.Helper.setAndroidAudioConfiguration(androidConfig);
      } catch (webrtcConfigError) {
        _addLog('WebRTC audio config skipped: $webrtcConfigError');
      }

      _room = Room();
      _listener = _room!.createListener();
      _setupListeners();

      final roomOptions = RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        defaultAudioPublishOptions: const AudioPublishOptions(dtx: true),
        defaultAudioOutputOptions: const AudioOutputOptions(speakerOn: true),
      );

      await _room!.connect(finalUrl, cleanToken, roomOptions: roomOptions);
      _addLog('Room connected: ${_room!.name ?? expectedRoom}');

      unawaited(Future<void>(() async {
        try {
          await _room!.setSpeakerOn(true);
        } catch (e) {
          _addLog('Speakerphone enable failed: $e');
        }
      }));

      // Publish mic track muted by default (push-to-talk / tap-to-unmute)
      try {
        await _room!.localParticipant?.setMicrophoneEnabled(true);
        await _room!.localParticipant?.setMicrophoneEnabled(false);
        _addLog('Microphone ready (starts muted)');
      } catch (pubErr) {
        _addLog('Microphone init warning: $pubErr');
      }

      state = state.copyWith(
        status: VoiceChatStatus.connected,
        isMuted: true,
        participants: _getCurrentParticipantsState(),
        clearError: true,
      );
    } catch (e) {
      final err = _formatConnectionError(e);
      _addLog('Connection failed: $err');
      await _cleanupRoom();
      state = state.copyWith(
        status: VoiceChatStatus.failed,
        lastError: err,
        isMuted: true,
      );
    }
  }

  /// Reset failed state so user can tap voice again without stale session.
  Future<void> prepareReconnect() async {
    if (state.status == VoiceChatStatus.failed ||
        state.status == VoiceChatStatus.connecting) {
      await disconnect();
    }
  }

  String _formatConnectionError(Object e) {
    final msg = e.toString();
    if (msg.contains('invalid authorization token') ||
        msg.contains('InvalidAuthorization')) {
      return 'invalid authorization token — check server LIVEKIT_API_KEY and LIVEKIT_API_SECRET';
    }
    if (msg.contains('ConnectionError') || msg.contains('ConnectException')) {
      return msg.replaceFirst('Exception: ', '').trim();
    }
    return msg.length > 120 ? '${msg.substring(0, 120)}...' : msg;
  }

  void _setupListeners() {
    if (_listener == null || _room == null) return;

    _listener!.on<TrackSubscribedEvent>((event) {
      if (event.track.kind == TrackType.AUDIO) {
        try {
          event.track.start();
        } catch (_) {}
      }
      _updateParticipants();
    });

    _listener!.on<TrackUnsubscribedEvent>((_) => _updateParticipants());
    _listener!.on<ParticipantConnectedEvent>((_) => _updateParticipants());
    _listener!.on<ParticipantDisconnectedEvent>((_) => _updateParticipants());

    _listener!.on<RoomDisconnectedEvent>((event) {
      _addLog('Room disconnected: ${event.reason}');
      state = state.copyWith(status: VoiceChatStatus.disconnected);
    });

    _room!.addListener(_updateSpeakerAndSpeakingStates);
  }

  void _updateParticipants() {
    state = state.copyWith(participants: _getCurrentParticipantsState());
  }

  void _updateSpeakerAndSpeakingStates() {
    if (_room == null) return;
    String? activeSpeaker;
    for (var p in _room!.remoteParticipants.values) {
      if (p.isSpeaking) {
        activeSpeaker = p.name.isNotEmpty ? p.name : p.identity;
        break;
      }
    }
    if (_room!.localParticipant?.isSpeaking ?? false) {
      activeSpeaker = 'You';
    }

    state = state.copyWith(
      activeSpeaker: activeSpeaker,
      participants: _getCurrentParticipantsState(),
    );
  }

  Map<String, ParticipantVoiceState> _getCurrentParticipantsState() {
    if (_room == null) return {};
    final map = <String, ParticipantVoiceState>{};

    final local = _room!.localParticipant;
    if (local != null) {
      map[local.identity] = ParticipantVoiceState(
        identity: local.identity,
        name: local.name.isNotEmpty ? local.name : 'You',
        isMuted: !local.isMicrophoneEnabled(),
        isSpeaking: local.isSpeaking,
      );
    }

    for (var rp in _room!.remoteParticipants.values) {
      map[rp.identity] = ParticipantVoiceState(
        identity: rp.identity,
        name: rp.name.isNotEmpty ? rp.name : rp.identity,
        isMuted: !rp.isMicrophoneEnabled(),
        isSpeaking: rp.isSpeaking,
      );
    }

    return map;
  }

  Future<void> toggleMute() async {
    if (_room == null || state.status != VoiceChatStatus.connected) {
      _addLog('Cannot toggle mute — not connected');
      return;
    }
    await setMuted(!state.isMuted);
  }

  Future<void> setMuted(bool mute) async {
    if (_room == null || state.status != VoiceChatStatus.connected) {
      _addLog('Cannot set mute — not connected');
      return;
    }
    try {
      await _room!.localParticipant?.setMicrophoneEnabled(!mute);
      state = state.copyWith(
        isMuted: mute,
        participants: _getCurrentParticipantsState(),
      );
      _addLog(mute ? 'Microphone muted' : 'Microphone unmuted');
    } catch (e) {
      _addLog('Failed to set mute: $e');
    }
  }

  Future<void> _cleanupRoom() async {
    _listener?.dispose();
    _listener = null;
    try {
      await _room?.disconnect();
      await _room?.dispose();
    } catch (_) {}
    _room = null;
  }

  Future<void> disconnect() async {
    _addLog('Disconnecting voice session');
    await _cleanupRoom();
    state = state.copyWith(
      status: VoiceChatStatus.disconnected,
      isMuted: true,
      activeSpeaker: null,
      participants: const {},
      clearError: true,
    );
  }

  bool get hasLocalAudioTrack {
    if (_room == null) return false;
    final local = _room!.localParticipant;
    if (local == null) return false;
    return local.audioTrackPublications.isNotEmpty;
  }

  bool get isLocalAudioTrackPublished {
    if (_room == null) return false;
    final local = _room!.localParticipant;
    if (local == null) return false;
    return local.audioTrackPublications.any((pub) => pub.track != null && !pub.muted);
  }

  bool get hasRemoteAudioSubscribed {
    if (_room == null) return false;
    for (var participant in _room!.remoteParticipants.values) {
      if (participant.audioTrackPublications.any((pub) => pub.subscribed)) {
        return true;
      }
    }
    return false;
  }

  String get currentRoomName {
    if (_room == null) return 'N/A';
    return _room!.name ?? 'N/A';
  }

  int get participantCount {
    if (_room == null) return 0;
    return _room!.remoteParticipants.length + (_room!.localParticipant != null ? 1 : 0);
  }

  @override
  void dispose() {
    _cleanupRoom();
    super.dispose();
  }
}

final voiceChatProvider = StateNotifierProvider<VoiceChatService, VoiceChatState>((ref) {
  final service = VoiceChatService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});
