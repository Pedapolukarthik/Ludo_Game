import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../services/audio_service.dart';
import '../services/tts_service.dart';

class BottomDock extends StatelessWidget {
  final String activeTab;

  const BottomDock({
    super.key,
    required this.activeTab,
  });

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> items = [
      {
        'id': 'home',
        'label': 'LOBBY',
        'icon': Icons.sports_esports_rounded,
        'route': '/home',
        'tts': 'Lobby Screen',
      },
      {
        'id': 'leaderboard',
        'label': 'RANKS',
        'icon': Icons.emoji_events_rounded,
        'route': '/leaderboard',
        'tts': 'Leaderboard Screen',
      },
      {
        'id': 'rewards',
        'label': 'QUESTS',
        'icon': Icons.stars_rounded,
        'route': '/rewards',
        'tts': 'Rewards Screen',
      },
      {
        'id': 'profile',
        'label': 'PROFILE',
        'icon': Icons.person_rounded,
        'route': '/profile',
        'tts': 'Profile Screen',
      },
    ];

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.08),
              blurRadius: 15,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF131929).withOpacity(0.75),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: items.map((item) {
                  final isSelected = activeTab == item['id'];
                  final Color iconColor = isSelected ? Colors.white : AppColors.textSecondary;
                  final double scale = isSelected ? 1.05 : 0.95;

                  return Expanded(
                    child: Semantics(
                      label: '${item['label']} Tab Button',
                      hint: 'Double tap to open the ${item['label'].toLowerCase()} page',
                      selected: isSelected,
                      button: true,
                      child: GestureDetector(
                        onTap: () {
                          if (isSelected) return;
                          AudioService.instance.playButtonClick();
                          TtsService.instance.speak(item['tts'] as String);
                          context.go(item['route'] as String);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: AnimatedScale(
                          scale: scale,
                          duration: const Duration(milliseconds: 150),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: isSelected
                                      ? AppTheme.purplePinkGradient
                                      : null,
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: AppColors.secondary.withOpacity(0.3),
                                            blurRadius: 10,
                                            spreadRadius: 1,
                                          )
                                        ]
                                      : [],
                                ),
                                child: Icon(
                                  item['icon'] as IconData,
                                  color: iconColor,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item['label'] as String,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? Colors.white : AppColors.textSecondary,
                                  letterSpacing: 0.8,
                                  fontFamily: 'Outfit',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
