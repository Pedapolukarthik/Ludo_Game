import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/env_config.dart';

class SocketService {
  io.Socket? _socket;
  String get _serverUrl => EnvConfig.socketUrl;

  // Callbacks for screen state synchronization
  void Function(Map<String, dynamic>)? onMatchFound;
  void Function(Map<String, dynamic>)? onMatchmakingStatus;
  void Function(Map<String, dynamic>)? onRoomCreated;
  void Function(Map<String, dynamic>)? onRoomJoined;
  void Function(Map<String, dynamic>)? onRoomUpdated;
  void Function(Map<String, dynamic>)? onPlayerJoined;
  void Function(Map<String, dynamic>)? onGameStarted;
  void Function(Map<String, dynamic>)? onDiceRolled;
  void Function(Map<String, dynamic>)? onPawnMoved;
  void Function(Map<String, dynamic>)? onTurnChanged;
  void Function(Map<String, dynamic>)? onChatMessage;
  void Function(Map<String, dynamic>)? onEmojiReaction;
  void Function(Map<String, dynamic>)? onVoiceToken;
  void Function(Map<String, dynamic>)? onGameEnded;
  void Function(String)? onError;
  void Function()? onConnect;
  void Function()? onDisconnect;

  bool get isConnected => _socket?.connected ?? false;

  void connect(String token) {
    if (_socket != null && _socket!.connected) return;

    _socket = io.io(_serverUrl, io.OptionBuilder()
      .setTransports(['websocket'])
      .setAuth({'token': token})
      .disableAutoConnect()
      .build());

    _socket!.onConnect((_) {
      print('Connected to socket server');
      onConnect?.call();
    });

    _socket!.onDisconnect((_) {
      print('Disconnected from socket server');
      onDisconnect?.call();
    });

    _socket!.onConnectError((data) {
      print('Socket connection error: $data');
      onError?.call('Connection failed: ${data.toString()}');
    });

    // Matchmaking Events
    _socket!.on('match_found', (data) => onMatchFound?.call(Map<String, dynamic>.from(data)));
    _socket!.on('matchmaking_status', (data) => onMatchmakingStatus?.call(Map<String, dynamic>.from(data)));
    
    // Custom Room Events
    _socket!.on('room_created', (data) => onRoomCreated?.call(Map<String, dynamic>.from(data)));
    _socket!.on('room_joined', (data) => onRoomJoined?.call(Map<String, dynamic>.from(data)));
    _socket!.on('room_updated', (data) => onRoomUpdated?.call(Map<String, dynamic>.from(data)));
    _socket!.on('player_joined', (data) => onPlayerJoined?.call(Map<String, dynamic>.from(data)));
    _socket!.on('game_started', (data) => onGameStarted?.call(Map<String, dynamic>.from(data)));
    
    // Game Action Events
    _socket!.on('dice_rolled', (data) => onDiceRolled?.call(Map<String, dynamic>.from(data)));
    _socket!.on('pawn_moved', (data) => onPawnMoved?.call(Map<String, dynamic>.from(data)));
    _socket!.on('turn_changed', (data) => onTurnChanged?.call(Map<String, dynamic>.from(data)));
    _socket!.on('game_ended', (data) => onGameEnded?.call(Map<String, dynamic>.from(data)));
    
    // Auxiliary Action Events
    _socket!.on('chat_message', (data) => onChatMessage?.call(Map<String, dynamic>.from(data)));
    _socket!.on('emoji_reaction', (data) => onEmojiReaction?.call(Map<String, dynamic>.from(data)));
    _socket!.on('voice_token', (data) => onVoiceToken?.call(Map<String, dynamic>.from(data)));
    
    _socket!.on('error', (data) => onError?.call(data.toString()));

    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  // --- Emits ---

  void joinMatchmaking(String mode, int maxPlayers) {
    _socket?.emit('join_matchmaking', {'mode': mode, 'maxPlayers': maxPlayers});
  }

  void leaveMatchmaking() {
    _socket?.emit('leave_matchmaking');
  }

  void createRoom(int maxPlayers, int entryFee) {
    _socket?.emit('create_room', {'maxPlayers': maxPlayers, 'entryFee': entryFee});
  }

  void joinRoom(String code) {
    _socket?.emit('join_room', {'code': code});
  }

  void toggleReady(String roomCode) {
    _socket?.emit('toggle_ready', {'roomCode': roomCode});
  }

  void startGame(String roomCode) {
    _socket?.emit('start_game', {'roomCode': roomCode});
  }

  void rollDice(String roomCode) {
    _socket?.emit('roll_dice', {'roomCode': roomCode});
  }

  void movePawn(String roomCode, int pawnId) {
    _socket?.emit('move_pawn', {'roomCode': roomCode, 'pawnId': pawnId});
  }

  void sendMessage(String roomCode, String text) {
    _socket?.emit('send_message', {'roomCode': roomCode, 'text': text});
  }

  void sendReaction(String roomCode, String reactionId) {
    _socket?.emit('send_reaction', {'roomCode': roomCode, 'reactionId': reactionId});
  }

  void requestVoiceToken(String roomCode) {
    _socket?.emit('request_voice_token', {'roomCode': roomCode});
  }
}
