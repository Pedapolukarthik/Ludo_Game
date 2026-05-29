import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/match_history_provider.dart';
import '../../domain/match_history_item.dart';
import '../../../../core/services/audio_service.dart';

class MatchHistoryScreen extends ConsumerWidget {
  const MatchHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyState = ref.watch(matchHistoryProvider);
    final currentUser = ref.watch(authProvider).user;

    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('MATCH HISTORY', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            AudioService.instance.playButtonClick();
            context.go('/profile');
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              AudioService.instance.playButtonClick();
              ref.read(matchHistoryProvider.notifier).fetchMatchHistory();
            },
          ),
        ],
      ),
      body: historyState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error loading match history: $error', style: const TextStyle(color: AppColors.ludoRed)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  AudioService.instance.playButtonClick();
                  ref.read(matchHistoryProvider.notifier).fetchMatchHistory();
                },
                child: const Text('RETRY'),
              ),
            ],
          ),
        ),
        data: (matches) {
          if (matches.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off, size: 64, color: AppColors.textMuted.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  const Text(
                    'NO MATCHES PLAYED YET',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textSecondary, letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Play quick matches or practice vs AI to see records here!',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: matches.length,
            itemBuilder: (context, index) {
              final match = matches[index];
              final isWinner = match.winner.userId == currentUser.id || 
                  (match.winner.userId == null && match.winner.name == currentUser.name);
              
              // Find opponents
              final opponentsList = match.players
                  .where((p) => p.userId != currentUser.id && p.name != currentUser.name)
                  .map((p) => p.name)
                  .toList();
              
              final opponentsStr = opponentsList.isEmpty ? 'AI Bot' : opponentsList.join(', ');
              
              // Coins display
              final coinsEarned = isWinner ? match.prizePool : -match.entryFee;
              final coinsStr = isWinner ? '+$coinsEarned' : '$coinsEarned';
              final coinsColor = isWinner ? AppColors.ludoGreen : AppColors.ludoRed;

              // Color bullet representing our played zone color
              final myPlayerInfo = match.players.firstWhere(
                (p) => p.userId == currentUser.id || p.name == currentUser.name,
                orElse: () => MatchPlayer(name: currentUser.name, avatar: currentUser.avatar, color: 'Red', isBot: false),
              );

              Color bulletColor;
              switch (myPlayerInfo.color) {
                case 'Red': bulletColor = AppColors.ludoRed; break;
                case 'Green': bulletColor = AppColors.ludoGreen; break;
                case 'Yellow': bulletColor = AppColors.ludoYellow; break;
                case 'Blue': bulletColor = AppColors.ludoBlue; break;
                default: bulletColor = Colors.white;
              }

              final dateStr = '${match.createdAt.day.toString().padLeft(2, '0')}/${match.createdAt.month.toString().padLeft(2, '0')}/${match.createdAt.year} ${match.createdAt.hour.toString().padLeft(2, '0')}:${match.createdAt.minute.toString().padLeft(2, '0')}';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Match Result Indicator Badge
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (isWinner ? AppColors.ludoGreen : AppColors.ludoRed).withOpacity(0.1),
                          border: Border.all(
                            color: (isWinner ? AppColors.ludoGreen : AppColors.ludoRed).withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          isWinner ? Icons.emoji_events : Icons.close,
                          color: isWinner ? AppColors.ludoGreen : AppColors.ludoRed,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Opponents & Date Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.lens, color: bulletColor, size: 8),
                                const SizedBox(width: 6),
                                Text(
                                  isWinner ? 'VICTORY' : 'DEFEAT',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isWinner ? AppColors.ludoGreen : AppColors.ludoRed,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Opponent: $opponentsStr',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              dateStr,
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),

                      // Winnings/Earnings displaying coins
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.monetization_on, color: coinsColor, size: 18),
                              const SizedBox(width: 4),
                              Text(
                                coinsStr,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: coinsColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isWinner ? 'Prize won' : 'Entry fee lost',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
