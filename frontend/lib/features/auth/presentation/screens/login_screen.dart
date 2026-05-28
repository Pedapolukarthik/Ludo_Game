import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _mockUserController = TextEditingController();
  final TextEditingController _referralController = TextEditingController();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '927677242341-5me8gbn19micmb2op4tq91d67rb517jf.apps.googleusercontent.com',
  );
  bool _isMockDrawerOpen = false;
  bool _isSigningIn = false;

  void _handleGoogleSignIn() async {
    if (_isSigningIn) return;
    setState(() {
      _isSigningIn = true;
    });
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // Sign-in cancelled by user
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final String? idToken = await userCredential.user?.getIdToken();

      if (idToken == null) {
        throw Exception('Failed to retrieve Firebase ID Token.');
      }

      // Pass token to backend via authProvider
      final success = await ref.read(authProvider.notifier).loginWithGoogle(idToken);
      if (success && mounted) {
        context.go('/home');
      } else if (mounted) {
        final error = ref.read(authProvider).errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error ?? 'Login failed. Verify if server is running!')),
        );
      }
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google Sign-In failed: $e.\nEnsure your SHA-1 fingerprint is added in the Firebase Console.'),
            backgroundColor: AppColors.ludoRed,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'Mock Login',
              textColor: Colors.white,
              onPressed: () {
                setState(() {
                  _isMockDrawerOpen = true;
                });
              },
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
    }
  }

  void _handleMockLogin() async {
    final username = _mockUserController.text.trim();
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a username')),
      );
      return;
    }

    final referralCode = _referralController.text.trim().isEmpty ? null : _referralController.text.trim();

    final success = await ref.read(authProvider.notifier).loginMock(
      username,
      referralCode: referralCode,
    );

    if (success && mounted) {
      context.go('/home');
    } else if (mounted) {
      final error = ref.read(authProvider).errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Login failed. Verify if server is running!')),
      );
    }
  }

  @override
  void dispose() {
    _mockUserController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background Gradient Circles
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withOpacity(0.1),
              ),
            ),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon/Logo
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.2),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.casino_outlined,
                      size: 60,
                      color: AppColors.secondary,
                    ),
                  )
                  .animate()
                  .scale(duration: 500.ms, curve: Curves.easeOutBack),
                  
                  const SizedBox(height: 24),
                  
                  const Text(
                    'Ludo Kingdom',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      fontFamily: 'Outfit',
                    ),
                  ),
                  
                  const Text(
                    'Join the ultimate multiplayer tournament',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  
                  const SizedBox(height: 48),

                  // Authentication Button Card
                  if (authState.isLoading || _isSigningIn)
                    const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.secondary))
                  else ...[
                    // Premium Google Sign-In Button
                    InkWell(
                      onTap: _handleGoogleSignIn,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.network(
                              'https://api.iconify.design/logos:google-icon.svg',
                              width: 24,
                              height: 24,
                              errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, color: Colors.black),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Sign In with Google',
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),

                    // Quick Mock Login Toggle
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isMockDrawerOpen = !_isMockDrawerOpen;
                        });
                      },
                      child: Text(
                        _isMockDrawerOpen ? 'Hide Developer Options' : 'Show Developer Options (Local Test)',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),

                    if (_isMockDrawerOpen) ...[
                      const SizedBox(height: 16),
                      Card(
                        color: AppColors.surface,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Developer Fast Login',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),
                              
                              // Nickname input
                              TextField(
                                controller: _mockUserController,
                                decoration: const InputDecoration(
                                  labelText: 'Nickname (e.g. Alice, Bob)',
                                  filled: true,
                                  fillColor: Color(0xFF1E293B),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              
                              const SizedBox(height: 12),
                              
                              // Optional referral code
                              TextField(
                                controller: _referralController,
                                decoration: const InputDecoration(
                                  labelText: 'Referral Code (Optional)',
                                  filled: true,
                                  fillColor: Color(0xFF1E293B),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              
                              const SizedBox(height: 16),
                              
                              ElevatedButton(
                                onPressed: _handleMockLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.secondary,
                                ),
                                child: const Text('Connect Mock Account'),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fade(duration: 300.ms).slideY(begin: 0.2, end: 0),
                    ]
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
