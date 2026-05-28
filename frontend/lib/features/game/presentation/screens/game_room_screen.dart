import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:livekit_client/livekit_client.dart';
import '../../../../core/network/socket_provider.dart';
import '../../../../core/services/local_storage.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/ludo_coordinates.dart';

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
  bool _isVoiceMuted = true;
  bool _isVoiceConnected = false;
  String? _activeSpeaker;
  Room? _lkRoom;
  
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
    _isOffline = widget.roomCode.startsWith('BOT_');
    
    // Setup dice controller
    _diceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _parseGameState(widget.initialGameState);

    if (_isOffline) {
      _botDifficulty = widget.roomCode.split('_').last.toLowerCase();
      _addHistoryMessage('Local practice game started vs AI ($_botDifficulty)');
    } else {
      _setupSocketListeners();
    }
  }

  @override
  void dispose() {
    _lkRoom?.disconnect();
    _lkRoom?.dispose();
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
      if (_isOffline && _activeColor == 'Red' && _rollState == 'rolled' && _diceValue != null) {
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
        
        if (data['forfeit'] == true) {
          _addHistoryMessage('$_activeColor forfeits turn (consecutive sixes limit)');
        } else if (_possibleMoves.isEmpty && _activeColor == _getLocalPlayerColor()) {
          _addHistoryMessage('You rolled $_diceValue but have no moves');
        }
      }
    };

    socket.onPawnMoved = (data) {
      if (mounted) {
        _playSfx('move');
        if (data['isKill'] == true) _playSfx('capture');
        if (data['isGoal'] == true) _playSfx('goal');
        
        _parseGameState(data['gameState']);
      }
    };

    socket.onTurnChanged = (data) {
      if (mounted) {
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

    socket.onVoiceToken = (data) async {
      final token = data['token'] as String?;
      final url = data['url'] as String?;
      if (token == null || url == null) {
        print('LiveKit token or url missing in socket event response');
        return;
      }
      
      try {
        if (_lkRoom != null) {
          await _lkRoom!.disconnect();
          await _lkRoom!.dispose();
        }

        final room = Room();
        _lkRoom = room;

        room.addListener(() {
          if (!mounted) return;
          String? speaker;
          for (var p in room.remoteParticipants.values) {
            if (p.isSpeaking) {
              speaker = p.name.isNotEmpty ? p.name : p.identity;
              break;
            }
          }
          if (room.localParticipant?.isSpeaking ?? false) {
            speaker = 'You';
          }
          setState(() {
            _activeSpeaker = speaker;
          });
        });

        await room.connect(url, token);
        await room.localParticipant?.setMicrophoneEnabled(!_isVoiceMuted);

        if (mounted) {
          setState(() {
            _isVoiceConnected = true;
          });
          _addHistoryMessage('Connected to secure audio channel');
        }
      } catch (e) {
        print('Failed to connect to LiveKit: $e');
        if (mounted) {
          _addHistoryMessage('Failed to connect to audio channel');
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
      _addHistoryMessage('$_activeColor has no moves. Passing turn...');
      Future.delayed(const Duration(milliseconds: 1500), _passOfflineTurn);
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

    _addHistoryMessage('$_activeColor rolled a $_diceValue');

    if (_diceValue == 6) {
      // Local consecutive check is omitted for simplicity in practice, or capped
    }

    _calculateOfflinePossibleMoves();

    // If bot rolled, perform automated decision
    if (_activeColor == 'Green') {
      Future.delayed(const Duration(milliseconds: 1200), _executeBotPawnSelection);
    }
  }

  void _moveOfflinePawn(int pawnId) {
    if (_rollState != 'rolled') return;
    
    final move = _possibleMoves.firstWhere((m) => m['pawnId'] == pawnId, orElse: () => <String, dynamic>{});
    if (move.isEmpty) return;

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
                _addHistoryMessage('$_activeColor captured $oppColor\'s pawn!');
              }
            }
          }
        });
      }
    }

    if (isKill) _playSfx('capture');
    if (move['to'] == 57) _playSfx('goal');

    // Win check
    if (_pawns[_activeColor]!.every((s) => s == 57)) {
      _showWinnerDialog(_activeColor == 'Red' ? 'You' : 'Bot Green', _activeColor);
      return;
    }

    // Extra roll check (rolled 6, captured, or reached goal)
    final getExtra = (_diceValue == 6 || isKill || move['to'] == 57);
    
    if (getExtra) {
      setState(() {
        _diceValue = null;
        _rollState = 'idle';
      });
      _addHistoryMessage('$_activeColor gets an extra roll!');
      if (_activeColor == 'Green') {
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
      _activeColor = _activeColor == 'Red' ? 'Green' : 'Red';
    });

    if (_activeColor == 'Green') {
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

    if (_isOffline) {
      _moveOfflinePawn(pawnId);
    } else {
      ref.read(socketServiceProvider).movePawn(widget.roomCode, pawnId);
    }
  }

  // --- Sound Effects Player Emulator ---

  void _playSfx(String type) {
    if (!LocalStorage.isSfxEnabled()) return;
    // Log sound to verify triggers
    print('[SFX PLAYED] -> ludo_sound_$type.wav');
  }

  void _addHistoryMessage(String text) {
    setState(() {
      _history.add({'text': text, 'timestamp': DateTime.now()});
    });
  }

  // --- Voice & Chat Toggles ---

  void _toggleVoiceChat() async {
    if (_isVoiceConnected && _lkRoom != null) {
      setState(() {
        _isVoiceMuted = !_isVoiceMuted;
      });
      try {
        await _lkRoom!.localParticipant?.setMicrophoneEnabled(!_isVoiceMuted);
        _addHistoryMessage('Microphone ${_isVoiceMuted ? 'Muted' : 'Unmuted'}');
      } catch (e) {
        print('Failed to toggle mic state: $e');
      }
    } else {
      _addHistoryMessage('Connecting to audio channel...');
      ref.read(socketServiceProvider).requestVoiceToken(widget.roomCode);
    }
  }

  void _sendChatMessage() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.primary, width: 2),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 20),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events, size: 80, color: AppColors.gold)
                  .animate()
                  .scale(duration: 800.ms, curve: Curves.bounceOut),
              const SizedBox(height: 16),
              Text(
                'MATCH COMPLETED',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textSecondary, letterSpacing: 2),
              ),
              const SizedBox(height: 8),
              Text(
                '$winnerName WON!',
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 26, 
                  color: winnerColor == 'Red'
                      ? AppColors.ludoRed
                      : winnerColor == 'Green'
                          ? AppColors.ludoGreen
                          : winnerColor == 'Yellow'
                              ? AppColors.ludoYellow
                              : AppColors.ludoBlue,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Winnings (+300 XP, Gold Prize Pool) credited to user wallet.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  context.go('/home');
                },
                child: const Text('BACK TO LOBBY'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Rendering UI Layout ---

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Calculate max available height for the board based on screen height
    final double reservedHeight = _isVoiceConnected ? 380.0 : 340.0;
    final double maxBoardHeight = size.height - reservedHeight;
    final boardSize = min(min(size.width - 32, 450.0), max(200.0, maxBoardHeight));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _isOffline ? 'OFFLINE PRACTICE VS AI' : 'MULTIPLAYER ROOM: ${widget.roomCode}',
          style: const TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.exit_to_app_rounded),
          onPressed: () {
            // Confirm quit dialog
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Abandon Match?'),
                content: const Text('Quitting this match counts as a forfeit. Entry fee coins will not be returned.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Resume')),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.go('/home');
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.ludoRed),
                    child: const Text('Forfeit & Leave'),
                  )
                ],
              ),
            );
          },
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isVoiceConnected 
                  ? (_isVoiceMuted ? Icons.mic_off : Icons.mic) 
                  : Icons.volume_up, 
              color: _isVoiceConnected 
                  ? (_isVoiceMuted ? AppColors.ludoRed : AppColors.ludoGreen) 
                  : AppColors.textSecondary
            ),
            onPressed: _toggleVoiceChat,
          ),
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
            ),
          )
        ],
      ),
      endDrawer: _buildChatDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            // Voice status indicator row
            if (_isVoiceConnected)
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.record_voice_over, color: AppColors.ludoGreen, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _activeSpeaker != null ? '$_activeSpeaker is speaking...' : 'Voice Chat Active (LiveKit)',
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

            // Bottom Dice roller deck
            _buildDiceConsoleDeck(),
            
            const SizedBox(height: 16),
          ],
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
        ? AppColors.ludoRed
        : color == 'Green'
            ? AppColors.ludoGreen
            : color == 'Yellow'
                ? AppColors.ludoYellow
                : AppColors.ludoBlue;

    return Column(
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
                  border: Border.all(color: colorVal, width: 3),
                  boxShadow: [
                    BoxShadow(color: colorVal.withOpacity(0.3), blurRadius: 10, spreadRadius: 2),
                  ],
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 600.ms),
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.surface,
              backgroundImage: NetworkImage(avatar),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          name, 
          style: TextStyle(
            fontSize: 11, 
            fontWeight: isTurn ? FontWeight.bold : FontWeight.normal,
            color: isTurn ? Colors.white : AppColors.textSecondary,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
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

        final tokenWidget = GestureDetector(
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

  Widget _buildDiceConsoleDeck() {
    final isMyTurn = _isLocalPlayerTurn();

    final Color activeColorVal = _activeColor == 'Red'
        ? AppColors.ludoRed
        : _activeColor == 'Green'
            ? AppColors.ludoGreen
            : _activeColor == 'Yellow'
                ? AppColors.ludoYellow
                : AppColors.ludoBlue;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isMyTurn ? activeColorVal : const Color(0xFF334155), width: 1.5),
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
                  isMyTurn ? 'YOUR TURN' : '${_activeColor.toUpperCase()}\'S TURN',
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: 15, 
                    color: activeColorVal,
                    fontFamily: 'Outfit',
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _rollState == 'idle' 
                      ? 'Roll the dice to advance' 
                      : 'Select highlighted pawn to move',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),

          // Right: styled dice box
          GestureDetector(
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
                        BoxShadow(color: activeColorVal.withOpacity(0.3), blurRadius: 15, spreadRadius: 3),
                      ],
                    ),
                  ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15), duration: 500.ms),
                
                // Dice body
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: activeColorVal,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 5, offset: Offset(0, 3)),
                    ],
                    gradient: LinearGradient(
                      colors: [activeColorVal, activeColorVal.withOpacity(0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: Colors.white38, width: 2),
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
        ],
      ),
    );
  }

  Widget _buildDiceFaceContent() {
    if (_diceValue == null) {
      return const Icon(Icons.casino_rounded, size: 28, color: Colors.white);
    }
    
    // Dot matrices representing Ludo dice faces
    switch (_diceValue) {
      case 1:
        return _buildDiceDots([const Alignment(0, 0)]);
      case 2:
        return _buildDiceDots([const Alignment(-0.6, -0.6), const Alignment(0.6, 0.6)]);
      case 3:
        return _buildDiceDots([const Alignment(-0.6, -0.6), const Alignment(0, 0), const Alignment(0.6, 0.6)]);
      case 4:
        return _buildDiceDots([
          const Alignment(-0.6, -0.6), const Alignment(0.6, -0.6),
          const Alignment(-0.6, 0.6), const Alignment(0.6, 0.6)
        ]);
      case 5:
        return _buildDiceDots([
          const Alignment(-0.6, -0.6), const Alignment(0.6, -0.6),
          const Alignment(0, 0),
          const Alignment(-0.6, 0.6), const Alignment(0.6, 0.6)
        ]);
      case 6:
        return _buildDiceDots([
          const Alignment(-0.6, -0.6), const Alignment(0.6, -0.6),
          const Alignment(-0.6, 0), const Alignment(0.6, 0),
          const Alignment(-0.6, 0.6), const Alignment(0.6, 0.6)
        ]);
      default:
        return const Icon(Icons.casino, size: 28, color: Colors.white);
    }
  }

  Widget _buildDiceDots(List<Alignment> alignments) {
    return Stack(
      children: alignments.map((align) {
        return Align(
          alignment: align,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
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

    // Set paint styles
    final Paint fillRed = Paint()..color = AppColors.ludoRed;
    final Paint fillGreen = Paint()..color = AppColors.ludoGreen;
    final Paint fillYellow = Paint()..color = AppColors.ludoYellow;
    final Paint fillBlue = Paint()..color = AppColors.ludoBlue;
    final Paint borderPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final Paint pathBackPaint = Paint()..color = const Color(0xFFE2E8F0);

    // 1. Draw 15x15 basic grid outline
    for (int col = 0; col < 15; col++) {
      for (int row = 0; row < 15; row++) {
        final rect = Rect.fromLTWH(col * stepSize, row * stepSize, stepSize, stepSize);
        canvas.drawRect(rect, pathBackPaint);
        canvas.drawRect(rect, borderPaint);
      }
    }

    // 2. Draw 4 primary quadrant bases (Yards)
    canvas.drawRect(Rect.fromLTWH(0, 0, stepSize * 6, stepSize * 6), fillRed);
    canvas.drawRect(Rect.fromLTWH(stepSize * 9, 0, stepSize * 6, stepSize * 6), fillGreen);
    canvas.drawRect(Rect.fromLTWH(stepSize * 9, stepSize * 9, stepSize * 6, stepSize * 6), fillYellow);
    canvas.drawRect(Rect.fromLTWH(0, stepSize * 9, stepSize * 6, stepSize * 6), fillBlue);

    // 3. Draw yard inner white panels
    _drawInnerYardPanel(canvas, 1 * stepSize, 1 * stepSize, stepSize * 4);
    _drawInnerYardPanel(canvas, 10 * stepSize, 1 * stepSize, stepSize * 4);
    _drawInnerYardPanel(canvas, 10 * stepSize, 10 * stepSize, stepSize * 4);
    _drawInnerYardPanel(canvas, 1 * stepSize, 10 * stepSize, stepSize * 4);

    // 4. Highlight path start/home stretch tracks
    // Red home stretch (row 7, col 1-5) & starting cell (row 6, col 1)
    for (int i = 1; i <= 5; i++) {
      canvas.drawRect(Rect.fromLTWH(i * stepSize, 7 * stepSize, stepSize, stepSize), fillRed);
    }
    canvas.drawRect(Rect.fromLTWH(1 * stepSize, 6 * stepSize, stepSize, stepSize), fillRed);

    // Green home stretch (col 7, row 1-5) & starting cell (row 1, col 8)
    for (int i = 1; i <= 5; i++) {
      canvas.drawRect(Rect.fromLTWH(7 * stepSize, i * stepSize, stepSize, stepSize), fillGreen);
    }
    canvas.drawRect(Rect.fromLTWH(8 * stepSize, 1 * stepSize, stepSize, stepSize), fillGreen);

    // Yellow home stretch (row 7, col 9-13) & starting cell (row 8, col 13)
    for (int i = 9; i <= 13; i++) {
      canvas.drawRect(Rect.fromLTWH(i * stepSize, 7 * stepSize, stepSize, stepSize), fillYellow);
    }
    canvas.drawRect(Rect.fromLTWH(13 * stepSize, 8 * stepSize, stepSize, stepSize), fillYellow);

    // Blue home stretch (col 7, row 9-13) & starting cell (row 13, col 6)
    for (int i = 9; i <= 13; i++) {
      canvas.drawRect(Rect.fromLTWH(7 * stepSize, i * stepSize, stepSize, stepSize), fillBlue);
    }
    canvas.drawRect(Rect.fromLTWH(6 * stepSize, 13 * stepSize, stepSize, stepSize), fillBlue);

    // 5. Draw safety Star stars
    // Stars at: (6,2), (8,6), (12,8), (6,12), (8,2), (13,8), (2,6), (8,12)
    _drawStar(canvas, 2 * stepSize, 6 * stepSize, stepSize);
    _drawStar(canvas, 8 * stepSize, 2 * stepSize, stepSize);
    _drawStar(canvas, 12 * stepSize, 8 * stepSize, stepSize);
    _drawStar(canvas, 6 * stepSize, 12 * stepSize, stepSize);
    
    _drawStar(canvas, 6 * stepSize, 8 * stepSize, stepSize);
    _drawStar(canvas, 8 * stepSize, 6 * stepSize, stepSize);
    _drawStar(canvas, 8 * stepSize, 8 * stepSize, stepSize);
    _drawStar(canvas, 6 * stepSize, 6 * stepSize, stepSize);

    // 6. Draw Center Goal triangles
    final Path redTriangle = Path()
      ..moveTo(6 * stepSize, 6 * stepSize)
      ..lineTo(7.5 * stepSize, 7.5 * stepSize)
      ..lineTo(6 * stepSize, 9 * stepSize)
      ..close();
    canvas.drawPath(redTriangle, fillRed);

    final Path greenTriangle = Path()
      ..moveTo(6 * stepSize, 6 * stepSize)
      ..lineTo(7.5 * stepSize, 7.5 * stepSize)
      ..lineTo(9 * stepSize, 6 * stepSize)
      ..close();
    canvas.drawPath(greenTriangle, fillGreen);

    final Path yellowTriangle = Path()
      ..moveTo(9 * stepSize, 6 * stepSize)
      ..lineTo(7.5 * stepSize, 7.5 * stepSize)
      ..lineTo(9 * stepSize, 9 * stepSize)
      ..close();
    canvas.drawPath(yellowTriangle, fillYellow);

    final Path blueTriangle = Path()
      ..moveTo(6 * stepSize, 9 * stepSize)
      ..lineTo(7.5 * stepSize, 7.5 * stepSize)
      ..lineTo(9 * stepSize, 9 * stepSize)
      ..close();
    canvas.drawPath(blueTriangle, fillBlue);

    // Draw borders over triangles
    canvas.drawPath(redTriangle, borderPaint);
    canvas.drawPath(greenTriangle, borderPaint);
    canvas.drawPath(yellowTriangle, borderPaint);
    canvas.drawPath(blueTriangle, borderPaint);
  }

  void _drawInnerYardPanel(Canvas canvas, double x, double y, double sideSize) {
    final Paint borderPaint = Paint()
      ..color = const Color(0xFF334155)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final Paint fillWhite = Paint()..color = Colors.white.withOpacity(0.9);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, sideSize, sideSize), const Radius.circular(8)), fillWhite);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, sideSize, sideSize), const Radius.circular(8)), borderPaint);
  }

  void _drawStar(Canvas canvas, double x, double y, double size) {
    final Paint starPaint = Paint()..color = const Color(0xFF64748B);
    final double cx = x + size / 2;
    final double cy = y + size / 2;
    final double outer = size * 0.35;
    final double inner = size * 0.15;

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
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
