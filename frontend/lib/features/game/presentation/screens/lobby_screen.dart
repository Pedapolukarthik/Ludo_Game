import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import '../../../../core/network/socket_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/services/audio_service.dart';

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
    AudioService.instance.playButtonClick();
    ref.read(socketServiceProvider).toggleReady(widget.roomCode);
  }

  void _startGame() {
    AudioService.instance.playButtonClick();
    ref.read(socketServiceProvider).startGame(widget.roomCode);
  }

  void _copyRoomCode() {
    AudioService.instance.playButtonClick();
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
        title: const Text('GAME LOBBY', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            AudioService.instance.playButtonClick();
            // Disconnect or leave room socket trigger
            context.go('/home');
          },
        ),
      ),
      body: Stack(
        children: [
          // Cyberpunk grid backing
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    colors: [AppColors.primary, Colors.transparent],
                    radius: 1.2,
                  ),
                ),
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Code Banner Card (Glassmorphic glow look)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.12),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(color: AppColors.primary.withOpacity(0.25), width: 1.5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                      child: Column(
                        children: [
                          Text(
                            'SHARE ROOM CODE',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.accentNeon.withOpacity(0.9),
                              letterSpacing: 2.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                widget.roomCode,
                                style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 6,
                                  fontFamily: 'Outfit',
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(color: AppColors.accentNeon, blurRadius: 12),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.content_copy_rounded, color: AppColors.accentNeon, size: 20),
                                  onPressed: _copyRoomCode,
                                  tooltip: 'Copy Room Code',
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 36, color: Color(0xFF26324A)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildInfoItem('FEE AMOUNT', '$_entryFee COINS', Icons.monetization_on_rounded, AppColors.gold),
                              _buildInfoItem('BATTLE MODE', '$_maxPlayers PLAYERS', Icons.casino_rounded, AppColors.secondary),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 28),
                
                const Text(
                  'PLAYERS IN LOBBY',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.8,
                  ),
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
                        
                        final playerColor = player['color'] == 'Red'
                            ? AppColors.tokenRed
                            : player['color'] == 'Green'
                                ? AppColors.tokenGreen
                                : player['color'] == 'Yellow'
                                    ? AppColors.tokenYellow
                                    : AppColors.tokenBlue;
    
                        return Card(
                          color: AppColors.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: isUserReady ? AppColors.ludoGreen.withOpacity(0.3) : const Color(0xFF26324A),
                              width: 1.2,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(2.0),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: playerColor, width: 2.0),
                              ),
                              child: CircleAvatar(
                                backgroundImage: NetworkImage(player['avatar']),
                                radius: 20,
                              ),
                            ),
                            title: Text(
                              player['name'],
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                            ),
                            subtitle: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: playerColor,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Color: ${player['color']}',
                                  style: TextStyle(
                                    color: playerColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isUserReady ? AppColors.ludoGreen.withOpacity(0.08) : Colors.white.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isUserReady ? AppColors.ludoGreen.withOpacity(0.8) : AppColors.textMuted.withOpacity(0.3),
                                  width: 1.2,
                                ),
                              ),
                              child: Text(
                                isUserReady ? 'READY' : 'WAITING',
                                style: TextStyle(
                                  color: isUserReady ? AppColors.ludoGreen : AppColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ),
                        );
                      } else {
                        // Empty slot
                        return Card(
                          color: AppColors.surface.withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.white.withOpacity(0.05), width: 1.0),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: Colors.white.withOpacity(0.05),
                              radius: 22,
                              child: Icon(Icons.person_add_alt_1_rounded, color: AppColors.textMuted.withOpacity(0.5)),
                            ),
                            title: Text(
                              'Empty Slot',
                              style: TextStyle(color: AppColors.textMuted.withOpacity(0.6), fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              'AI Bot will fill the slot if launched',
                              style: TextStyle(color: AppColors.textMuted.withOpacity(0.4), fontSize: 11),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
    
                const SizedBox(height: 20),
    
                // Start / Ready Trigger Button
                if (widget.isHost)
                  Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        if (canStart)
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: canStart ? _startGame : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: const Color(0xFF1E2638),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text('LAUNCH MATCH (${_players.length}/$_maxPlayers)'),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: (isMeReady ? AppColors.tokenRed : AppColors.ludoGreen).withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _toggleReady,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        backgroundColor: isMeReady ? AppColors.tokenRed : AppColors.tokenGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(isMeReady ? 'CANCEL READY' : 'MARK READY'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoItem(String title, String val, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title, 
              style: const TextStyle(
                fontSize: 10, 
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              val, 
              style: const TextStyle(
                fontSize: 14, 
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
