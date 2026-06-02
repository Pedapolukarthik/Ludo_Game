import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/services/tts_service.dart';
import '../../../../core/widgets/bottom_dock.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  String _sortBy = 'wins'; // 'wins' or 'xp'
  List<dynamic> _rankings = [];
  int? _myRank;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchLeaderboard();
  }

  Future<void> _fetchLeaderboard() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiClient.get('/leaderboard?sortBy=$_sortBy');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _rankings = data['leaderboard'] ?? [];
          _myRank = data['myRank'];
        });
      }
    } catch (e) {
      print('Error fetching leaderboard: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _toggleSort(String sortType) {
    if (_sortBy == sortType) return;
    setState(() {
      _sortBy = sortType;
    });
    _fetchLeaderboard();
  }

  @override
  Widget build(BuildContext context) {
    final topThree = _rankings.take(3).toList();
    final remaining = _rankings.skip(3).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('LEADERBOARD', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false, // Removed back button since bottom dock is present
      ),
      body: Column(
        children: [
          // Sort Filters Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _buildSortTab('TOTAL WINS', _sortBy == 'wins', () => _toggleSort('wins')),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSortTab('TOTAL XP', _sortBy == 'xp', () => _toggleSort('xp')),
                ),
              ],
            ),
          ),
          
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_rankings.isEmpty)
            const Expanded(child: Center(child: Text('No rankings available')))
          else ...[
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Podium for top 3
                  if (topThree.isNotEmpty) ...[
                    _buildPodium(topThree),
                    const SizedBox(height: 24),
                  ],

                  // Remaining users list
                  ...remaining.asMap().entries.map((entry) {
                    final idx = entry.key + 4; // Start index at 4
                    final player = entry.value;
                    return Card(
                      color: AppColors.surface,
                      child: ListTile(
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '#$idx',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                            ),
                            const SizedBox(width: 12),
                            CircleAvatar(
                              backgroundImage: NetworkImage(player['avatar']),
                            ),
                          ],
                        ),
                        title: Text(player['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          'LVL ${player['level']} • ${player['rank']}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.secondary.withOpacity(0.3), width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _sortBy == 'wins' ? Icons.emoji_events_rounded : Icons.stars_rounded,
                                color: _sortBy == 'wins' ? AppColors.gold : AppColors.accentNeon,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _sortBy == 'wins' ? '${player['totalWins']}' : '${player['xp']}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 40), // Spacer for bottom navigation dock
                ],
              ),
            ),
            
            // Current User Standing Bottom Bar
            if (_myRank != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: AppTheme.cyberGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.stars_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    const Text(
                      'YOUR STANDING',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12, letterSpacing: 0.8),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'RANK #$_myRank',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accentNeon, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
      bottomNavigationBar: const BottomDock(activeTab: 'leaderboard'),
    );
  }

  Widget _buildSortTab(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        AudioService.instance.playButtonClick();
        TtsService.instance.speak("Sort by $label");
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppColors.primary : const Color(0xFF334155)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1),
        ),
      ),
    );
  }

  Widget _buildPodium(List<dynamic> topThree) {
    final hasSecond = topThree.length > 1;
    final hasThird = topThree.length > 2;

    return Container(
      height: 270,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd Place
          if (hasSecond)
            Expanded(
              child: _buildPodiumCol(
                player: topThree[1],
                rank: 2,
                height: 120,
                color: AppColors.silver,
              ),
            )
          else
            const Spacer(),
            
          // 1st Place
          Expanded(
            child: _buildPodiumCol(
              player: topThree[0],
              rank: 1,
              height: 155,
              color: AppColors.gold,
            ),
          ),
          
          // 3rd Place
          if (hasThird)
            Expanded(
              child: _buildPodiumCol(
                player: topThree[2],
                rank: 3,
                height: 100,
                color: AppColors.bronze,
              ),
            )
          else
            const Spacer(),
        ],
      ),
    );
  }

  Widget _buildPodiumCol({
    required Map<String, dynamic> player,
    required int rank,
    required double height,
    required Color color,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Avatar
        Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: rank == 1 ? 36 : 28,
              backgroundColor: color,
              child: CircleAvatar(
                radius: rank == 1 ? 33 : 25,
                backgroundImage: NetworkImage(player['avatar']),
              ),
            ),
            Positioned(
              top: -12,
              child: Icon(Icons.workspace_premium, color: color, size: rank == 1 ? 24 : 18),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          player['name'],
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Container(
          height: height,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '#$rank',
                style: TextStyle(fontSize: rank == 1 ? 32 : 24, fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _sortBy == 'wins' ? Icons.emoji_events_rounded : Icons.stars_rounded,
                    color: color,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _sortBy == 'wins' ? '${player['totalWins']}' : '${player['xp']}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
