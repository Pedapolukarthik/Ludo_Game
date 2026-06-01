import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/services/local_storage.dart';
import '../../../../core/services/tts_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _musicEnabled = true;
  bool _sfxEnabled = true;
  bool _voiceAssistanceEnabled = true;

  @override
  void initState() {
    super.initState();
    _musicEnabled = LocalStorage.isMusicEnabled();
    _sfxEnabled = LocalStorage.isSfxEnabled();
    _voiceAssistanceEnabled = LocalStorage.isVoiceAssistanceEnabled();
  }

  void _toggleMusic(bool enabled) async {
    AudioService.instance.playButtonClick();
    setState(() => _musicEnabled = enabled);
    await LocalStorage.setMusicEnabled(enabled);
    AudioService.instance.handleSettingsChanged();
  }

  void _toggleSfx(bool enabled) async {
    AudioService.instance.playButtonClick();
    setState(() => _sfxEnabled = enabled);
    await LocalStorage.setSfxEnabled(enabled);
    AudioService.instance.handleSettingsChanged();
  }

  void _toggleVoiceAssistance(bool enabled) async {
    AudioService.instance.playButtonClick();
    setState(() => _voiceAssistanceEnabled = enabled);
    await LocalStorage.setVoiceAssistanceEnabled(enabled);
    if (enabled) {
      TtsService.instance.speak("Voice assistance enabled");
    } else {
      // Speak right before turning off
      TtsService.instance.speak("Voice assistance disabled");
    }
  }

  void _handleLogout() async {
    AudioService.instance.playButtonClick();
    TtsService.instance.speak("Logout");
    await ref.read(authProvider.notifier).logout();
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('SETTINGS', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            AudioService.instance.playButtonClick();
            TtsService.instance.speak("Back to home");
            context.go('/home');
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Audio settings card
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Game Background Music'),
                  subtitle: const Text('Toggle lobby and matching soundtrack'),
                  value: _musicEnabled,
                  onChanged: _toggleMusic,
                  activeColor: AppColors.primary,
                ),
                const Divider(height: 1, color: Color(0xFF334155)),
                SwitchListTile(
                  title: const Text('Sound Effects (SFX)'),
                  subtitle: const Text('Toggle pawn steps and dice roll alerts'),
                  value: _sfxEnabled,
                  onChanged: _toggleSfx,
                  activeColor: AppColors.primary,
                ),
                const Divider(height: 1, color: Color(0xFF334155)),
                SwitchListTile(
                  title: const Text('Voice Assistance'),
                  subtitle: const Text('Toggle narration of clicked items and dice rolls'),
                  value: _voiceAssistanceEnabled,
                  onChanged: _toggleVoiceAssistance,
                  activeColor: AppColors.primary,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),

          // Information card
          Card(
            child: const Column(
              children: [
                ListTile(
                  leading: Icon(Icons.info_outline, color: AppColors.ludoBlue),
                  title: Text('App Version'),
                  trailing: Text('1.0.0+1', style: TextStyle(color: AppColors.textSecondary)),
                ),
                Divider(height: 1, color: Color(0xFF334155)),
                ListTile(
                  leading: Icon(Icons.security, color: AppColors.ludoGreen),
                  title: Text('Data Encryption'),
                  trailing: Text('AES-256 / JWT', style: TextStyle(color: AppColors.textSecondary)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Logout Button
          ElevatedButton(
            onPressed: _handleLogout,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.ludoRed,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout_rounded),
                SizedBox(width: 8),
                Text('LOGOUT FROM SERVER'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
