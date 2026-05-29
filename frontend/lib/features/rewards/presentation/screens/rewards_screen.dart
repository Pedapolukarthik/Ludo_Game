import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/missions_widget.dart';
import '../providers/missions_provider.dart';

class RewardsScreen extends ConsumerStatefulWidget {
  const RewardsScreen({super.key});

  @override
  ConsumerState<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends ConsumerState<RewardsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _spinController;
  late Animation<double> _animation;
  double _currentRotation = 0.0;
  bool _isSpinning = false;
  bool _dailyClaimed = false;
  bool _spinClaimed = false;

  final List<String> _wheelSegments = [
    '50 Coins',
    '100 Coins',
    '200 Coins',
    '500 Coins',
    '150 XP',
    '1000 Coins',
  ];

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _animation = CurvedAnimation(
      parent: _spinController,
      curve: Curves.decelerate,
    );

    _checkClaims();
  }

  void _checkClaims() {
    final user = ref.read(authProvider).user;
    if (user != null) {
      final todayClaimKey = 'DailyClaim_' + DateTime.now().toDateString();
      final todaySpinKey = 'SpinClaim_' + DateTime.now().toDateString();
      
      setState(() {
        _dailyClaimed = user.achievements.contains(todayClaimKey);
        _spinClaimed = user.achievements.contains(todaySpinKey);
      });
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  void _claimDailyReward() async {
    try {
      final response = await ApiClient.post('/rewards/daily', {});
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _dailyClaimed = true;
        });
        // Update user state coins & XP in Riverpod
        ref.read(authProvider.notifier).tryRestoreSession();
        ref.read(dailyMissionsProvider.notifier).fetchMissions();
        _showSuccessDialog('Daily Reward', data['message']);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Claim failed')),
        );
      }
    } catch (e) {
      print(e);
    }
  }

  void _spinWheel() async {
    if (_isSpinning || _spinClaimed) return;

    setState(() {
      _isSpinning = true;
    });

    try {
      final response = await ApiClient.post('/rewards/spin', {});
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final outcome = data['outcome'];
        final label = outcome['label'];
        
        // Find segment index to align rotation angle
        // Outcomes: 50, 100, 200, 500, 150, 1000
        int targetIdx = 0;
        if (label.contains('50 Coins')) targetIdx = 0;
        else if (label.contains('100 Coins')) targetIdx = 1;
        else if (label.contains('200 Coins')) targetIdx = 2;
        else if (label.contains('500 Coins')) targetIdx = 3;
        else if (label.contains('150 XP')) targetIdx = 4;
        else if (label.contains('1000')) targetIdx = 5;

        // Calculate rotation angles
        // 6 segments = 60 degrees each.
        final double segmentAngle = 2 * pi / 6;
        final double targetAngle = (2 * pi * 4) + (targetIdx * segmentAngle);

        _spinController.reset();
        _animation = Tween<double>(
          begin: _currentRotation,
          end: targetAngle,
        ).animate(CurvedAnimation(
          parent: _spinController,
          curve: Curves.decelerate,
        ));

        _spinController.forward().then((_) {
          setState(() {
            _currentRotation = targetAngle % (2 * pi);
            _isSpinning = false;
            _spinClaimed = true;
          });
          ref.read(authProvider.notifier).tryRestoreSession();
          ref.read(dailyMissionsProvider.notifier).fetchMissions();
          _showSuccessDialog('Spin Outcome', 'Congratulations! You won: $label');
        });
      } else {
        setState(() {
          _isSpinning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Spin failed')),
        );
      }
    } catch (e) {
      setState(() {
        _isSpinning = false;
      });
      print(e);
    }
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('AWESOME'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('REWARDS', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Daily login streak card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.calendar_today, size: 40, color: AppColors.secondary),
                    const SizedBox(height: 12),
                    Text(
                      'DAILY STREAK: ${user.loginStreak} DAYS',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Claim daily coins & XP. Higher streaks earn larger coin bonuses!',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _dailyClaimed ? null : _claimDailyReward,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.ludoGreen,
                        disabledBackgroundColor: const Color(0xFF334155),
                      ),
                      child: Text(_dailyClaimed ? 'CLAIMED TODAY' : 'CLAIM COINS & XP'),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),

            // Spin Wheel card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      'SPIN WHEEL OF FORTUNE',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Outfit'),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Spin once a day to win Jackpots, XP, or Coin boosts!',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                    const SizedBox(height: 24),
                    
                    // The Spin Wheel Graphic
                    AnimatedBuilder(
                      animation: _animation,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _animation.value,
                          child: child,
                        );
                      },
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary, width: 6),
                          gradient: const SweepGradient(
                            colors: [
                              AppColors.ludoRed,
                              AppColors.ludoGreen,
                              AppColors.ludoYellow,
                              AppColors.ludoBlue,
                              AppColors.primary,
                              AppColors.secondary,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: List.generate(6, (idx) {
                            final double angle = (idx * 60) * pi / 180;
                            return Transform.rotate(
                              angle: angle,
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 20),
                                  child: RotatedBox(
                                    quarterTurns: 1,
                                    child: Text(
                                      _wheelSegments[idx],
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        shadows: [
                                          Shadow(color: Colors.black, blurRadius: 4),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                    
                    // Spinner Pointer arrow
                    const Icon(Icons.arrow_drop_down, size: 40, color: Colors.white),

                    const SizedBox(height: 16),
                    
                    ElevatedButton(
                      onPressed: (_spinClaimed || _isSpinning) ? null : _spinWheel,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: const Color(0xFF334155),
                      ),
                      child: Text(_isSpinning ? 'SPINNING...' : _spinClaimed ? 'SPUN TODAY' : 'SPIN WHEEL'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const DailyMissionsWidget(),
          ],
        ),
      ),
    );
  }
}

extension DateTimeExtension on DateTime {
  String toDateString() {
    return '${year}-${month}-${day}';
  }
}
