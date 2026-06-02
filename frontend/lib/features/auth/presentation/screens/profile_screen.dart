import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/tts_service.dart';
import '../providers/auth_provider.dart';
import '../../../../core/widgets/bottom_dock.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _nameController = TextEditingController();
  List<dynamic> _friends = [];
  bool _isLoadingFriends = false;
  String _searchQuery = '';
  List<dynamic> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _nameController.text = ref.read(authProvider).user?.name ?? '';
    _fetchFriends();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _fetchFriends() async {
    setState(() => _isLoadingFriends = true);
    try {
      final response = await ApiClient.get('/auth/me');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _friends = data['user']['friends'] ?? [];
        });
      }
    } catch (e) {
      print('Error fetching friends: $e');
    } finally {
      setState(() => _isLoadingFriends = false);
    }
  }

  void _searchUsers(String val) async {
    if (val.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    try {
      final response = await ApiClient.get('/users/search?query=$val');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _searchResults = data['users'] ?? [];
        });
      }
    } catch (e) {
      print('Error searching users: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _sendFriendRequest(String userId) async {
    try {
      final response = await ApiClient.post('/users/friends/request/$userId', {});
      final data = jsonDecode(response.body);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message'] ?? 'Friend request sent!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send request')),
      );
    }
  }

  void _removeFriend(String userId) async {
    try {
      final response = await ApiClient.delete('/users/friends/$userId');
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend removed')),
        );
        _fetchFriends();
      }
    } catch (e) {
      print(e);
    }
  }

  void _updateName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    try {
      final response = await ApiClient.put('/users/profile', {'name': name});
      if (response.statusCode == 200) {
        ref.read(authProvider.notifier).tryRestoreSession();
        TtsService.instance.speak("Profile updated to $name");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update profile')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final nextLevelXp = 1000;
    final currentLevelXp = user.xp % 1000;
    final xpProgress = currentLevelXp / nextLevelXp;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('PLAYER PROFILE', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false, // Removed back button since bottom dock is present
      ),
      body: Column(
        children: [
          // Header Profile Card
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Semantics(
                          label: 'Player Avatar Picture',
                          child: CircleAvatar(
                            radius: 40,
                            backgroundColor: AppColors.primary,
                            backgroundImage: NetworkImage(user.avatar),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Semantics(
                                      label: 'Username Input Field',
                                      hint: 'Enter a new username and press enter to update your profile name',
                                      child: TextField(
                                        controller: _nameController,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          suffixIcon: Icon(Icons.edit, size: 16, color: AppColors.textSecondary),
                                        ),
                                        onSubmitted: (_) => _updateName(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                user.email,
                                style: const TextStyle(color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 8),
                              Semantics(
                                label: 'Player Current Rank Badge',
                                value: user.rank,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.purplePinkGradient,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'Rank: ${user.rank}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // Level Progression Bar
                    Semantics(
                      label: 'Level Progression Progress Bar',
                      value: 'Level ${user.level}, $currentLevelXp out of $nextLevelXp Experience Points',
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('LEVEL ${user.level}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('$currentLevelXp / $nextLevelXp XP', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: xpProgress,
                              backgroundColor: const Color(0xFF334155),
                              valueColor: const AlwaysStoppedAnimation(AppColors.secondary),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Win-Loss statistics 2x2 grid
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.7,
                      children: [
                        _buildGridStatCard(
                          'WINS',
                          '${user.totalWins}',
                          Icons.emoji_events_rounded,
                          AppColors.ludoGreen,
                        ),
                        _buildGridStatCard(
                          'WIN RATE',
                          user.totalGames > 0
                              ? '${(user.totalWins / user.totalGames * 100).toStringAsFixed(0)}%'
                              : '0%',
                          Icons.analytics_rounded,
                          AppColors.gold,
                        ),
                        _buildGridStatCard(
                          'STREAK',
                          '${user.currentWinStreak} (MAX ${user.highestWinStreak})',
                          Icons.local_fire_department_rounded,
                          AppColors.secondary,
                        ),
                        _buildGridStatCard(
                          'MATCHES',
                          '${user.totalGames}',
                          Icons.sports_esports_rounded,
                          AppColors.accentNeon,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFF334155)),
                    const SizedBox(height: 8),
                    // Action button to open match history
                    Semantics(
                      label: 'View Match History Button',
                      hint: 'Double tap to view details of your past online matches, wins, and losses',
                      button: true,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          TtsService.instance.speak("View Match History");
                          context.go('/match-history');
                        },
                        icon: const Icon(Icons.history, size: 18),
                        label: const Text('VIEW MATCH HISTORY'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.cardBg,
                          side: const BorderSide(color: AppColors.primary, width: 1.5),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Tab Bar
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Achievements'),
              Tab(text: 'Friends List'),
            ],
            indicatorColor: AppColors.primary,
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.textSecondary,
          ),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Achievements Tab
                () {
                  final cleanAchievements = user.achievements
                      .where((a) => !a.startsWith('DailyClaim_') && !a.startsWith('SpinClaim_'))
                      .toList();

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'REFERRAL CODE: ${user.referralCode}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.ludoYellow, fontSize: 14, letterSpacing: 0.8, fontFamily: 'Outfit'),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        child: cleanAchievements.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.workspace_premium_rounded, size: 48, color: AppColors.textMuted.withOpacity(0.5)),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'No achievements unlocked yet.',
                                      style: TextStyle(color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              )
                            : GridView.builder(
                                padding: const EdgeInsets.all(16),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.85,
                                ),
                                itemCount: cleanAchievements.length,
                                itemBuilder: (context, index) {
                                  final achievement = cleanAchievements[index];
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.cardBg,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                                    ),
                                    padding: const EdgeInsets.all(8),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: AppTheme.purplePinkGradient,
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppColors.secondary.withOpacity(0.2),
                                                blurRadius: 8,
                                              ),
                                            ],
                                          ),
                                          child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 24),
                                        ),
                                        const SizedBox(height: 8),
                                        Expanded(
                                          child: Text(
                                            achievement,
                                            style: const TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 80), // spacer for bottom navigation dock
                    ],
                  );
                }(),

                // Friends tab
                Column(
                  children: [
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        onChanged: _searchUsers,
                        decoration: InputDecoration(
                          hintText: 'Search friends...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: AppColors.cardBg,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),

                    if (_isSearching)
                      const LinearProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.primary))
                    else if (_searchResults.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('Search Results', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _searchResults.length + 1,
                          itemBuilder: (context, idx) {
                            if (idx == _searchResults.length) {
                              return const SizedBox(height: 80);
                            }
                            final item = _searchResults[idx];
                            return ListTile(
                              leading: CircleAvatar(backgroundImage: NetworkImage(item['avatar'])),
                              title: Text(item['name']),
                              subtitle: Text('Lvl ${item['level']} - ${item['rank']}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.person_add_alt_1, color: AppColors.primary),
                                onPressed: () => _sendFriendRequest(item['_id']),
                              ),
                            );
                          },
                        ),
                      ),
                    ] else ...[
                      // Normal Friends list
                      Expanded(
                        child: _isLoadingFriends
                            ? const Center(child: CircularProgressIndicator())
                            : _friends.isEmpty
                                ? const Center(child: Text('No friends added yet.'))
                                : ListView.builder(
                                    itemCount: _friends.length + 1,
                                    itemBuilder: (context, idx) {
                                      if (idx == _friends.length) {
                                        return const SizedBox(height: 80);
                                      }
                                      final friend = _friends[idx];
                                      return ListTile(
                                        leading: CircleAvatar(backgroundImage: NetworkImage(friend['avatar'])),
                                        title: Text(friend['name']),
                                        subtitle: Text(
                                          'RANK: ${friend['rank'].toUpperCase()}',
                                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, letterSpacing: 0.5),
                                        ),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.person_remove_outlined, color: AppColors.ludoRed),
                                          onPressed: () => _removeFriend(friend['_id']),
                                        ),
                                      );
                                    },
                                  ),
                      ),
                    ]
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomDock(activeTab: 'profile'),
    );
  }

  Widget _buildGridStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1.2),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
              Icon(icon, color: color, size: 16),
            ],
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String title, String value, Color color) {
    return Semantics(
      label: 'Player Statistic: $title',
      value: value,
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
