import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/audio_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/missions_widget.dart';
import '../providers/missions_provider.dart';

class RewardsScreen extends ConsumerStatefulWidget {
  const RewardsScreen({super.key});

  @override
  ConsumerState<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends ConsumerState<RewardsScreen> with TickerProviderStateMixin {
  late AnimationController _spinController;
  late AnimationController _pointerController;
  late Animation<double> _animation;
  double _currentRotation = 0.0;
  bool _isSpinning = false;
  bool _dailyClaimed = false;
  bool _spinClaimed = false;
  int _lastTickSegment = 0;

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

    _pointerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _animation = CurvedAnimation(
      parent: _spinController,
      curve: Curves.decelerate,
    );

    _spinController.addListener(() {
      if (_spinController.isAnimating) {
        final double currentRotation = _animation.value;
        // Check segment boundary crossing to trigger pointer tick
        final int segment = (currentRotation / (2 * pi / 6)).floor();
        if (segment != _lastTickSegment) {
          setState(() {
            _lastTickSegment = segment;
          });
          _pointerController.forward(from: 0.0);
        }
      }
    });

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
    _pointerController.dispose();
    super.dispose();
  }

  void _claimDailyReward() async {
    AudioService.instance.playButtonClick();
    try {
      final response = await ApiClient.post('/rewards/daily', {});
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _dailyClaimed = true;
        });
        ref.read(authProvider.notifier).tryRestoreSession();
        ref.read(dailyMissionsProvider.notifier).fetchMissions();
        _showSuccessDialog('Daily Reward', data['message']);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Claim failed'), backgroundColor: AppColors.ludoRed),
        );
      }
    } catch (e) {
      debugPrint('Daily Claim Error: $e');
    }
  }

  void _spinWheel() async {
    if (_isSpinning || _spinClaimed) return;

    setState(() {
      _isSpinning = true;
    });

    // Play whirring wheel spin sound
    AudioService.instance.playSpinWheel();

    try {
      final response = await ApiClient.post('/rewards/spin', {});
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final outcome = data['outcome'];
        final label = outcome['label'];
        
        int targetIdx = 0;
        if (label.contains('50 Coins')) targetIdx = 0;
        else if (label.contains('100 Coins')) targetIdx = 1;
        else if (label.contains('200 Coins')) targetIdx = 2;
        else if (label.contains('500 Coins')) targetIdx = 3;
        else if (label.contains('150 XP')) targetIdx = 4;
        else if (label.contains('1000')) targetIdx = 5;

        final double segmentAngle = 2 * pi / 6;
        // Counter-clockwise offset: to place segment targetIdx at top (0 radians relative to top center)
        final double targetAngle = (2 * pi * 4) + ((6 - targetIdx) % 6) * segmentAngle;

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
          _showSuccessDialog('Wheel Fortune', 'Congratulations! You won: $label', isSpin: true);
        });
      } else {
        setState(() {
          _isSpinning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Spin failed'), backgroundColor: AppColors.ludoRed),
        );
      }
    } catch (e) {
      setState(() {
        _isSpinning = false;
      });
      debugPrint('Spin Wheel Error: $e');
    }
  }

  void _showSuccessDialog(String title, String message, {bool isSpin = false}) {
    AudioService.instance.playRewardClaim();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glassmorphic Dialog Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.2),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 120),
                    Text(
                      title.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        letterSpacing: 1.5,
                        color: AppColors.accentNeon,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.white,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          AudioService.instance.playButtonClick();
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shadowColor: AppColors.primary.withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('AWESOME'),
                      ),
                    ),
                  ],
                ),
              ),

              // Floating Confetti Overlay
              Positioned(
                top: 0,
                child: SizedBox(
                  width: 220,
                  height: 200,
                  child: Lottie.network(
                    'https://assets10.lottiefiles.com/packages/lf20_vu9jxpmo.json',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(
                          Icons.stars_rounded,
                          size: 80,
                          color: AppColors.gold,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStreakTimeline(int streak) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List.generate(7, (index) {
          final dayNum = index + 1;
          final isClaimed = dayNum < streak || (dayNum == streak && _dailyClaimed);
          final isClaimable = dayNum == streak && !_dailyClaimed;
          final isLocked = dayNum > streak;
          
          final cardColor = isClaimable 
            ? AppColors.primary.withOpacity(0.15) 
            : isClaimed 
              ? AppColors.ludoGreen.withOpacity(0.08) 
              : Colors.white.withOpacity(0.03);
              
          final borderColor = isClaimable
            ? AppColors.primary
            : isClaimed
              ? AppColors.ludoGreen.withOpacity(0.4)
              : Colors.white.withOpacity(0.08);

          final Widget dayCard = Container(
            width: 72,
            margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: isClaimable ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.2),
                  blurRadius: 8,
                  spreadRadius: 1,
                )
              ] : [],
            ),
            child: Column(
              children: [
                Text(
                  'DAY $dayNum',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isClaimable 
                      ? AppColors.accentNeon 
                      : isLocked 
                        ? AppColors.textMuted 
                        : AppColors.textPrimary,
                    fontFamily: 'Outfit',
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Icon(
                  dayNum == 7 ? Icons.card_giftcard_rounded : Icons.monetization_on_rounded,
                  size: 22,
                  color: isClaimed 
                    ? AppColors.ludoGreen 
                    : isClaimable 
                      ? AppColors.gold 
                      : AppColors.textMuted,
                ),
                const SizedBox(height: 6),
                Text(
                  dayNum == 7 ? '500+XP' : '${dayNum * 50}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isLocked ? AppColors.textMuted : Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                if (isClaimed)
                  const Icon(Icons.check_circle_rounded, color: AppColors.ludoGreen, size: 12)
                else if (isClaimable)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'READY',
                      style: TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                        color: AppColors.gold,
                      ),
                    ),
                  )
                else
                  const Icon(Icons.lock_rounded, color: AppColors.textMuted, size: 12),
              ],
            ),
          );

          if (isClaimable) {
            return dayCard
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 1.seconds);
          }
          return dayCard;
        }),
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.3,
            colors: [
              Color(0xFF161E33),
              AppColors.background,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                      onPressed: () {
                        AudioService.instance.playButtonClick();
                        context.go('/home');
                      },
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'QUEST REWARDS',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        letterSpacing: 1.5,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Daily Streak Card
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardBg.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.08),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.calendar_today_rounded, color: AppColors.secondary, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'DAILY LOGIN STREAK',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textSecondary,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${user.loginStreak} DAYS ACTIVE',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontFamily: 'Outfit',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Claim daily coins & XP. Higher streaks earn larger coin bonuses!',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      
                      _buildStreakTimeline(user.loginStreak),
                      
                      const SizedBox(height: 20),
                      
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _dailyClaimed ? null : _claimDailyReward,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.ludoGreen,
                            disabledBackgroundColor: const Color(0xFF1E293B),
                            shadowColor: AppColors.ludoGreen.withOpacity(_dailyClaimed ? 0 : 0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            _dailyClaimed ? 'CLAIMED TODAY' : 'CLAIM COINS & XP',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fade(duration: 400.ms).slideY(begin: 0.05, end: 0),
                
                const SizedBox(height: 24),

                // Spin Wheel Card
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardBg.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.08),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Column(
                    children: [
                      const Text(
                        'WHEEL OF FORTUNE',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Outfit', letterSpacing: 1.2),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Spin once a day to win Jackpots, XP, or Coin boosts!',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      
                      // Spin Wheel
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Flashing Outer Glow Rings
                          Container(
                            width: 250,
                            height: 250,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.12),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                          ),

                          // Rotated Wheel Custom Painter
                          AnimatedBuilder(
                            animation: _animation,
                            builder: (context, child) {
                              return Transform.rotate(
                                angle: _animation.value,
                                child: child,
                              );
                            },
                            child: SizedBox(
                              width: 230,
                              height: 230,
                              child: CustomPaint(
                                painter: LudoWheelPainter(_wheelSegments),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: List.generate(6, (idx) {
                                    // Align text perfectly centered within each 60-degree segment
                                    final double angle = (idx * 60 + 30) * pi / 180;
                                    return Transform.rotate(
                                      angle: angle,
                                      child: Align(
                                        alignment: Alignment.topCenter,
                                        child: Padding(
                                          padding: const EdgeInsets.only(top: 25),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                _wheelSegments[idx].contains('XP') 
                                                  ? Icons.star_rounded 
                                                  : Icons.monetization_on_rounded,
                                                size: 18,
                                                color: _wheelSegments[idx].contains('XP') 
                                                  ? AppColors.accentNeon 
                                                  : AppColors.gold,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _wheelSegments[idx].split(' ')[0],
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                  fontFamily: 'Outfit',
                                                  shadows: [
                                                    Shadow(color: Colors.black54, blurRadius: 4),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ),
                          ),

                          // Running Flashing LED Lights around the rim
                          SizedBox(
                            width: 230,
                            height: 230,
                            child: Stack(
                              children: List.generate(12, (idx) {
                                final double angle = (idx * 30) * pi / 180;
                                return Transform.rotate(
                                  angle: angle,
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 1),
                                      child: Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: idx % 2 == 0 ? AppColors.accentNeon : AppColors.secondary,
                                          boxShadow: [
                                            BoxShadow(
                                              color: (idx % 2 == 0 ? AppColors.accentNeon : AppColors.secondary).withOpacity(0.8),
                                              blurRadius: 4,
                                              spreadRadius: 1,
                                            )
                                          ],
                                        ),
                                      ).animate(onPlay: (c) => c.repeat(reverse: true))
                                       .fade(duration: 500.ms, delay: (idx * 40).ms),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),

                          // Static Center Hub Pins
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFFFD700), width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.casino_rounded,
                                color: Color(0xFFFFD700),
                                size: 24,
                              ),
                            ),
                          ),
                          
                          // Pointer tick needle
                          Positioned(
                            top: -12,
                            child: AnimatedBuilder(
                              animation: _pointerController,
                              builder: (context, child) {
                                final double tilt = -0.28 * (1.0 - _pointerController.value) * (1.0 - _pointerController.value);
                                return Transform.rotate(
                                  angle: _spinController.isAnimating ? tilt : 0.0,
                                  child: child,
                                );
                              },
                              child: Container(
                                width: 28,
                                height: 38,
                                child: Stack(
                                  alignment: Alignment.topCenter,
                                  children: [
                                    // Pointer needle body
                                    Positioned(
                                      top: 4,
                                      child: Container(
                                        width: 6,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [AppColors.accentNeon, AppColors.primary],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                          borderRadius: BorderRadius.circular(3),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.accentNeon.withOpacity(0.5),
                                              blurRadius: 6,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Needle pivot pin screw
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: [Color(0xFFFFFFFF), Color(0xFFB0B0B0)],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 2,
                                            offset: Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 28),
                      
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: (_spinClaimed || _isSpinning) ? null : _spinWheel,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            disabledBackgroundColor: const Color(0xFF1E293B),
                            shadowColor: AppColors.primary.withOpacity((_spinClaimed || _isSpinning) ? 0 : 0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            _isSpinning 
                              ? 'SPINNING...' 
                              : _spinClaimed 
                                ? 'SPUN TODAY' 
                                : 'SPIN WHEEL',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fade(duration: 400.ms, delay: 100.ms).slideY(begin: 0.05, end: 0),
                
                const SizedBox(height: 24),
                
                const DailyMissionsWidget()
                    .animate()
                    .fade(duration: 400.ms, delay: 200.ms)
                    .slideY(begin: 0.05, end: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LudoWheelPainter extends CustomPainter {
  final List<String> segments;
  LudoWheelPainter(this.segments);

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / 2;
    final center = Offset(radius, radius);
    final rect = Rect.fromCircle(center: center, radius: radius);

    // High fidelity neon slice colors
    final List<List<Color>> sliceGradients = [
      [const Color(0xFF8B5CF6), const Color(0xFF5B21B6)], // Purple
      [const Color(0xFFFF2E63), const Color(0xFF9B1C31)], // Red
      [const Color(0xFFFFDE7D), const Color(0xFFC79E22)], // Golden Yellow
      [const Color(0xFF08D9D6), const Color(0xFF059A98)], // Mint Green
      [const Color(0xFF2979FF), const Color(0xFF1565C0)], // Neon Blue
      [const Color(0xFFEC4899), const Color(0xFFAD1457)], // Neon Pink
    ];

    for (int i = 0; i < 6; i++) {
      // Offset by -90 degrees (pi/2 radians) to align sector 0 with top center
      final double startAngle = (i * 60 - 90) * pi / 180;
      final double sweepAngle = 60 * pi / 180;

      final paint = Paint()
        ..shader = SweepGradient(
          center: Alignment.center,
          colors: sliceGradients[i],
          startAngle: startAngle,
          endAngle: startAngle + sweepAngle,
        ).createShader(rect)
        ..style = PaintingStyle.fill;

      canvas.drawArc(rect, startAngle, sweepAngle, true, paint);

      // Fine division sector lines
      final borderPaint = Paint()
        ..color = Colors.white.withOpacity(0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawArc(rect, startAngle, sweepAngle, true, borderPaint);
    }

    // Outer premium gold ring border
    final outerRingPaint = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0;
    canvas.drawCircle(center, radius, outerRingPaint);

    // Inner center gold ring border
    canvas.drawCircle(center, radius * 0.22, outerRingPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

extension DateTimeExtension on DateTime {
  String toDateString() {
    return '$year-$month-$day';
  }
}
