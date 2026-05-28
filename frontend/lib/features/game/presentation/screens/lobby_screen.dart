import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import '../../../../core/network/socket_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  final String roomCode;
  final bool isHost;

  const LobbyScreen({
    super.key,
    required this.roomCode,
    required this.isHost,
  });

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  List<dynamic> _players = [];
  int _maxPlayers = 4;
  int _entryFee = 100;

  @override
  void initState() {
    super.initState();
    _setupLobbyListeners();
  }

  void _setupLobbyListeners() {
    final socket = ref.read(socketServiceProvider);

    socket.onRoomUpdated = (data) {
      if (mounted) {
        setState(() {
          _players = data['players'] ?? [];
          _maxPlayers = data['maxPlayers'] ?? 4;
          _entryFee = data['entryFee'] ?? 100;
        });
      }
    };

    socket.onPlayerJoined = (data) {
      if (mounted) {
        setState(() {
          _players = data['players'] ?? [];
        });
      }
    };

    socket.onGameStarted = (data) {
      if (mounted) {
        context.go('/game', extra: {
          'roomCode': data['roomCode'],
          'gameState': data,
        });
      }
    };
  }

  void _toggleReady() {
    ref.read(socketServiceProvider).toggleReady(widget.roomCode);
  }

  void _startGame() {
    ref.read(socketServiceProvider).startGame(widget.roomCode);
  }

  void _copyRoomCode() {
    Clipboard.setData(ClipboardData(text: widget.roomCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Room code copied to clipboard!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.read(authProvider).user?.id;

    // Check if current user is ready
    Map<String, dynamic>? me;
    for (var p in _players) {
      if (p['user'] != null && p['user'].toString() == currentUserId) {
        me = p as Map<String, dynamic>;
        break;
      }
    }
    final isMeReady = me?['ready'] ?? false;

    // Count ready players
    final readyCount = _players.where((p) => p['ready'] == true).length;
    final canStart = readyCount >= 2; // Need at least 2 players to play (even if others are bots)

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('GAME LOBBY', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            // Disconnect or leave room socket trigger
            context.go('/home');
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Code Banner Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      'SHARE ROOM CODE',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary, letterSpacing: 1),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.roomCode,
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4, fontFamily: 'Outfit'),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, color: AppColors.primary),
                          onPressed: _copyRoomCode,
                        ),
                      ],
                    ),
                    const Divider(height: 32, color: Color(0xFF334155)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildInfoItem('Fee', '$_entryFee Coins', Icons.monetization_on, AppColors.gold),
                        _buildInfoItem('Mode', '$_maxPlayers Players', Icons.casino, AppColors.secondary),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            const Text(
              'PLAYERS IN LOBBY',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary, letterSpacing: 1),
            ),
            const SizedBox(height: 12),

            // Player slots list
            Expanded(
              child: ListView.builder(
                itemCount: _maxPlayers,
                itemBuilder: (context, idx) {
                  if (idx < _players.length) {
                    final player = _players[idx];
                    final isUserReady = player['ready'] == true;
                    return Card(
                      color: AppColors.surface,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage(player['avatar']),
                        ),
                        title: Text(
                          player['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Color: ${player['color']}',
                          style: TextStyle(
                            color: player['color'] == 'Red'
                                ? AppColors.ludoRed
                                : player['color'] == 'Green'
                                    ? AppColors.ludoGreen
                                    : player['color'] == 'Yellow'
                                        ? AppColors.ludoYellow
                                        : AppColors.ludoBlue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isUserReady ? AppColors.ludoGreen.withOpacity(0.15) : AppColors.textMuted.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isUserReady ? AppColors.ludoGreen : AppColors.textMuted),
                          ),
                          child: Text(
                            isUserReady ? 'READY' : 'WAITING',
                            style: TextStyle(
                              color: isUserReady ? AppColors.ludoGreen : AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    );
                  } else {
                    // Empty slot
                    return Card(
                      color: AppColors.surface.withOpacity(0.5),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.transparent,
                          child: Icon(Icons.person_add_rounded, color: AppColors.textMuted.withOpacity(0.5)),
                        ),
                        title: Text(
                          'Empty Slot',
                          style: TextStyle(color: AppColors.textMuted.withOpacity(0.5)),
                        ),
                        subtitle: Text(
                          'AI Bot will join if launched',
                          style: TextStyle(color: AppColors.textMuted.withOpacity(0.3), fontSize: 11),
                        ),
                      ),
                    );
                  }
                },
              ),
            ),

            const SizedBox(height: 16),

            // Start / Ready Trigger Button
            if (widget.isHost)
              ElevatedButton(
                onPressed: canStart ? _startGame : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.primary,
                ),
                child: Text('LAUNCH MATCH (${_players.length}/$_maxPlayers)'),
              )
            else
              ElevatedButton(
                onPressed: _toggleReady,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: isMeReady ? AppColors.ludoRed : AppColors.ludoGreen,
                ),
                child: Text(isMeReady ? 'CANCEL READY' : 'MARK READY'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String title, String val, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
            Text(val, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}
