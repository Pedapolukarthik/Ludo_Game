import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';

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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.go('/home'),
        ),
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
                        subtitle: Text('Level ${player['level']} - ${player['rank']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _sortBy == 'wins' ? '${player['totalWins']} Wins' : '${player['xp']} XP',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondary),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            
            // Current User Standing Bottom Bar
            if (_myRank != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -2)),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'YOUR CURRENT POSITION:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary, fontSize: 13),
                      ),
                      Text(
                        'RANK #$_myRank',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.ludoYellow, fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSortTab(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
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
      height: 200,
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
              Text(
                _sortBy == 'wins' ? '${player['totalWins']}' : '${player['xp']}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
              ),
              Text(
                _sortBy == 'wins' ? 'Wins' : 'XP',
                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
