import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/network/socket_provider.dart';
import '../../../../core/services/local_storage.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isMatching = false;
  int _matchingCount = 0;
  String _activeMatchMode = '2 Players';

  @override
  void initState() {
    super.initState();
    _connectSocket();
  }

  void _connectSocket() {
    final token = LocalStorage.getToken();
    if (token != null) {
      final socket = ref.read(socketServiceProvider);
      socket.connect(token);
      
      // Bind event listeners
      socket.onMatchmakingStatus = (data) {
        if (mounted) {
          setState(() {
            _isMatching = data['status'] == 'waiting';
            _matchingCount = data['count'] ?? 0;
          });
        }
      };

      socket.onMatchFound = (data) {
        if (mounted) {
          setState(() {
            _isMatching = false;
          });
          context.go('/game', extra: {
            'roomCode': data['roomCode'],
            'gameState': data['gameState'],
          });
        }
      };

      socket.onRoomCreated = (data) {
        if (mounted) {
          context.go('/lobby', extra: {
            'roomCode': data['code'],
            'isHost': true,
          });
        }
      };

      socket.onRoomJoined = (data) {
        if (mounted) {
          context.go('/lobby', extra: {
            'roomCode': data['code'],
            'isHost': false,
          });
        }
      };
      
      socket.onError = (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err), backgroundColor: AppColors.ludoRed),
          );
        }
      };
    }
  }

  void _startMatchmaking(int maxPlayers) {
    setState(() {
      _isMatching = true;
      _activeMatchMode = '$maxPlayers Players';
    });
    ref.read(socketServiceProvider).joinMatchmaking('classic', maxPlayers);
  }

  void _cancelMatchmaking() {
    setState(() {
      _isMatching = false;
    });
    ref.read(socketServiceProvider).leaveMatchmaking();
  }

  void _showJoinRoomDialog() {
    final codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Room', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        content: TextField(
          controller: codeController,
          decoration: const InputDecoration(
            hintText: 'Enter 6-digit Room Code',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final code = codeController.text.trim();
              if (code.isNotEmpty) {
                ref.read(socketServiceProvider).joinRoom(code);
                Navigator.pop(context);
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  void _showCreateRoomDialog() {
    int selectedPlayers = 4;
    int entryFee = 100;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Room', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Player Count', style: TextStyle(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Radio<int>(
                    value: 2,
                    groupValue: selectedPlayers,
                    onChanged: (val) => setDialogState(() => selectedPlayers = val!),
                  ),
                  const Text('2 Players'),
                  const SizedBox(width: 16),
                  Radio<int>(
                    value: 4,
                    groupValue: selectedPlayers,
                    onChanged: (val) => setDialogState(() => selectedPlayers = val!),
                  ),
                  const Text('4 Players'),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Entry Fee (Coins)', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<int>(
                value: entryFee,
                isExpanded: true,
                items: [50, 100, 200, 500, 1000].map((fee) {
                  return DropdownMenuItem<int>(
                    value: fee,
                    child: Text('$fee Coins'),
                  );
                }).toList(),
                onChanged: (val) => setDialogState(() => entryFee = val!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                ref.read(socketServiceProvider).createRoom(selectedPlayers, entryFee);
                Navigator.pop(context);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _startAiMatch(String difficulty) {
    // Generate a mock game room offline directly for local play
    final mockRoomCode = 'BOT_${difficulty.toUpperCase()}';
    final mockGameState = {
      'roomCode': mockRoomCode,
      'players': [
        {
          'userId': 'me',
          'name': ref.read(authProvider).user?.name ?? 'Player',
          'avatar': ref.read(authProvider).user?.avatar ?? '',
          'color': 'Red',
          'isBot': false,
          'active': true
        },
        {
          'userId': null,
          'name': 'Bot Green',
          'avatar': 'https://api.dicebear.com/7.x/bottts/png?seed=BotGreen',
          'color': 'Green',
          'isBot': true,
          'botDifficulty': difficulty,
          'active': true
        }
      ],
      'colors': ['Red', 'Green'],
      'activeColor': 'Red',
      'diceValue': null,
      'rollState': 'idle',
      'consecutiveSixes': 0,
      'pawns': {
        'Red': [0, 0, 0, 0],
        'Green': [0, 0, 0, 0]
      },
      'winner': null,
      'history': []
    };

    context.go('/game', extra: {
      'roomCode': mockRoomCode,
      'gameState': mockGameState
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Profile & Currency Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // User Info
                      GestureDetector(
                        onTap: () => context.go('/profile'),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: AppColors.primary,
                              backgroundImage: NetworkImage(user.avatar),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Text(
                                  'Level ${user.level}',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      // Wallet & Settings
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.monetization_on, color: AppColors.gold, size: 20),
                                const SizedBox(width: 4),
                                Text(
                                  '${user.coins}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (user.isAdmin) ...[
                            IconButton(
                              icon: const Icon(Icons.admin_panel_settings, color: AppColors.secondary),
                              tooltip: 'Open Admin Control Panel',
                              onPressed: () => context.go('/admin'),
                            ),
                            const SizedBox(width: 4),
                          ],
                          IconButton(
                            icon: const Icon(Icons.settings, color: Colors.white),
                            onPressed: () => context.go('/settings'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Promoted Banner Card
                  Container(
                    height: 140,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppTheme.purplePinkGradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'LUDO ARENA',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontFamily: 'Outfit'),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Play online, claim rewards,\nwin real gaming glory!',
                              style: TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                          ],
                        ),
                        Icon(Icons.casino_rounded, size: 80, color: Colors.white.withOpacity(0.2)),
                      ],
                    ),
                  )
                  .animate()
                  .fade(duration: 500.ms)
                  .slideY(begin: 0.1, end: 0),
                  
                  const SizedBox(height: 24),

                  // Game Modes Layout
                  const Text(
                    'CHOOSE BATTLEFIELD',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      // Matchmaking 2P
                      Expanded(
                        child: _buildModeCard(
                          title: 'Quick Match',
                          subtitle: '2 Players',
                          icon: Icons.flash_on,
                          color: AppColors.ludoBlue,
                          onTap: () => _startMatchmaking(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Matchmaking 4P
                      Expanded(
                        child: _buildModeCard(
                          title: 'Classic Battle',
                          subtitle: '4 Players',
                          icon: Icons.groups,
                          color: AppColors.ludoRed,
                          onTap: () => _startMatchmaking(4),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      // Custom Room
                      Expanded(
                        child: _buildModeCard(
                          title: 'Create Room',
                          subtitle: 'With friends',
                          icon: Icons.add_circle,
                          color: AppColors.ludoGreen,
                          onTap: _showCreateRoomDialog,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Join Room
                      Expanded(
                        child: _buildModeCard(
                          title: 'Join Room',
                          subtitle: 'Enter Code',
                          icon: Icons.vpn_key,
                          color: AppColors.ludoYellow,
                          onTap: _showJoinRoomDialog,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Bot Heuristics Card
                  _buildBotSelector(),

                  const SizedBox(height: 16),

                  // Nav Action row
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionNav(
                          title: 'LEADERBOARD',
                          icon: Icons.emoji_events,
                          color: AppColors.gold,
                          onTap: () => context.go('/leaderboard'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionNav(
                          title: 'REWARDS WHEEL',
                          icon: Icons.star,
                          color: AppColors.secondary,
                          onTap: () => context.go('/rewards'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Matchmaking Modal Overlay
          if (_isMatching)
            _buildMatchmakingOverlay(),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            children: [
              Icon(icon, size: 36, color: color),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionNav({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBotSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PRACTICE MODE (VS AI BOT)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildDifficultyBtn('EASY', AppColors.ludoGreen, () => _startAiMatch('easy')),
                _buildDifficultyBtn('MEDIUM', AppColors.ludoYellow, () => _startAiMatch('medium')),
                _buildDifficultyBtn('HARD', AppColors.ludoRed, () => _startAiMatch('hard')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyBtn(String label, Color color, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withOpacity(0.5)),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildMatchmakingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Floating dice animation
            const Icon(Icons.casino, size: 80, color: AppColors.secondary)
                .animate(onPlay: (controller) => controller.repeat())
                .rotate(duration: 1.seconds),
            
            const SizedBox(height: 24),
            
            const Text(
              'FINDING MATCH...',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2, fontFamily: 'Outfit'),
            ),
            const SizedBox(height: 8),
            
            Text(
              'Mode: $_activeMatchMode',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            
            const SizedBox(height: 4),
            
            Text(
              'Players joined queue: $_matchingCount',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            
            const SizedBox(height: 48),
            
            ElevatedButton(
              onPressed: _cancelMatchmaking,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ludoRed,
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
              ),
              child: const Text('CANCEL MATCHMAKING'),
            ),
          ],
        ),
      ),
    );
  }
}
