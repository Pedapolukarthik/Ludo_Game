import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/network/socket_provider.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/local_storage.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/ludo_coordinates.dart';
import '../../../../core/services/tts_service.dart';
import '../../../../core/services/voice_chat_service.dart';

class GameRoomScreen extends ConsumerStatefulWidget {
  final String roomCode;
  final Map<String, dynamic> initialGameState;

  const GameRoomScreen({
    super.key,
    required this.roomCode,
    required this.initialGameState,
  });

  @override
  ConsumerState<GameRoomScreen> createState() => _GameRoomScreenState();
}

class _GameRoomScreenState extends ConsumerState<GameRoomScreen> with TickerProviderStateMixin {
  // Game states
  bool _isOffline = false;
  bool _isLocalMultiplayer = false;
  late String _activeColor;
  late String _rollState; // 'idle', 'rolled', 'moving'
  int? _diceValue;
  late Map<String, List<int>> _pawns;
  late List<dynamic> _players;
  late List<String> _colors;
  List<dynamic> _history = [];
  List<Map<String, dynamic>> _possibleMoves = [];

  // UI state
  final List<Map<String, dynamic>> _chatMessages = [];
  final TextEditingController _chatController = TextEditingController();
  
  // Temporary visibility variable for the developer debug overlay panel
  bool _showVoiceDebugPanel = false;
  
  // Track push-to-talk press status locally to animate the Hold-to-Talk button
  bool _isHoldingMic = false;
  
  // Floating emoji animation state
  final Map<String, List<String>> _floatingEmojis = {
    'Red': [], 'Green': [], 'Yellow': [], 'Blue': []
  };

  // Turn timers / animations
  late AnimationController _diceController;
  final Random _random = Random();
  String _botDifficulty = 'medium';

