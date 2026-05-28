import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
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
    _checkAuth();
  }

  void _checkAuth() async {
    // Wait for the initialization / restore session to run
    await Future.delayed(const Duration(seconds: 2));
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Styled Premium Gaming Logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.purplePinkGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.5),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.casino_rounded,
                  size: 64,
                  color: Colors.white,
                ),
              ),
            )
            .animate()
            .scale(duration: 800.ms, curve: Curves.bounceOut)
            .then()
            .shake(hz: 4, duration: 1.seconds),
            
            const SizedBox(height: 24),
            
            const Text(
              'LUDO KINGDOM',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
                color: Colors.white,
                fontFamily: 'Outfit',
              ),
            )
            .animate()
            .fade(delay: 300.ms, duration: 500.ms)
            .slideY(begin: 0.5, end: 0),
            
            const SizedBox(height: 8),
            
            const Text(
              'Premium Multiplayer Arena',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                letterSpacing: 1.5,
              ),
            )
            .animate()
            .fade(delay: 500.ms, duration: 500.ms),
            
            const SizedBox(height: 48),
            
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
            )
            .animate()
            .fade(delay: 700.ms),
          ],
        ),
      ),
    );
  }
}
