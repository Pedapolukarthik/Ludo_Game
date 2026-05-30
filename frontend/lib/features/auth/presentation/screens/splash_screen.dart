import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Start background music loop
    AudioService.instance.startBgm('bgm.mp3');
    _checkAuth();
  }

  void _checkAuth() async {
    // Wait for the initialization / restore session to run
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    
    final authState = ref.read(authProvider);
    if (authState.isAuthenticated) {
      context.go('/home');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Cyberpunk Grid/Glow background effect
          Positioned.fill(
            child: Opacity(
              opacity: 0.08,
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [AppColors.primary, Colors.transparent],
                    radius: 1.2,
                  ),
                ),
              ),
            ),
          ),
          
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Glowing Lottie Logo Animation
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.25),
                        blurRadius: 40,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Lottie.asset(
                      'assets/animations/loading.json',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback to static icon if network error
                        return Container(
                          color: AppColors.surface,
                          child: const Icon(
                            Icons.casino_rounded,
                            size: 80,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                  ),
                )
                .animate()
                .scale(duration: 1000.ms, curve: Curves.elasticOut),
                
                const SizedBox(height: 36),
                
                const Text(
                  'LUDO ARENA',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 6,
                    color: Colors.white,
                    fontFamily: 'Outfit',
                    shadows: [
                      Shadow(
                        color: AppColors.accentNeon,
                        blurRadius: 15,
                        offset: Offset(0, 0),
                      ),
                    ],
                  ),
                )
                .animate()
                .fade(delay: 300.ms, duration: 600.ms)
                .slideY(begin: 0.4, end: 0),
                
                const SizedBox(height: 12),
                
                Text(
                  'PREMIUM MULTIPLAYER BATTLEFIELD',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppColors.accentNeon.withOpacity(0.8),
                    letterSpacing: 2.0,
                    fontWeight: FontWeight.w600,
                  ),
                )
                .animate()
                .fade(delay: 600.ms, duration: 500.ms),
                
                const SizedBox(height: 60),
                
                // Tech loading indicator
                SizedBox(
                  width: 50,
                  height: 50,
                  child: const CircularProgressIndicator(
                    strokeWidth: 4.5,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
                  ),
                )
                .animate()
                .fade(delay: 800.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