  @override
  void initState() {
    super.initState();
    _isOffline = widget.roomCode.startsWith('BOT_') || widget.roomCode.startsWith('LOCAL_');
    _isLocalMultiplayer = widget.roomCode.startsWith('LOCAL_');
    
    // Setup dice controller
    _diceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _parseGameState(widget.initialGameState);

    if (_isOffline) {
      if (_isLocalMultiplayer) {
        _addHistoryMessage('Local multiplayer match started');
      } else {
        _botDifficulty = widget.roomCode.split('_').last.toLowerCase();
        _addHistoryMessage('Local practice game started vs AI ($_botDifficulty)');
      }
    } else {
      _setupSocketListeners();
    }

    // Pause background lobby music during active match
    AudioService.instance.pauseBgm();
  }
  void dispose() {
    // Resume background lobby music when leaving match
    AudioService.instance.resumeBgm();
    
    // Clean up voice chat room session
    Future.microtask(() {
      ref.read(voiceChatProvider.notifier).disconnect();
    });
    _diceController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  void _parseGameState(Map<String, dynamic> state) {
    setState(() {
      _activeColor = state['activeColor'] ?? 'Red';
      _rollState = state['rollState'] ?? 'idle';
      _diceValue = state['diceValue'];
      _players = state['players'] ?? [];
      _colors = List<String>.from(state['colors'] ?? ['Red', 'Green', 'Yellow', 'Blue']);
      _history = state['history'] ?? [];
      
      // Parse pawns safely
      final rawPawns = state['pawns'] ?? {};
      _pawns = {};
      rawPawns.forEach((key, val) {
        _pawns[key] = List<int>.from(val);
      });
      
      // Recalculate possible moves for current local user if offline
      if (_isOffline && (_isLocalMultiplayer || _activeColor == 'Red') && _rollState == 'rolled' && _diceValue != null) {
        _calculateOfflinePossibleMoves();
      } else if (!_isOffline) {
        // If online, potential moves list is sent by server in socket responses
      }
    });
  }

  // --- Socket.IO Integration ---

  void _setupSocketListeners() {
    final socket = ref.read(socketServiceProvider);

    socket.onDiceRolled = (data) {
      if (mounted) {
        setState(() {
          _diceValue = data['value'];
          _rollState = data['gameState']['rollState'] ?? 'rolled';
          _activeColor = data['color'];
          _possibleMoves = List<Map<String, dynamic>>.from(data['possibleMoves'] ?? []);
          _parseGameState(data['gameState']);
        });
        
        // Trigger dice shake
        _diceController.reset();
        _diceController.forward();
        _playSfx('roll');

        // Speak ONLY the player color and dice number
        final String? color = data['color'];
        final val = data['value'];
        if (color != null && val != null) {
          TtsService.instance.speak('$color $val');
        }
      }
    };

    socket.onPawnMoved = (data) {
      if (mounted) {
        _playSfx('move');
        if (data['isKill'] == true) {
          _playSfx('capture');
        }
        if (data['isGoal'] == true) _playSfx('goal');
        
        final move = data['move'];
        if (move != null && move['to'] != null) {
          final int toStep = move['to'];
          if (toStep < 57 && _isStepSafe(data['color'], toStep)) {
            _playSfx('safe');
          }
        }
        
        _parseGameState(data['gameState']);

        // Speak only new history messages from this move (stop searching at the turn's roll message)
        final history = data['gameState']['history'] as List<dynamic>?;
        if (history != null && history.isNotEmpty) {
          try {
            final List<String> newMessagesToSpeak = [];
            for (final h in history.reversed) {
              final text = h['text'] as String?;
              if (text == null) continue;
              final lowerText = text.toLowerCase();
              
              // Stop looking back if we encounter a roll or forfeit event of this turn
              if (lowerText.contains('rolled') || lowerText.contains('forfeited')) {
                break;
              }
              
              if (lowerText.contains('captured') ||
                  lowerText.contains('reached 3 points') ||
                  lowerText.contains('won') ||
                  lowerText.contains('extra roll')) {
                newMessagesToSpeak.add(text);
              }
            }
            
            // Speak new events chronologically
            for (final msg in newMessagesToSpeak.reversed) {
              TtsService.instance.speak(msg);
            }
          } catch (_) {
            // Ignore lookup/cast errors
          }
        }
      }
    };

    socket.onTurnChanged = (data) {
      if (mounted) {
        setState(() {
          if (data['possibleMoves'] != null) {
            _possibleMoves = List<Map<String, dynamic>>.from(data['possibleMoves']);
          }
        });
        _parseGameState(data['gameState']);
      }
    };

    socket.onChatMessage = (data) {
      if (mounted) {
        setState(() {
          _chatMessages.add({
            'senderName': data['senderName'],
            'text': data['text'],
            'isSelf': data['senderId'] == ref.read(authProvider).user?.id,
          });
        });
      }
    };

    socket.onEmojiReaction = (data) {
      if (mounted) {
        _triggerEmojiReaction(data['senderColor'], data['reactionId']);
      }
    };

    socket.onVoiceToken = (data) {
      if (mounted) _handleVoiceTokenPayload(Map<String, dynamic>.from(data));
    };

    socket.onVoiceTokenError = (message) {
      debugPrint('[LiveKit] voice_token_error: $message');
      if (mounted) {
        _addHistoryMessage('Voice token error: $message');
        _showVoiceUnavailable(message);
        _fetchVoiceTokenViaHttpIfAvailable();
      }
    };

    socket.onError = (message) {
      if (message.toLowerCase().contains('voice')) {
        debugPrint('[LiveKit] socket error: $message');
        if (mounted) {
          _addHistoryMessage(message);
          _showVoiceUnavailable(message);
          _fetchVoiceTokenViaHttpIfAvailable();
        }
      }
    };

    socket.onGameEnded = (data) {
      if (mounted) {
        _parseGameState(data['gameState']);
        _showWinnerDialog(data['winnerName'], data['winnerColor']);
      }
    };
  }

  // --- Offline Engine Logic ---

  void _calculateOfflinePossibleMoves() {
    if (_diceValue == null) return;
    
    final List<int> myPawns = _pawns[_activeColor]!;
    final List<Map<String, dynamic>> moves = [];

    for (int i = 0; i < 4; i++) {
      final int step = myPawns[i];
      if (step == 0) {
        if (_diceValue == 6) {
          moves.add({'pawnId': i, 'type': 'unlock', 'from': 0, 'to': 1});
        }
      } else if (step > 0 && step < 57) {
        final int next = step + _diceValue!;
        if (next <= 57) {
          moves.add({
            'pawnId': i,
            'type': next == 57 ? 'goal' : 'move',
            'from': step,
            'to': next
          });
        }
      }
    }
    setState(() {
      _possibleMoves = moves;
    });

    if (_possibleMoves.isEmpty) {
      final activePlayer = _findPlayerByColor(_activeColor);
      final String activePlayerName = activePlayer['name'] ?? _activeColor;
      final noMovesMsg = '$activePlayerName has no moves. Passing turn...';
      _addHistoryMessage(noMovesMsg);
      TtsService.instance.speak(noMovesMsg);
      // Only schedule turn passage automatically for human players.
      // For the bot, _executeBotPawnSelection is already scheduled and will handle passing the turn.
      if (!(_activeColor == 'Green' && !_isLocalMultiplayer)) {
        Future.delayed(const Duration(milliseconds: 1500), _passOfflineTurn);
      }
    }
  }

  void _rollOfflineDice() {
    if (_rollState != 'idle') return;

    setState(() {
      _rollState = 'rolled';
      _diceValue = _random.nextInt(6) + 1;
      
      _diceController.reset();
      _diceController.forward();
      _playSfx('roll');
    });

    final activePlayer = _findPlayerByColor(_activeColor);
    final String activePlayerName = activePlayer['name'] ?? _activeColor;
    final String speakText = '$activePlayerName rolled $_diceValue';
    
    _addHistoryMessage(speakText);
    TtsService.instance.speak(speakText);

    if (_diceValue == 6) {
      // Local consecutive check is omitted for simplicity in practice, or capped
    }

    _calculateOfflinePossibleMoves();

    // If bot rolled, perform automated decision
    if (_activeColor == 'Green' && !_isLocalMultiplayer) {
      Future.delayed(const Duration(milliseconds: 1200), _executeBotPawnSelection);
    }
  }

  void _moveOfflinePawn(int pawnId) {
    if (_rollState != 'rolled') return;
    
    final move = _possibleMoves.firstWhere((m) => m['pawnId'] == pawnId, orElse: () => <String, dynamic>{});
    if (move.isEmpty) return;

    final int goalCountBefore = _pawns[_activeColor]!.where((s) => s == 57).length;

    setState(() {
      _rollState = 'idle';
      _pawns[_activeColor]![pawnId] = move['to'];
    });

    _playSfx('move');

    // Capturing check
    bool isKill = false;
    final int nextStep = move['to'];
    if (nextStep >= 1 && nextStep <= 51) {
      final targetIdx = _getGeneralTrackIndex(_activeColor, nextStep);
      if (targetIdx != null && !_isSafeTrackIndex(targetIdx)) {
        _pawns.forEach((oppColor, oppPawns) {
          if (oppColor != _activeColor) {
            for (int i = 0; i < 4; i++) {
              final oppStep = oppPawns[i];
              if (_getGeneralTrackIndex(oppColor, oppStep) == targetIdx) {
                oppPawns[i] = 0;
                isKill = true;
                final activePlayerName = _findPlayerByColor(_activeColor)['name'] ?? _activeColor;
                final oppPlayerName = _findPlayerByColor(oppColor)['name'] ?? oppColor;
                final killText = '$activePlayerName captured $oppPlayerName\'s pawn!';
                _addHistoryMessage(killText);
                TtsService.instance.speak(killText);
              }
            }
          }
        });
      }
    }

    // Check if player reached 3 points (exactly 3 pawns in goal now, but was 2 before)
    final int goalCountAfter = _pawns[_activeColor]!.where((s) => s == 57).length;
    if (goalCountBefore == 2 && goalCountAfter == 3) {
      final remainingPawnId = _pawns[_activeColor]!.indexWhere((s) => s != 57);
      if (remainingPawnId != -1) {
        final currentStep = _pawns[_activeColor]![remainingPawnId];
        final bonusStep = min(57, currentStep + 4);
        setState(() {
          _pawns[_activeColor]![remainingPawnId] = bonusStep;
        });

        final activePlayerName = _findPlayerByColor(_activeColor)['name'] ?? _activeColor;
        final bonusMsg = '$activePlayerName reached 3 points! Pawn ${remainingPawnId + 1} automatically moved 4 steps.';
        _addHistoryMessage(bonusMsg);
        TtsService.instance.speak(bonusMsg);

        // Capturing check for bonus step
        if (bonusStep >= 1 && bonusStep <= 51) {
          final targetIdx = _getGeneralTrackIndex(_activeColor, bonusStep);
          if (targetIdx != null && !_isSafeTrackIndex(targetIdx)) {
            _pawns.forEach((oppColor, oppPawns) {
              if (oppColor != _activeColor) {
                for (int i = 0; i < 4; i++) {
                  final oppStep = oppPawns[i];
                  if (_getGeneralTrackIndex(oppColor, oppStep) == targetIdx) {
                    oppPawns[i] = 0;
                    isKill = true;
                    final oppPlayerName = _findPlayerByColor(oppColor)['name'] ?? oppColor;
                    final killText = '$activePlayerName captured $oppPlayerName\'s pawn!';
                    _addHistoryMessage(killText);
                    TtsService.instance.speak(killText);
                  }
                }
              }
            });
          }
        }
      }
    }

    if (isKill) _playSfx('capture');
    if (move['to'] == 57) {
      _playSfx('goal');
    } else if (_isStepSafe(_activeColor, move['to'])) {
      _playSfx('safe');
    }

    // Win check
    if (_pawns[_activeColor]!.every((s) => s == 57)) {
      final activePlayer = _findPlayerByColor(_activeColor);
      final String winnerName = activePlayer['name'] ?? _activeColor;
      _showWinnerDialog(winnerName, _activeColor);
      return;
    }

    // Extra roll check (rolled 6, captured, or reached goal)
    final getExtra = (_diceValue == 6 || isKill || move['to'] == 57);
    
    if (getExtra) {
      setState(() {
        _diceValue = null;
        _rollState = 'idle';
      });
      final activePlayer = _findPlayerByColor(_activeColor);
      final String activePlayerName = activePlayer['name'] ?? _activeColor;
      final extraRollMsg = '$activePlayerName gets an extra roll!';
      _addHistoryMessage(extraRollMsg);
      TtsService.instance.speak(extraRollMsg);
      if (_activeColor == 'Green' && !_isLocalMultiplayer) {
        Future.delayed(const Duration(milliseconds: 1000), _rollOfflineDice);
      }
    } else {
      _passOfflineTurn();
    }
  }

  void _passOfflineTurn() {
    setState(() {
      _diceValue = null;
      _rollState = 'idle';
      _possibleMoves = [];
      
      // Dynamic turn rotation based on active color list
      int nextIdx = (_colors.indexOf(_activeColor) + 1) % _colors.length;
      _activeColor = _colors[nextIdx];
    });

    if (_activeColor == 'Green' && !_isLocalMultiplayer) {
      // Bot turn
      Future.delayed(const Duration(milliseconds: 1000), _rollOfflineDice);
    }
  }

  void _executeBotPawnSelection() {
    if (_possibleMoves.isEmpty) {
      _passOfflineTurn();
      return;
    }

    // Call local bot algorithm implementation
    final chosenPawnId = _selectLocalBotMove();
    if (chosenPawnId != null) {
      _moveOfflinePawn(chosenPawnId);
    }
  }

  int? _selectLocalBotMove() {
    if (_possibleMoves.isEmpty) return null;
    if (_possibleMoves.length == 1) return _possibleMoves[0]['pawnId'];

    if (_botDifficulty == 'easy') {
      return _possibleMoves[_random.nextInt(_possibleMoves.length)]['pawnId'];
    }

    if (_botDifficulty == 'medium') {
      for (var m in _possibleMoves) {
        if (m['type'] == 'goal') return m['pawnId'];
      }
      for (var m in _possibleMoves) {
        if (m['type'] == 'unlock') return m['pawnId'];
      }
      var best = _possibleMoves[0];
      for (var m in _possibleMoves) {
        if (m['from'] > best['from']) best = m;
      }
      return best['pawnId'];
    }

    // Hard Mode
    for (var m in _possibleMoves) {
      if (m['type'] == 'goal') return m['pawnId'];
    }

    final List<Map<String, dynamic>> moveScores = [];
    for (var move in _possibleMoves) {
      int score = 0;
      final int pawnId = move['pawnId'];
      final int targetStep = move['to'];
      final int currentStep = move['from'];

      final int? targetTrackIndex = _getGeneralTrackIndex('Green', targetStep);

      // A. Check Capture
      bool isKill = false;
      if (targetTrackIndex != null && !_isSafeTrackIndex(targetTrackIndex)) {
        for (var oppStep in _pawns['Red']!) {
          if (_getGeneralTrackIndex('Red', oppStep) == targetTrackIndex) {
            isKill = true;
          }
        }
      }
      if (isKill) score += 1000;

      // B. Evade danger
      if (_isUnderThreatLocal('Green', currentStep)) {
        score += 300;
      }

      // C. Land in safe zone
      if (targetTrackIndex != null && _isSafeTrackIndex(targetTrackIndex)) {
        score += 150;
      }

      // D. Avoid putting in threat
      if (targetTrackIndex != null && !_isSafeTrackIndex(targetTrackIndex)) {
        bool threatAfter = false;
        for (var oppStep in _pawns['Red']!) {
          final int? oppIdx = _getGeneralTrackIndex('Red', oppStep);
          if (oppIdx != null) {
            final int distance = (targetTrackIndex - oppIdx + 52) % 52;
            if (distance > 0 && distance <= 6) threatAfter = true;
          }
        }
        if (threatAfter) score -= 100;
      }

      // E. Unlock priority
      if (move['type'] == 'unlock') score += 200;

      // F. Rush priority
      score += (currentStep * 2);

      moveScores.add({'pawnId': pawnId, 'score': score});
    }

    moveScores.sort((a, b) => b['score'].compareTo(a['score']));
    return moveScores[0]['pawnId'];
  }

  int? _getGeneralTrackIndex(String color, int stepCount) {
    if (stepCount < 1 || stepCount > 51) return null;
    int start = 0;
    if (color == 'Red') start = 0;
    else if (color == 'Green') start = 13;
    else if (color == 'Yellow') start = 26;
    else if (color == 'Blue') start = 39;
    return (start + stepCount - 1) % 52;
  }

  bool _isSafeTrackIndex(int idx) {
    final List<int> safes = [0, 8, 13, 21, 26, 34, 39, 47];
    return safes.contains(idx);
  }

  bool _isStepSafe(String color, int step) {
    if (step >= 52) return true;
    final trackIdx = _getGeneralTrackIndex(color, step);
    if (trackIdx == null) return false;
    return _isSafeTrackIndex(trackIdx);
  }

  bool _isUnderThreatLocal(String color, int step) {
    if (step < 1 || step > 51) return false;
    final int? trackIdx = _getGeneralTrackIndex(color, step);
    if (trackIdx == null || _isSafeTrackIndex(trackIdx)) return false;

    bool threat = false;
    _pawns.forEach((oppColor, oppPawns) {
      if (oppColor != color) {
        for (var oppStep in oppPawns) {
          if (oppStep < 1 || oppStep > 51) continue;
          final int? oppIdx = _getGeneralTrackIndex(oppColor, oppStep);
          if (oppIdx != null) {
            final int dist = (trackIdx - oppIdx + 52) % 52;
            if (dist > 0 && dist <= 6) threat = true;
          }
        }
      }
    });
    return threat;
  }

  // --- UI Interactivity Trigger Helpers ---

  String _getLocalPlayerColor() {
    if (_isLocalMultiplayer) return _activeColor;
    if (_isOffline) return 'Red';
    final user = ref.read(authProvider).user;
    if (user == null) return 'Red';
    Map<String, dynamic>? me;
    for (var p in _players) {
      if (p['userId'] != null && p['userId'].toString() == user.id) {
        me = p as Map<String, dynamic>;
        break;
      }
    }
    return me?['color'] ?? 'Red';
  }

  Map<String, dynamic> _findPlayerByColor(String color) {
    for (var p in _players) {
      if (p is Map && p['color'] == color) {
        return Map<String, dynamic>.from(p);
      }
    }
    return <String, dynamic>{};
  }

  bool _isLocalPlayerTurn() {
    return _activeColor == _getLocalPlayerColor();
  }

  void _onDiceBoxTapped() {
    if (!_isLocalPlayerTurn() || _rollState != 'idle') return;
    
    if (_isOffline) {
      _rollOfflineDice();
    } else {
      ref.read(socketServiceProvider).rollDice(widget.roomCode);
    }
  }

  void _onPawnTapped(int pawnId) {
    if (!_isLocalPlayerTurn() || _rollState != 'rolled') return;
    
    // Check if this pawn is selectable
    final isSelectable = _possibleMoves.any((m) => m['pawnId'] == pawnId);
    if (!isSelectable) return;

    TtsService.instance.speak("Moving pawn ${pawnId + 1}");

    if (_isOffline) {
      _moveOfflinePawn(pawnId);
    } else {
      ref.read(socketServiceProvider).movePawn(widget.roomCode, pawnId);
    }
  }

  // --- Sound Effects Playback Service ---

  void _playSfx(String type) {
    if (!LocalStorage.isSfxEnabled()) return;
    // Call the actual audio service triggers
    if (type == 'roll') {
      if (_diceValue == 6) {
        AudioService.instance.playRollSix();
      } else {
        AudioService.instance.playDiceRoll();
      }
    } else if (type == 'move') {
      AudioService.instance.playPawnMove();
    } else if (type == 'capture') {
      AudioService.instance.playPawnCapture();
    } else if (type == 'goal') {
      AudioService.instance.playGoalReached();
    } else if (type == 'safe') {
      AudioService.instance.playSafeZone();
    }
  }

  void _addHistoryMessage(String text) {
    setState(() {
      _history.add({'text': text, 'timestamp': DateTime.now()});
    });
  }

  // --- Voice & Chat Toggles ---

  void _handleVoiceTokenPayload(Map<String, dynamic> data) {
    final token = data['token'] as String?;
    final url = data['url'] as String?;
    final roomName = data['roomName'] as String?;
    debugPrint(
      '[LiveKit] token received url=$url room=$roomName valid=${VoiceChatService.isValidLiveKitToken(token)}',
    );
    if (!VoiceChatService.isValidLiveKitToken(token) || url == null || url.trim().isEmpty) {
      debugPrint('[LiveKit] Invalid token/url from socket');
      _showVoiceUnavailable('Invalid voice token from server');
      _fetchVoiceTokenViaHttpIfAvailable();
      return;
    }
    ref.read(voiceChatProvider.notifier).connect(
      token: token!,
      url: url,
      roomCode: widget.roomCode.trim().toUpperCase(),
      roomName: roomName,
    );
  }

  Future<void> _requestVoiceToken() async {
    await ref.read(voiceChatProvider.notifier).prepareReconnect();
    TtsService.instance.speak('Connecting voice chat');
    _addHistoryMessage('Requesting secure voice channel token...');
    ref.read(socketServiceProvider).requestVoiceToken(widget.roomCode.trim().toUpperCase());
  }

  void _showVoiceUnavailable(String message) {
    if (!mounted) return;
    ref.read(voiceChatProvider.notifier).prepareReconnect();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Voice chat unavailable: $message'),
        backgroundColor: AppColors.ludoRed,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Only calls REST API when deployed backend exposes /api/voice/health.
  Future<void> _fetchVoiceTokenViaHttpIfAvailable() async {
    try {
      final healthRes = await ApiClient.get('/voice/health');
      if (healthRes.statusCode == 404) {
        debugPrint('[LiveKit] /api/voice not on server — deploy latest backend to Render');
        if (mounted) {
          _showVoiceUnavailable(
            'Server needs update. Deploy latest backend on Render, then try again.',
          );
        }
        return;
      }

      final roomCode = widget.roomCode.trim().toUpperCase();
      debugPrint('[LiveKit] HTTP POST /voice/token room=$roomCode');
      final response = await ApiClient.post('/voice/token', {'roomCode': roomCode});
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['success'] == true) {
        if (mounted) _handleVoiceTokenPayload(body);
        return;
      }
      final msg = body['message']?.toString() ?? 'Voice token request failed';
      debugPrint('[LiveKit] HTTP token failed: $msg');
      if (mounted) _showVoiceUnavailable(msg);
    } catch (e) {
      debugPrint('[LiveKit] HTTP fallback error: $e');
      if (mounted) _showVoiceUnavailable('Network error requesting voice token');
    }
  }

  void _toggleVoiceChat() {
    AudioService.instance.playButtonClick();
    final voiceState = ref.read(voiceChatProvider);
    if (voiceState.status == VoiceChatStatus.connected ||
        voiceState.status == VoiceChatStatus.connecting) {
      TtsService.instance.speak('Disable voice chat');
      _addHistoryMessage('Disabling voice chat globally...');
      ref.read(voiceChatProvider.notifier).disconnect();
    } else {
      _requestVoiceToken();
    }
  }

  void _sendChatMessage() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    AudioService.instance.playButtonClick();
    TtsService.instance.speak("Send message");

    if (_isOffline) {
      setState(() {
        _chatMessages.add({
          'senderName': 'You',
          'text': text,
          'isSelf': true,
        });
      });
      _chatController.clear();
      // Simulate quick chatbot replies for offline practice fun!
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _chatMessages.add({
              'senderName': 'Bot Green',
              'text': _random.nextBool() ? 'Good move!' : 'Let\'s roll!',
              'isSelf': false,
            });
          });
        }
      });
    } else {
      ref.read(socketServiceProvider).sendMessage(widget.roomCode, text);
      _chatController.clear();
    }
  }

  void _triggerLocalEmojiReaction(String emojiId) {
    AudioService.instance.playButtonClick();
    TtsService.instance.speak("$emojiId reaction");
    final myColor = _getLocalPlayerColor();
    if (_isOffline) {
      _triggerEmojiReaction(myColor, emojiId);
      // Bot triggers reaction too
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          final botReaction = ['thumbs_up', 'laugh', 'fire'][_random.nextInt(3)];
          _triggerEmojiReaction('Green', botReaction);
        }
      });
    } else {
      ref.read(socketServiceProvider).sendReaction(widget.roomCode, emojiId);
    }
  }

  void _triggerEmojiReaction(String senderColor, String emojiId) {
    final String emojiChar = _resolveEmojiCharacter(emojiId);
    setState(() {
      _floatingEmojis[senderColor]?.add(emojiChar);
    });
    // Remove after animation finishes
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) {
        setState(() {
          if (_floatingEmojis[senderColor]!.isNotEmpty) {
            _floatingEmojis[senderColor]?.removeAt(0);
          }
        });
      }
    });
  }

  String _resolveEmojiCharacter(String id) {
    switch (id) {
      case 'laugh': return '😂';
      case 'thumbs_up': return '👍';
      case 'wow': return '😮';
      case 'sad': return '😢';
      case 'fire': return '🔥';
      default: return '🎉';
    }
  }

  // --- Modals ---

  void _showWinnerDialog(String winnerName, String winnerColor) {
    // Play win or lose sound based on outcome
    final myColor = _getLocalPlayerColor();
    if (winnerColor == myColor) {
      AudioService.instance.playWin();
    } else {
      AudioService.instance.playLose();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 30),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.accentNeon.withOpacity(0.5), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentNeon.withOpacity(0.15),
                    blurRadius: 25,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 36),
                  const Text(
                    'MATCH COMPLETED',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isLocalMultiplayer 
                        ? 'GAME OVER'
                        : (winnerColor == myColor ? 'VICTORY!' : 'DEFEAT!'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                      color: (_isLocalMultiplayer || winnerColor == myColor) ? AppColors.ludoGreen : AppColors.ludoRed,
                      letterSpacing: 2,
                      shadows: [
                        Shadow(
                          color: ((_isLocalMultiplayer || winnerColor == myColor) ? AppColors.ludoGreen : AppColors.ludoRed).withOpacity(0.5),
                          blurRadius: 10,
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$winnerName is the Champion',
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _isLocalMultiplayer
                          ? 'Match completed locally! Congratulations to the winner!'
                          : (winnerColor == myColor
                              ? 'Winnings (+300 XP, Gold Prize Pool) credited to user wallet.'
                              : 'Rank Rating Adjusted. Better luck next time!'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      AudioService.instance.playButtonClick();
                      TtsService.instance.speak("Back to lobby");
                      Navigator.pop(context); // Close dialog
                      context.go('/home');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: winnerColor == myColor ? AppColors.ludoGreen : AppColors.primary,
                      shadowColor: (winnerColor == myColor ? AppColors.ludoGreen : AppColors.primary).withOpacity(0.4),
                    ),
                    child: const Text('BACK TO LOBBY'),
                  ),
                ],
              ),
            ),
            
            // Lottie Confetti Burst Animation positioned to rain over the dialog
            Positioned(
              top: 0,
              child: SizedBox(
                width: 320,
                height: 300,
                child: Lottie.asset(
                  'assets/animations/confetti.json',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback animated icon if network is offline
                    return const Icon(
                      Icons.emoji_events_rounded,
                      size: 76,
                      color: AppColors.gold,
                    ).animate(onPlay: (c) => c.repeat(reverse: true))
                     .scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15), duration: 1.seconds);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAbandonMatchDialog() {
    AudioService.instance.playButtonClick();
    TtsService.instance.speak("Abandon match dialog");
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Abandon Match?'),
        content: const Text('Quitting this match counts as a forfeit. Entry fee coins will not be returned.'),
        actions: [
          TextButton(
            onPressed: () {
              AudioService.instance.playButtonClick();
              TtsService.instance.speak("Resume");
              Navigator.pop(ctx);
            },
            child: const Text('Resume Game'),
          ),
          ElevatedButton(
            onPressed: () {
              AudioService.instance.playButtonClick();
              TtsService.instance.speak("Forfeit and leave");
              Navigator.pop(ctx);
              context.go('/home');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.ludoRed),
            child: const Text('Exit Match'),
          )
        ],
      ),
    );
  }

  // --- Rendering UI Layout ---

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final voiceState = ref.watch(voiceChatProvider);
    final isVoiceConnected = voiceState.status == VoiceChatStatus.connected;
    final isVoiceMuted = voiceState.isMuted;
    final activeSpeaker = voiceState.activeSpeaker;
    // Calculate max available height for the board based on screen height
    // Listen to voice state failures to alert the user with a standard SnackBar
    ref.listen<VoiceChatState>(voiceChatProvider, (previous, next) {
      if (next.status == VoiceChatStatus.permissionDenied && previous?.status != VoiceChatStatus.permissionDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission required for voice chat'),
            backgroundColor: AppColors.ludoRed,
            duration: Duration(seconds: 3),
          ),
        );
      } else if (next.status == VoiceChatStatus.failed && previous?.status != VoiceChatStatus.failed) {
        final errorMsg = next.lastError ??
            (next.logs.isNotEmpty
                ? (next.logs.last.contains(']')
                    ? next.logs.last.split(']').last.trim()
                    : next.logs.last)
                : 'Unknown audio error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Voice chat connection failed: $errorMsg'),
            backgroundColor: AppColors.ludoRed,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });

    // Recalculate reserved height dynamically to scale board down slightly on smaller screens and prevent any 0.818 pixels overflow
    final double reservedHeight = !_isOffline ? (isVoiceConnected ? 440.0 : 400.0) : 320.0;
    final double maxBoardHeight = size.height - reservedHeight;
    final boardSize = min(min(size.width - 32, 450.0), max(200.0, maxBoardHeight));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showAbandonMatchDialog();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            _isLocalMultiplayer
                ? 'LOCAL MULTIPLAYER'
                : (_isOffline ? 'OFFLINE PRACTICE VS AI' : 'MULTIPLAYER ROOM: ${widget.roomCode}'),
            style: const TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.exit_to_app_rounded),
            onPressed: _showAbandonMatchDialog,
          ),
        actions: [
          // Developer secret trigger: Long-press chat or double-tap to toggle voice logs overlay panel
          if (!_isOffline)
            GestureDetector(
              onLongPress: () {
                setState(() {
                  _showVoiceDebugPanel = !_showVoiceDebugPanel;
                });
              },
              child: IconButton(
                icon: voiceState.status == VoiceChatStatus.connecting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(
                        isVoiceConnected
                            ? (isVoiceMuted ? Icons.mic_off : Icons.mic)
                            : Icons.mic,
                        color: isVoiceConnected
                            ? (isVoiceMuted ? AppColors.ludoRed : AppColors.ludoGreen)
                            : AppColors.textSecondary,
                      ),
                onPressed: _toggleVoiceChat,
                tooltip: 'Toggle Voice Chat',
              ),
            ),
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              onPressed: () {
                AudioService.instance.playButtonClick();
                Scaffold.of(ctx).openEndDrawer();
              },
            ),
          )
        ],
      ),
      endDrawer: _buildChatDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            // Voice status indicator row
            if (!_isOffline && voiceState.status != VoiceChatStatus.disconnected)
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      voiceState.status == VoiceChatStatus.connecting
                          ? Icons.sync
                          : (isVoiceConnected
                              ? (isVoiceMuted ? Icons.mic_off : Icons.mic)
                              : Icons.mic_off_outlined),
                      color: voiceState.status == VoiceChatStatus.connecting
                          ? AppColors.gold
                          : (isVoiceConnected
                              ? (isVoiceMuted ? AppColors.ludoRed : AppColors.ludoGreen)
                              : AppColors.textSecondary),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _voiceStatusLabel(voiceState, activeSpeaker),
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),

            // Top Status Bar: Avatars & Active Turn Glow
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildPlayerBadge('Red', _activeColor == 'Red'),
                  _buildPlayerBadge('Green', _activeColor == 'Green'),
                  if (_colors.contains('Yellow')) _buildPlayerBadge('Yellow', _activeColor == 'Yellow'),
                  if (_colors.contains('Blue')) _buildPlayerBadge('Blue', _activeColor == 'Blue'),
                ],
              ),
            ),

            const Spacer(),

            // Interactive Ludo Board
            Center(
              child: Container(
                width: boardSize,
                height: boardSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 15, spreadRadius: 2),
                  ],
                ),
                child: Stack(
                  children: [
                    LudoBoardLayout(size: boardSize),
                    _buildPawnOverlayLayer(boardSize),
                    _buildFloatingEmojiLayer(boardSize),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Emoji quick reactions bar
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: ['laugh', 'thumbs_up', 'wow', 'sad', 'fire'].map((eId) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: InkWell(
                      onTap: () => _triggerLocalEmojiReaction(eId),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surface,
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Text(_resolveEmojiCharacter(eId), style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            if (!_isOffline) ...[
              const SizedBox(height: 8),
              // Persistent Push-To-Talk (Hold-to-Talk) Button
              _buildHoldToTalkButton(voiceState),
              const SizedBox(height: 12),
            ],

            // Bottom Dice roller deck
            _buildDiceConsoleDeck(),
            
            const SizedBox(height: 16),
            
            // Temporary Developer Logs Debug overlay (safely layered without affecting core gameplay)
            if (_showVoiceDebugPanel)
              Container(
                height: 220,
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.6), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '🎙️ HARDWARE AUDIO PIPELINE AUDIT PANEL',
                          style: TextStyle(fontFamily: 'Courier', fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.bold),
                        ),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _showVoiceDebugPanel = false;
                            });
                          },
                          child: const Icon(Icons.close, size: 16, color: Colors.white),
                        )
                      ],
                    ),
                    const Divider(color: Colors.white24, height: 8),
                    
                    // Hardware pipeline values grid
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Table(
                        columnWidths: const {
                          0: FlexColumnWidth(1.2),
                          1: FlexColumnWidth(1.0),
                          2: FlexColumnWidth(1.2),
                          3: FlexColumnWidth(1.0),
                        },
                        children: [
                          TableRow(
                            children: [
                              const Text('Voice Connect:', style: TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'Courier')),
                              Text(voiceState.status == VoiceChatStatus.connected ? 'YES' : 'NO', style: TextStyle(color: voiceState.status == VoiceChatStatus.connected ? Colors.green : Colors.red, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Courier')),
                              const Text('Room Name:', style: TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'Courier')),
                              Text(ref.read(voiceChatProvider.notifier).currentRoomName, style: const TextStyle(color: Colors.cyan, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Courier')),
                            ],
                          ),
                          TableRow(
                            children: [
                              const Text('Mic Capturing:', style: TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'Courier')),
                              Text(ref.read(voiceChatProvider.notifier).hasLocalAudioTrack ? 'YES' : 'NO', style: TextStyle(color: ref.read(voiceChatProvider.notifier).hasLocalAudioTrack ? Colors.green : Colors.red, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Courier')),
                              const Text('Audio Pubbed:', style: TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'Courier')),
                              Text(ref.read(voiceChatProvider.notifier).isLocalAudioTrackPublished ? 'YES' : 'NO', style: TextStyle(color: ref.read(voiceChatProvider.notifier).isLocalAudioTrackPublished ? Colors.green : Colors.red, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Courier')),
                            ],
                          ),
                          TableRow(
                            children: [
                              const Text('Remote Subs:', style: TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'Courier')),
                              Text(ref.read(voiceChatProvider.notifier).hasRemoteAudioSubscribed ? 'YES' : 'NO', style: TextStyle(color: ref.read(voiceChatProvider.notifier).hasRemoteAudioSubscribed ? Colors.green : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Courier')),
                              const Text('Peer Count:', style: TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'Courier')),
                              Text('${ref.read(voiceChatProvider.notifier).participantCount}', style: const TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Courier')),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text('LOG STREAM:', style: TextStyle(color: Colors.grey, fontSize: 9, fontFamily: 'Courier', fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: ListView.builder(
                          itemCount: voiceState.logs.length,
                          reverse: true,
                          itemBuilder: (context, idx) {
                            final reversedList = voiceState.logs.reversed.toList();
                            return Text(
                              reversedList[idx],
                              style: const TextStyle(fontFamily: 'Courier', fontSize: 9, color: Colors.lightGreen),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildPlayerBadge(String color, bool isTurn) {
    // Locate player details matching color
    Map<String, dynamic>? pInfo;
    for (var p in _players) {
      if (p['color'] == color) {
        pInfo = p as Map<String, dynamic>;
        break;
      }
    }

    final String name = pInfo?['name'] ?? (color == 'Red' ? 'Player 1' : 'Bot');
    final String avatar = pInfo?['avatar'] ?? 'https://api.dicebear.com/7.x/pixel-art/png?seed=$color';

    final Color colorVal = color == 'Red'
        ? AppColors.tokenRed
        : color == 'Green'
            ? AppColors.tokenGreen
            : color == 'Yellow'
                ? AppColors.tokenYellow
                : AppColors.tokenBlue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isTurn ? colorVal.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTurn ? colorVal.withOpacity(0.3) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              if (isTurn)
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colorVal, width: 2.5),
                    boxShadow: [
                      BoxShadow(color: colorVal.withOpacity(0.4), blurRadius: 10, spreadRadius: 2),
                    ],
                  ),
                ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.12, 1.12), duration: 600.ms),
              
              // Frame around avatar
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.cardBg,
                  border: Border.all(color: isTurn ? Colors.white : colorVal.withOpacity(0.5), width: 1.5),
                ),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.surface,
                  backgroundImage: NetworkImage(avatar),
                ),
              ),
              
              // Real-Time Microphone state status indicator for teammate sync
              Consumer(
                builder: (context, ref, _) {
                  final voiceState = ref.watch(voiceChatProvider);
                  // Resolve identity/name to show correct icon state
                  final bool isLocal = name == 'You' || (ref.read(authProvider).user?.name == name);
                  ParticipantVoiceState? pState;
                  
                  if (isLocal) {
                    pState = voiceState.participants.values.firstWhere(
                      (p) => p.name == 'You',
                      orElse: () => ParticipantVoiceState(identity: '', name: 'You', isMuted: voiceState.isMuted),
                    );
                  } else {
                    pState = voiceState.participants.values.firstWhere(
                      (p) => p.name.trim().toLowerCase() == name.trim().toLowerCase() || p.identity == name,
                      orElse: () => voiceState.participants.values.firstWhere(
                        (p) => p.name != 'You',
                        orElse: () => ParticipantVoiceState(identity: '', name: name, isMuted: true),
                      ),
                    );
                  }
                  
                  final isMuted = pState.isMuted;
                  final isSpeaking = pState.isSpeaking && voiceState.status == VoiceChatStatus.connected;
                  
                  if (voiceState.status != VoiceChatStatus.connected) return const SizedBox.shrink();

                  return Positioned(
                    top: -2,
                    left: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: isMuted ? AppColors.ludoRed : AppColors.ludoGreen,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                        boxShadow: [
                          if (isSpeaking)
                            BoxShadow(
                              color: AppColors.ludoGreen.withOpacity(0.6),
                              blurRadius: 6,
                              spreadRadius: 2,
                            ),
                        ],
                      ),
                      child: Icon(
                        isMuted ? Icons.mic_off : Icons.mic,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
              
              // Level Star overlay
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: colorVal,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    size: 10,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            name, 
            style: GoogleFonts.outfit(
              fontSize: 12, 
              fontWeight: isTurn ? FontWeight.bold : FontWeight.w500,
              color: isTurn ? Colors.white : AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPawnOverlayLayer(double boardPixelSize) {
    final double cellPixelSize = boardPixelSize / 15;
    final List<Widget> pawnWidgets = [];

    // Accumulate all pawns currently on board by cell coordinates
    // key is "x,y", value is List of pawns coordinates details
    final Map<String, List<Map<String, dynamic>>> pawnsByCoords = {};

    _pawns.forEach((color, steps) {
      for (int i = 0; i < 4; i++) {
        final step = steps[i];
        
        BoardCell cell;
        if (step == 0) {
          // Yard position
          cell = LudoCoordinates.yardCoordinates[color]![i];
        } else {
          // Track position
          final path = LudoCoordinates.getPathForColor(color);
          cell = path[step];
        }

        final coordKey = '${cell.x},${cell.y}';
        if (!pawnsByCoords.containsKey(coordKey)) {
          pawnsByCoords[coordKey] = [];
        }
        pawnsByCoords[coordKey]!.add({
          'color': color,
          'pawnId': i,
          'step': step,
        });
      }
    });

    // Render pawns and offset overlaying items
    pawnsByCoords.forEach((coordKey, pawnList) {
      final parts = coordKey.split(',');
      final int cx = int.parse(parts[0]);
      final int cy = int.parse(parts[1]);
      
      final int numPawns = pawnList.length;

      for (int idx = 0; idx < numPawns; idx++) {
        final item = pawnList[idx];
        final String pColor = item['color'];
        final int pId = item['pawnId'];
        
        // Calculate coordinate offsets for overlaps
        double dx = 0.0;
        double dy = 0.0;

        if (numPawns > 1) {
          // Arrange overlay pawns in grid offset offsets within one cell box
          final double offsetVal = cellPixelSize / 5;
          if (numPawns == 2) {
            dx = (idx == 0) ? -offsetVal : offsetVal;
          } else if (numPawns == 3) {
            if (idx == 0) dy = -offsetVal;
            if (idx == 1) dx = -offsetVal; dy = offsetVal;
            if (idx == 2) dx = offsetVal; dy = offsetVal;
          } else {
            // 4+ pawns
            dx = (idx % 2 == 0) ? -offsetVal : offsetVal;
            dy = (idx < 2) ? -offsetVal : offsetVal;
          }
        }

        final double posX = (cx * cellPixelSize) + (cellPixelSize / 2) + dx - 12; // 12 is half token size (radius=12, width=24)
        final double posY = (cy * cellPixelSize) + (cellPixelSize / 2) + dy - 12;

        final Color colorVal = pColor == 'Red'
            ? AppColors.ludoRed
            : pColor == 'Green'
                ? AppColors.ludoGreen
                : pColor == 'Yellow'
                    ? AppColors.ludoYellow
                    : AppColors.ludoBlue;

        final isTurn = _activeColor == pColor;
        final isSelectable = isTurn && _possibleMoves.any((m) => m['pawnId'] == pId);

        final tokenWidget = Semantics(
          label: '$pColor Pawn ${pId + 1}',
          value: item['step'] == 0 ? 'Home Yard' : (item['step'] == 57 ? 'Reached Goal' : 'Step ${item['step']}'),
          hint: isSelectable ? 'Double tap to move this pawn by $_diceValue steps' : 'Pawn not selectable',
          button: isSelectable,
          child: GestureDetector(
            onTap: isSelectable ? () => _onPawnTapped(pId) : null,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isSelectable)
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.3),
                      boxShadow: [
                        BoxShadow(color: colorVal, blurRadius: 8, spreadRadius: 3),
                      ],
                    ),
                  ).animate(onPlay: (c) => c.repeat()).scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: 500.ms),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Colors.white, colorVal],
                      stops: const [0.1, 1.0],
                    ),
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(1, 2)),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '${pId + 1}',
                      style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        pawnWidgets.add(
          Positioned(
            left: posX,
            top: posY,
            child: tokenWidget,
          ),
        );
      }
    });

    return Stack(children: pawnWidgets);
  }

  Widget _buildFloatingEmojiLayer(double boardPixelSize) {
    final double cellSize = boardPixelSize / 15;
    final List<Widget> items = [];

    // Red Yard center coordinates: (2.5, 2.5) -> (cx * cellSize, cy * cellSize)
    final centers = {
      'Red': const Offset(2.5, 2.5),
      'Green': const Offset(11.5, 2.5),
      'Yellow': const Offset(11.5, 11.5),
      'Blue': const Offset(2.5, 11.5),
    };

    _floatingEmojis.forEach((color, list) {
      if (list.isNotEmpty) {
        final center = centers[color]!;
        final posX = (center.dx * cellSize) - 15;
        final posY = (center.dy * cellSize) - 15;
        
        final latestEmoji = list.last;

        items.add(
          Positioned(
            left: posX,
            top: posY,
            child: Text(latestEmoji, style: const TextStyle(fontSize: 36))
                .animate()
                .slideY(begin: 0, end: -2, duration: 1200.ms, curve: Curves.easeOut)
                .fadeOut(duration: 1200.ms),
          ),
        );
      }
    });

    return Stack(children: items);
  }

  String _voiceStatusLabel(VoiceChatState voiceState, String? activeSpeaker) {
    switch (voiceState.status) {
      case VoiceChatStatus.connecting:
        return 'Connecting to voice chat...';
      case VoiceChatStatus.connected:
        if (activeSpeaker != null) return '$activeSpeaker is speaking...';
        return voiceState.isMuted ? 'Voice connected — muted' : 'Voice connected — mic on';
      case VoiceChatStatus.failed:
        return 'Voice offline';
      case VoiceChatStatus.permissionDenied:
        return 'Microphone permission required';
      case VoiceChatStatus.disconnected:
        return 'Voice offline';
    }
  }

  Widget _buildHoldToTalkButton(VoiceChatState voiceState) {
    final isVoiceConnected = voiceState.status == VoiceChatStatus.connected;
    final isConnecting = voiceState.status == VoiceChatStatus.connecting;

    if (isConnecting) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: const Color(0xFF1E293B).withOpacity(0.8),
          border: Border.all(color: AppColors.gold.withOpacity(0.5), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
            ),
            const SizedBox(width: 12),
            Text(
              'CONNECTING...',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      );
    }

    if (!isVoiceConnected) {
      return GestureDetector(
        onTap: _toggleVoiceChat,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: const Color(0xFF1E293B).withOpacity(0.8),
            border: Border.all(
              color: const Color(0xFFEF4444).withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mic_off_outlined, color: Color(0xFFEF4444), size: 24),
              const SizedBox(width: 12),
              Text(
                'VOICE OFFLINE (TAP TO ENABLE)',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () async {
        AudioService.instance.playButtonClick();
        await ref.read(voiceChatProvider.notifier).toggleMute();
        if (mounted) {
          setState(() {
            _isHoldingMic = !ref.read(voiceChatProvider).isMuted;
          });
        }
      },
      onTapDown: (_) async {
        AudioService.instance.playButtonClick();
        setState(() {
          _isHoldingMic = true;
        });
        TtsService.instance.speak("Speaking live");
        _addHistoryMessage('Unmuted! Speaking live...');
        await ref.read(voiceChatProvider.notifier).setMuted(false);
      },
      onTapUp: (_) async {
        setState(() {
          _isHoldingMic = false;
        });
        _addHistoryMessage('Muted! Stopped talking.');
        await ref.read(voiceChatProvider.notifier).setMuted(true);
      },
      onTapCancel: () async {
        setState(() {
          _isHoldingMic = false;
        });
        await ref.read(voiceChatProvider.notifier).setMuted(true);
      },
      onLongPressStart: (_) async {
        if (!_isHoldingMic) {
          AudioService.instance.playButtonClick();
          setState(() {
            _isHoldingMic = true;
          });
          TtsService.instance.speak("Speaking live");
          _addHistoryMessage('Unmuted! Speaking live...');
          await ref.read(voiceChatProvider.notifier).setMuted(false);
        }
      },
      onLongPressEnd: (_) async {
        setState(() {
          _isHoldingMic = false;
        });
        _addHistoryMessage('Muted! Stopped talking.');
        await ref.read(voiceChatProvider.notifier).setMuted(true);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: _isHoldingMic
              ? const LinearGradient(
                  colors: [Color(0xFFEF4444), Color(0xFFF97316)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          border: Border.all(
            color: _isHoldingMic ? Colors.white : const Color(0xFFEF4444).withOpacity(0.4),
            width: 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHoldingMic
                  ? const Color(0xFFEF4444).withOpacity(0.6)
                  : Colors.black38,
              blurRadius: _isHoldingMic ? 16 : 6,
              spreadRadius: _isHoldingMic ? 3 : 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isHoldingMic ? Icons.mic : Icons.mic_none_outlined,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              _isHoldingMic || !voiceState.isMuted
                  ? '🎤 MIC ON (TAP OR RELEASE TO MUTE)'
                  : 'MUTED — HOLD TO TALK OR TAP TO UNMUTE',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiceConsoleDeck() {
    final isMyTurn = _isLocalPlayerTurn();

    final Color activeColorVal = _activeColor == 'Red'
        ? AppColors.tokenRed
        : _activeColor == 'Green'
            ? AppColors.tokenGreen
            : _activeColor == 'Yellow'
                ? AppColors.tokenYellow
                : AppColors.tokenBlue;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isMyTurn ? activeColorVal.withOpacity(0.6) : const Color(0xFF26324A),
          width: 1.5,
        ),
        boxShadow: [
          if (isMyTurn)
            BoxShadow(
              color: activeColorVal.withOpacity(0.12),
              blurRadius: 12,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Info textual column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMyTurn 
                      ? (_isLocalMultiplayer 
                          ? '${(_findPlayerByColor(_activeColor)['name'] ?? _activeColor).toUpperCase()}\'S TURN'
                          : 'YOUR TURN')
                      : '${_activeColor.toUpperCase()}\'S TURN',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold, 
                    fontSize: 16, 
                    color: activeColorVal,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _rollState == 'idle' 
                      ? 'Tap the dice to roll and advance' 
                      : 'Select a highlighted pawn on the board',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),

          // Right: styled dice box
          Semantics(
            label: 'Roll Dice Button',
            hint: isMyTurn 
                ? (_rollState == 'idle' ? 'Double tap to roll the dice' : 'Dice rolled: $_diceValue. Move your pawn.')
                : 'Waiting for ${_activeColor.toUpperCase()} to play',
            value: _diceValue != null ? 'Last rolled value: $_diceValue' : 'Not rolled yet',
            button: isMyTurn && _rollState == 'idle',
            child: GestureDetector(
              onTap: _onDiceBoxTapped,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Highlight ring
                  if (isMyTurn && _rollState == 'idle')
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: activeColorVal.withOpacity(0.35), blurRadius: 16, spreadRadius: 3),
                        ],
                      ),
                    ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.18, 1.18), duration: 500.ms),
                  
                  // Dice body (Metallic 3D look with bevel)
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: activeColorVal,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        const BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(2, 4)),
                        BoxShadow(color: activeColorVal.withOpacity(0.5), blurRadius: 8, offset: const Offset(-1, -1)),
                      ],
                      gradient: LinearGradient(
                        colors: [
                          activeColorVal.withOpacity(0.9),
                          activeColorVal,
                          activeColorVal.withOpacity(0.7)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(color: Colors.white.withOpacity(0.4), width: 2.2),
                    ),
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _diceController,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _diceController.value * pi * 4,
                            child: child,
                          );
                        },
                        child: _buildDiceFaceContent(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiceFaceContent() {
    if (_diceValue == null) {
      return const Icon(Icons.casino_rounded, size: 30, color: Colors.white);
    }
    
    // Dot matrices representing Ludo dice faces
    switch (_diceValue) {
      case 1:
        return _buildDiceDots([const Alignment(0, 0)]);
      case 2:
        return _buildDiceDots([const Alignment(-0.55, -0.55), const Alignment(0.55, 0.55)]);
      case 3:
        return _buildDiceDots([const Alignment(-0.55, -0.55), const Alignment(0, 0), const Alignment(0.55, 0.55)]);
      case 4:
        return _buildDiceDots([
          const Alignment(-0.55, -0.55), const Alignment(0.55, -0.55),
          const Alignment(-0.55, 0.55), const Alignment(0.55, 0.55)
        ]);
      case 5:
        return _buildDiceDots([
          const Alignment(-0.55, -0.55), const Alignment(0.55, -0.55),
          const Alignment(0, 0),
          const Alignment(-0.55, 0.55), const Alignment(0.55, 0.55)
        ]);
      case 6:
        return _buildDiceDots([
          const Alignment(-0.55, -0.55), const Alignment(0.55, -0.55),
          const Alignment(-0.55, 0), const Alignment(0.55, 0),
          const Alignment(-0.55, 0.55), const Alignment(0.55, 0.55)
        ]);
      default:
        return const Icon(Icons.casino, size: 30, color: Colors.white);
    }
  }

  Widget _buildDiceDots(List<Alignment> alignments) {
    return Stack(
      children: alignments.map((align) {
        return Align(
          alignment: align,
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 1.5,
                  offset: Offset(1, 1),
                ),
              ],
              gradient: RadialGradient(
                colors: [Colors.white, Colors.grey.shade300],
                stops: const [0.3, 1.0],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildChatDrawer() {
    return Drawer(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'CHAT LOBBY',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Outfit', letterSpacing: 1.5),
              ),
            ),
            const Divider(height: 1, color: Color(0xFF334155)),
            
            // Messages area
            Expanded(
              child: _chatMessages.isEmpty
                  ? const Center(child: Text('No messages yet. Say hello!', style: TextStyle(color: AppColors.textMuted)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _chatMessages.length,
                      itemBuilder: (context, idx) {
                        final msg = _chatMessages[idx];
                        final isSelf = msg['isSelf'] == true;
                        return Align(
                          alignment: isSelf ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelf ? AppColors.primary : AppColors.surface,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(12),
                                topRight: const Radius.circular(12),
                                bottomLeft: isSelf ? const Radius.circular(12) : Radius.zero,
                                bottomRight: isSelf ? Radius.zero : const Radius.circular(12),
                              ),
                              border: isSelf ? null : Border.all(color: const Color(0xFF334155)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isSelf)
                                  Text(
                                    msg['senderName'], 
                                    style: const TextStyle(fontSize: 10, color: AppColors.secondary, fontWeight: FontWeight.bold),
                                  ),
                                const SizedBox(height: 2),
                                Text(msg['text'], style: const TextStyle(fontSize: 13, color: Colors.white)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            
            const Divider(height: 1, color: Color(0xFF334155)),

            // Send panel
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatController,
                      style: const TextStyle(fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Enter text message...',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _sendChatMessage(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: AppColors.primary),
                    onPressed: _sendChatMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- High Fidelity Ludo Board Renderers ---

class LudoBoardLayout extends StatelessWidget {
  final double size;

  const LudoBoardLayout({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: const Color(0xFFE2E8F0),
      child: CustomPaint(
        size: Size(size, size),
        painter: LudoBoardPainter(),
      ),
    );
  }
}

class LudoBoardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double stepSize = size.width / 15;

    // Define colors & gradients
    final Color colorRed = AppColors.tokenRed;
    final Color colorGreen = AppColors.tokenGreen;
    final Color colorYellow = AppColors.tokenYellow;
    final Color colorBlue = AppColors.tokenBlue;

    final Paint borderPaint = Paint()
      ..color = const Color(0xFF2E3B5E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final Paint cellBackPaint = Paint()..color = const Color(0xFF131929);

    // 1. Draw basic board background grid
    for (int col = 0; col < 15; col++) {
      for (int row = 0; row < 15; row++) {
        canvas.drawRect(Rect.fromLTWH(col * stepSize, row * stepSize, stepSize, stepSize), cellBackPaint);
        canvas.drawRect(Rect.fromLTWH(col * stepSize, row * stepSize, stepSize, stepSize), borderPaint);
      }
    }

    // Function to draw gradients
    void drawGradientRect(Rect rect, Color baseColor) {
      final Paint paint = Paint()
        ..shader = LinearGradient(
          colors: [baseColor, baseColor.withOpacity(0.65)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), paint);
    }

    // 2. Draw 4 primary quadrant bases (Yards) with gradients & round corners
    drawGradientRect(Rect.fromLTWH(0, 0, stepSize * 6, stepSize * 6), colorRed);
    drawGradientRect(Rect.fromLTWH(stepSize * 9, 0, stepSize * 6, stepSize * 6), colorGreen);
    drawGradientRect(Rect.fromLTWH(stepSize * 9, stepSize * 9, stepSize * 6, stepSize * 6), colorYellow);
    drawGradientRect(Rect.fromLTWH(0, stepSize * 9, stepSize * 6, stepSize * 6), colorBlue);

    // 3. Draw yard inner white panels with subtle neon trim
    _drawInnerYardPanel(canvas, 1 * stepSize, 1 * stepSize, stepSize * 4, colorRed);
    _drawInnerYardPanel(canvas, 10 * stepSize, 1 * stepSize, stepSize * 4, colorGreen);
    _drawInnerYardPanel(canvas, 10 * stepSize, 10 * stepSize, stepSize * 4, colorYellow);
    _drawInnerYardPanel(canvas, 1 * stepSize, 10 * stepSize, stepSize * 4, colorBlue);

    // 4. Highlight path start / home stretch tracks
    // Red home stretch & starting cell
    for (int i = 1; i <= 5; i++) {
      drawGradientRect(Rect.fromLTWH(i * stepSize, 7 * stepSize, stepSize, stepSize), colorRed);
    }
    drawGradientRect(Rect.fromLTWH(1 * stepSize, 6 * stepSize, stepSize, stepSize), colorRed);

    // Green home stretch & starting cell
    for (int i = 1; i <= 5; i++) {
      drawGradientRect(Rect.fromLTWH(7 * stepSize, i * stepSize, stepSize, stepSize), colorGreen);
    }
    drawGradientRect(Rect.fromLTWH(8 * stepSize, 1 * stepSize, stepSize, stepSize), colorGreen);

    // Yellow home stretch & starting cell
    for (int i = 9; i <= 13; i++) {
      drawGradientRect(Rect.fromLTWH(i * stepSize, 7 * stepSize, stepSize, stepSize), colorYellow);
    }
    drawGradientRect(Rect.fromLTWH(13 * stepSize, 8 * stepSize, stepSize, stepSize), colorYellow);

    // Blue home stretch & starting cell
    for (int i = 9; i <= 13; i++) {
      drawGradientRect(Rect.fromLTWH(7 * stepSize, i * stepSize, stepSize, stepSize), colorBlue);
    }
    drawGradientRect(Rect.fromLTWH(6 * stepSize, 13 * stepSize, stepSize, stepSize), colorBlue);

    // 5. Draw safety Star stars (glowing gold)
    _drawStar(canvas, 2 * stepSize, 6 * stepSize, stepSize);
    _drawStar(canvas, 8 * stepSize, 2 * stepSize, stepSize);
    _drawStar(canvas, 12 * stepSize, 8 * stepSize, stepSize);
    _drawStar(canvas, 6 * stepSize, 12 * stepSize, stepSize);
    
    _drawStar(canvas, 6 * stepSize, 8 * stepSize, stepSize);
    _drawStar(canvas, 8 * stepSize, 6 * stepSize, stepSize);
    _drawStar(canvas, 8 * stepSize, 8 * stepSize, stepSize);
    _drawStar(canvas, 6 * stepSize, 6 * stepSize, stepSize);

    // 6. Draw Center Goal triangles
    final centerRect = Rect.fromLTWH(6 * stepSize, 6 * stepSize, stepSize * 3, stepSize * 3);
    
    void drawTriangle(Path path, Color baseColor) {
      final Paint paint = Paint()
        ..shader = RadialGradient(
          colors: [baseColor.withOpacity(0.95), baseColor.withOpacity(0.4)],
        ).createShader(centerRect);
      canvas.drawPath(path, paint);
      canvas.drawPath(path, borderPaint);
    }

    final Path redTriangle = Path()
      ..moveTo(6 * stepSize, 6 * stepSize)
      ..lineTo(7.5 * stepSize, 7.5 * stepSize)
      ..lineTo(6 * stepSize, 9 * stepSize)
      ..close();
    drawTriangle(redTriangle, colorRed);

    final Path greenTriangle = Path()
      ..moveTo(6 * stepSize, 6 * stepSize)
      ..lineTo(7.5 * stepSize, 7.5 * stepSize)
      ..lineTo(9 * stepSize, 6 * stepSize)
      ..close();
    drawTriangle(greenTriangle, colorGreen);

    final Path yellowTriangle = Path()
      ..moveTo(9 * stepSize, 6 * stepSize)
      ..lineTo(7.5 * stepSize, 7.5 * stepSize)
      ..lineTo(9 * stepSize, 9 * stepSize)
      ..close();
    drawTriangle(yellowTriangle, colorYellow);

    final Path blueTriangle = Path()
      ..moveTo(6 * stepSize, 9 * stepSize)
      ..lineTo(7.5 * stepSize, 7.5 * stepSize)
      ..lineTo(9 * stepSize, 9 * stepSize)
      ..close();
    drawTriangle(blueTriangle, colorBlue);
  }

  void _drawInnerYardPanel(Canvas canvas, double x, double y, double sideSize, Color glowColor) {
    final Paint borderPaint = Paint()
      ..color = glowColor.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final Paint fillWhite = Paint()..color = const Color(0xFF131929).withOpacity(0.85);
    
    final rrect = RRect.fromRectAndRadius(Rect.fromLTWH(x, y, sideSize, sideSize), const Radius.circular(16));
    canvas.drawRRect(rrect, fillWhite);
    canvas.drawRRect(rrect, borderPaint);
    
    // Draw 4 token home slots inside the yard
    final double padding = sideSize / 3;
    final Paint slotPaint = Paint()
      ..color = const Color(0xFF1D263B)
      ..style = PaintingStyle.fill;
    
    final Paint slotBorder = Paint()
      ..color = glowColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int col = 0; col < 2; col++) {
      for (int row = 0; row < 2; row++) {
        final double cx = x + padding + (col * padding * 1.1) + 4;
        final double cy = y + padding + (row * padding * 1.1) + 4;
        canvas.drawCircle(Offset(cx, cy), 12, slotPaint);
        canvas.drawCircle(Offset(cx, cy), 12, slotBorder);
      }
    }
  }

  void _drawStar(Canvas canvas, double x, double y, double size) {
    final double cx = x + size / 2;
    final double cy = y + size / 2;
    final double outer = size * 0.4;
    final double inner = size * 0.18;

    final Paint starPaint = Paint()
      ..shader = const RadialGradient(
        colors: [AppColors.gold, Color(0xFFFF8C00)],
      ).createShader(Rect.fromLTWH(x, y, size, size));

    final Paint starBorder = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final Path path = Path();
    for (int i = 0; i < 5; i++) {
      final double angleOuter = (i * 72 - 90) * pi / 180;
      final double angleInner = (i * 72 + 36 - 90) * pi / 180;
      
      final double pxOuter = cx + outer * cos(angleOuter);
      final double pyOuter = cy + outer * sin(angleOuter);
      final double pxInner = cx + inner * cos(angleInner);
      final double pyInner = cy + inner * sin(angleInner);

      if (i == 0) {
        path.moveTo(pxOuter, pyOuter);
      } else {
        path.lineTo(pxOuter, pyOuter);
      }
      path.lineTo(pxInner, pyInner);
    }
    path.close();
    canvas.drawPath(path, starPaint);
    canvas.drawPath(path, starBorder);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
