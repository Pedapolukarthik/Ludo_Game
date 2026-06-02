import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/missions_provider.dart';
import '../../domain/mission_model.dart';

class DailyMissionsWidget extends ConsumerWidget {
  const DailyMissionsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missionsState = ref.watch(dailyMissionsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'DAILY MISSIONS',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
                letterSpacing: 1.5,
                color: Colors.white,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 18, color: AppColors.textSecondary),
              onPressed: () => ref.read(dailyMissionsProvider.notifier).fetchMissions(),
            ),
          ],
        ),
        const SizedBox(height: 8),

        missionsState.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (err, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Failed to load daily missions: $err',
              style: const TextStyle(color: AppColors.ludoRed, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
          data: (missions) {
            if (missions.isEmpty) {
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.cardBg.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                padding: const EdgeInsets.all(24),
                child: const Text(
                  'No missions currently active.',
                  style: TextStyle(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              );
            }

            return Column(
              children: missions.asMap().entries.map((entry) {
                final idx = entry.key;
                final mission = entry.value;
                return _buildMissionCard(mission)
                    .animate()
                    .fade(duration: 350.ms, delay: (idx * 60).ms)
                    .slideY(begin: 0.05, end: 0, duration: 350.ms);
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMissionCard(MissionModel mission) {
    final progressVal = mission.progress / mission.goal;
    final displayProgress = progressVal.clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (mission.completed ? AppColors.ludoGreen : AppColors.primary).withOpacity(0.2),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left block: Title & Description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mission.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          fontFamily: 'Outfit',
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        mission.description,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Right block: Progress status / Completed badge & Rewards
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (mission.completed)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.ludoGreen.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.ludoGreen.withOpacity(0.3)),
                        ),
                        child: const Text(
                          'DONE',
                          style: TextStyle(
                            color: AppColors.ludoGreen,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else
                      Text(
                        '${mission.progress}/${mission.goal}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondary,
                          fontSize: 12,
                        ),
                      ),
                    const SizedBox(height: 6),
                    // Compact Rewards pills
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (mission.coins > 0) ...[
                          const Icon(Icons.monetization_on_rounded, color: AppColors.gold, size: 12),
                          const SizedBox(width: 2),
                          Text(
                            '${mission.coins}',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (mission.xp > 0) ...[
                          const Icon(Icons.stars_rounded, color: AppColors.secondary, size: 12),
                          const SizedBox(width: 2),
                          Text(
                            '${mission.xp}',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Container(
                height: 5,
                color: const Color(0xFF111726),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: displayProgress,
                           child: Container(
                            decoration: BoxDecoration(
                              gradient: mission.completed
                                ? const LinearGradient(colors: [AppColors.ludoGreen, Color(0xFF00ADB5)])
                                : AppTheme.purplePinkGradient,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
