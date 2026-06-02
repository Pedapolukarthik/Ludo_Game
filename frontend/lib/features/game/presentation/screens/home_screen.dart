import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/network/socket_provider.dart';
import '../../../../core/services/local_storage.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/services/tts_service.dart';
import '../../../../core/widgets/bottom_dock.dart';

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

  @override
  void dispose() {
    super.dispose();
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
            onPressed: () {
              AudioService.instance.playButtonClick();
              TtsService.instance.speak("Cancel");
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              AudioService.instance.playButtonClick();
              TtsService.instance.speak("Join");
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
                    onChanged: (val) {
                      TtsService.instance.speak("Two players");
                      setDialogState(() => selectedPlayers = val!);
                    },
                  ),
                  const Text('2 Players'),
                  const SizedBox(width: 16),
                  Radio<int>(
                    value: 4,
                    groupValue: selectedPlayers,
                    onChanged: (val) {
                      TtsService.instance.speak("Four players");
                      setDialogState(() => selectedPlayers = val!);
                    },
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
                onChanged: (val) {
                  if (val != null) {
                    TtsService.instance.speak("$val coins");
                    setDialogState(() => entryFee = val);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                AudioService.instance.playButtonClick();
                TtsService.instance.speak("Cancel");
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                AudioService.instance.playButtonClick();
                TtsService.instance.speak("Create");
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

    // Calculate level progress (e.g. user needs 1000 XP per level)
    final double xpInLevel = (user.xp % 1000).toDouble();
    final double xpProgress = xpInLevel / 1000.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Cyberpunk glowing backdrop
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    colors: [AppColors.primary, Colors.transparent],
                    radius: 1.5,
                  ),
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Profile & Currency Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // User Info with Rank border
                      Semantics(
                        label: 'Gamer Profile: ${user.name}',
                        hint: 'Double tap to view stats',
                        button: true,
                        child: GestureDetector(
                          onTap: () {
                            AudioService.instance.playButtonClick();
                            TtsService.instance.speak("Gamer Profile");
                            context.go('/profile');
                          },
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(2.5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: AppTheme.cyberGradient,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.accentNeon.withOpacity(0.3),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 22,
                                  backgroundColor: AppColors.surface,
                                  backgroundImage: NetworkImage(user.avatar),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        user.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.white,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.verified_user_rounded,
                                        size: 14,
                                        color: AppColors.accentNeon,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: AppColors.primary.withOpacity(0.4), width: 0.8),
                                        ),
                                        child: Text(
                                          'LVL ${user.level}',
                                          style: const TextStyle(
                                            color: AppColors.accentNeon,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 70,
                                        height: 4,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(2),
                                          child: LinearProgressIndicator(
                                            value: xpProgress,
                                            backgroundColor: Colors.white12,
                                            valueColor: const AlwaysStoppedAnimation(AppColors.accentNeon),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Wallet & Settings
                      Row(
                        children: [
                          Semantics(
                            label: 'Ludo Coins Balance',
                            value: '${user.coins} coins',
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: AppColors.gold.withOpacity(0.4)),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.gold.withOpacity(0.1),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.monetization_on_rounded, color: AppColors.gold, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${user.coins}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (user.isAdmin) ...[
                            Semantics(
                              label: 'Admin Control Panel Button',
                              hint: 'Double tap to open admin panel',
                              button: true,
                              child: IconButton(
                                icon: const Icon(Icons.admin_panel_settings_rounded, color: AppColors.secondary),
                                tooltip: 'Open Admin Control Panel',
                                onPressed: () {
                                  AudioService.instance.playButtonClick();
                                  TtsService.instance.speak("Admin Control Panel");
                                  context.go('/admin');
                                },
                              ),
                            ),
                          ],
                          Semantics(
                            label: 'Settings Button',
                            hint: 'Double tap to open settings',
                            button: true,
                            child: IconButton(
                              icon: const Icon(Icons.settings_suggest_rounded, color: Colors.white),
                              onPressed: () {
                                AudioService.instance.playButtonClick();
                                TtsService.instance.speak("Settings");
                                context.go('/settings');
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Promoted Banner Card
                  Container(
                    height: 90,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: AppTheme.cyberGradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                      border: Border.all(color: AppColors.accentNeon.withOpacity(0.3), width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'LUDO ARENA',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2.0,
                                color: Colors.white,
                                fontFamily: 'Outfit',
                                shadows: [
                                  Shadow(color: Colors.black45, blurRadius: 6),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black38,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.accentNeon.withOpacity(0.5), width: 0.8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.workspace_premium_rounded, color: AppColors.gold, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    'LEAGUE SEASON 1',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.accentNeon,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Icon(
                          Icons.casino_rounded,
                          size: 54,
                          color: Colors.white.withOpacity(0.25),
                        ).animate(onPlay: (c) => c.repeat(reverse: true))
                         .rotate(duration: 3.seconds)
                         .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 1.5.seconds),
                      ],
                    ),
                  )
                  .animate()
                  .fade(duration: 500.ms, delay: 200.ms)
                  .slideY(begin: 0.1, end: 0),
                  
                  const SizedBox(height: 24),

                  // Game Modes Layout
                  const Text(
                    'CHOOSE BATTLEFIELD',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                      letterSpacing: 2.0,
                    ),
                  ).animate().fade(delay: 300.ms),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      // Matchmaking 2P
                      Expanded(
                        child: _buildModeCard(
                          title: 'Quick Match',
                          subtitle: '2 Players',
                          icon: Icons.flash_on_rounded,
                          color: AppColors.ludoBlue,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2E8BC0), Color(0xFF145DA0)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          onTap: () => _startMatchmaking(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Matchmaking 4P
                      Expanded(
                        child: _buildModeCard(
                          title: 'Classic Battle',
                          subtitle: '4 Players',
                          icon: Icons.groups_rounded,
                          color: AppColors.ludoRed,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF2E63), Color(0xFFB83B5E)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          onTap: () => _startMatchmaking(4),
                        ),
                      ),
                    ],
                  ).animate().fade(delay: 350.ms).slideY(begin: 0.05, end: 0),
                  
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      // Custom Room
                      Expanded(
                        child: _buildModeCard(
                          title: 'Create Room',
                          subtitle: 'Play with Friends',
                          icon: Icons.add_circle_outline_rounded,
                          color: AppColors.ludoGreen,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF08D9D6), Color(0xFF00ADB5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          onTap: _showCreateRoomDialog,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Join Room
                      Expanded(
                        child: _buildModeCard(
                          title: 'Join Room',
                          subtitle: 'Enter Room Code',
                          icon: Icons.vpn_key_rounded,
                          color: AppColors.ludoYellow,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFE259), Color(0xFFFFA751)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          onTap: _showJoinRoomDialog,
                        ),
                      ),
                    ],
                  ).animate().fade(delay: 400.ms).slideY(begin: 0.05, end: 0),

                  const SizedBox(height: 16),

                  // Local Multiplayer Card
                  _buildLocalMultiplayerCard().animate().fade(delay: 420.ms).slideY(begin: 0.05, end: 0),

                  const SizedBox(height: 16),

                  // Bot Selector Card
                  _buildBotSelector().animate().fade(delay: 450.ms).slideY(begin: 0.05, end: 0),
                  
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          // Matchmaking Modal Overlay
          if (_isMatching)
            _buildMatchmakingOverlay().animate().fade(duration: 300.ms),
        ],
      ),
      bottomNavigationBar: const BottomDock(activeTab: 'home'),
    );
  }

  Widget _buildModeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return Semantics(
      label: 'Game Mode Card: $title',
      hint: 'Double tap to play $subtitle',
      button: true,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: color.withOpacity(0.3), width: 1.2),
          ),
          child: InkWell(
            onTap: () {
              AudioService.instance.playButtonClick();
              TtsService.instance.speak(title);
              onTap();
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [AppColors.cardBg, AppColors.surface.withOpacity(0.8)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: gradient,
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 1,
                        )
                      ]
                    ),
                    child: Icon(icon, size: 24, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withOpacity(0.3), width: 0.8),
                    ),
                    child: Text(
                      subtitle.toUpperCase(),
                      style: TextStyle(
                        color: color,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBotSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.rocket_launch_rounded, color: AppColors.ludoGreen, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'AI BATTLE',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.white,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDifficultyBtn('EASY', AppColors.ludoGreen, () => _startAiMatch('easy')),
                const SizedBox(width: 6),
                _buildDifficultyBtn('MED', AppColors.ludoYellow, () => _startAiMatch('medium')),
                const SizedBox(width: 6),
                _buildDifficultyBtn('HARD', AppColors.tokenRed, () => _startAiMatch('hard')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyBtn(String label, Color color, VoidCallback onTap) {
    return Semantics(
      label: 'Practice Mode Difficulty: $label',
      hint: 'Double tap to start an offline match against a $label AI bot',
      button: true,
      child: InkWell(
        onTap: () {
          AudioService.instance.playButtonClick();
          TtsService.instance.speak("$label difficulty");
          onTap();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.4), width: 1.2),
          ),
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 10,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocalMultiplayerCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.purple.withOpacity(0.3), width: 1.2),
        ),
        child: InkWell(
          onTap: () {
            AudioService.instance.playButtonClick();
            TtsService.instance.speak("Local Multiplayer Mode");
            _showLocalMultiplayerDialog();
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [AppColors.cardBg, AppColors.surface.withOpacity(0.85)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8A2387), Color(0xFFE94057)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(Icons.phone_android_rounded, size: 20, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'LOCAL MULTIPLAYER',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.purple.withOpacity(0.3), width: 0.8),
                        ),
                        child: Text(
                          'PASS & PLAY',
                          style: GoogleFonts.outfit(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple[200],
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLocalMultiplayerDialog() {
    int playerCount = 4;
    final List<TextEditingController> controllers = [
      TextEditingController(text: 'Player 1'),
      TextEditingController(text: 'Player 2'),
      TextEditingController(text: 'Player 3'),
      TextEditingController(text: 'Player 4'),
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: Colors.purple.withOpacity(0.4), width: 1.5),
            ),
            title: Text(
              'Local Multiplayer Setup',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.white,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose Player Count',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [2, 3, 4].map((count) {
                      final isSelected = playerCount == count;
                      return ChoiceChip(
                        label: Text('$count Players', style: TextStyle(color: isSelected ? Colors.white : Colors.white70)),
                        selected: isSelected,
                        selectedColor: Colors.purple,
                        backgroundColor: AppColors.cardBg,
                        onSelected: (selected) {
                          if (selected) {
                            TtsService.instance.speak('$count players');
                            setDialogState(() {
                              playerCount = count;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Player Names',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...List.generate(playerCount, (index) {
                    final colors = ['Red', 'Green', 'Yellow', 'Blue'];
                    final colorVals = [
                      AppColors.ludoRed,
                      AppColors.ludoGreen,
                      AppColors.ludoYellow,
                      AppColors.ludoBlue,
                    ];
                    final colorName = colors[index];
                    final colorVal = colorVals[index];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colorVal,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: controllers[index],
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                labelText: '$colorName Player Name',
                                labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                                enabledBorder: const UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white24),
                                ),
                                focusedBorder: const UnderlineInputBorder(
                                  borderSide: BorderSide(color: Colors.purple),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  AudioService.instance.playButtonClick();
                  TtsService.instance.speak("Cancel");
                  Navigator.pop(context);
                },
                child: Text('Cancel', style: TextStyle(color: Colors.white.withOpacity(0.7))),
              ),
              ElevatedButton(
                onPressed: () {
                  AudioService.instance.playButtonClick();
                  TtsService.instance.speak("Start Match");
                  
                  // Extract player details
                  final List<String> names = [];
                  for (int i = 0; i < playerCount; i++) {
                    final name = controllers[i].text.trim();
                    names.add(name.isNotEmpty ? name : 'Player ${i + 1}');
                  }

                  Navigator.pop(context);
                  _startLocalMultiplayerMatch(playerCount, names);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('START MATCH'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _startLocalMultiplayerMatch(int playerCount, List<String> names) {
    final mockRoomCode = 'LOCAL_${DateTime.now().millisecondsSinceEpoch}';
    final List<String> activeColors = [];
    final List<Map<String, dynamic>> players = [];
    final Map<String, List<int>> pawns = {};

    final colors = ['Red', 'Green', 'Yellow', 'Blue'];

    for (int i = 0; i < playerCount; i++) {
      final colorName = colors[i];
      activeColors.add(colorName);
      players.add({
        'userId': 'local_p${i + 1}',
        'name': names[i],
        'avatar': 'https://api.dicebear.com/7.x/pixel-art/png?seed=${names[i]}',
        'color': colorName,
        'isBot': false,
        'active': true
      });
      pawns[colorName] = [0, 0, 0, 0];
    }

    final mockGameState = {
      'roomCode': mockRoomCode,
      'players': players,
      'colors': activeColors,
      'activeColor': 'Red',
      'diceValue': null,
      'rollState': 'idle',
      'consecutiveSixes': 0,
      'pawns': pawns,
      'winner': null,
      'history': []
    };

    context.go('/game', extra: {
      'roomCode': mockRoomCode,
      'gameState': mockGameState
    });
  }


  Widget _buildMatchmakingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.9),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Tech Lottie Radar/Dice Loading Animation
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.secondary.withOpacity(0.2),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Lottie.asset(
                    'assets/animations/loading.json',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.casino, size: 80, color: AppColors.secondary);
                    },
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              const Text(
                'SEARCHING FOR RIVALS...',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                  fontFamily: 'Outfit',
                  color: Colors.white,
                  shadows: [
                    Shadow(color: AppColors.secondary, blurRadius: 10),
                  ],
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true))
               .scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 800.ms),
               
              const SizedBox(height: 8),
              
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.textMuted.withOpacity(0.3)),
                ),
                child: Text(
                  'Mode: $_activeMatchMode',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
              
              const SizedBox(height: 12),
              
              Text(
                'Players joined queue: $_matchingCount',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              
              const SizedBox(height: 48),
              
              ElevatedButton(
                onPressed: () {
                  AudioService.instance.playButtonClick();
                  TtsService.instance.speak("Cancel matchmaking");
                  _cancelMatchmaking();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.tokenRed,
                  shadowColor: AppColors.tokenRed.withOpacity(0.4),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('ABORT MISSION'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
